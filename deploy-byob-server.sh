#!/usr/bin/env bash

set -euo pipefail

ENV_FILE="${ENV_FILE:-.env.byob}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

# Server connection
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_HOST="${REMOTE_HOST:-}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY="${SSH_KEY:-}"

# Domain + SSL
DOMAIN="${DOMAIN:-byob-hkbeer.co}"
WWW_DOMAIN="${WWW_DOMAIN:-www.byob-hkbeer.co}"
LE_EMAIL="${LE_EMAIL:-}"
CERTBOT_STAGING="${CERTBOT_STAGING:-0}"
SKIP_CERTBOT="${SKIP_CERTBOT:-0}"

# Remote web root
WEB_ROOT="${WEB_ROOT:-/var/www/${DOMAIN}/html}"

# Deployment payload
SOURCE_FILE="${SOURCE_FILE:-byob-boss-invite.html}"
TARGET_HTML="${TARGET_HTML:-index.html}"
ASSET_DIRS="${ASSET_DIRS:-images fonts promo}"
REMOTE_FILE_CHMOD="${REMOTE_FILE_CHMOD:-644}"
REMOTE_DIR_CHMOD="${REMOTE_DIR_CHMOD:-755}"

# Step toggles
SKIP_SERVER_SETUP="${SKIP_SERVER_SETUP:-0}"
SKIP_UPLOAD="${SKIP_UPLOAD:-0}"

if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" ]]; then
  cat >&2 <<'EOF'
Missing required configuration.

Set these values in $ENV_FILE or export them before running:
  REMOTE_USER   SSH username
  REMOTE_HOST   SSH hostname or IP

Recommended:
  DOMAIN        e.g. byob-hkbeer.co
  WWW_DOMAIN    e.g. www.byob-hkbeer.co
  LE_EMAIL      email for Let's Encrypt notices
EOF
  exit 1
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Source file not found: $SOURCE_FILE" >&2
  exit 1
fi

asset_dirs=()
if [[ -n "$ASSET_DIRS" ]]; then
  # shellcheck disable=SC2206
  asset_dirs=($ASSET_DIRS)
fi

for dir in "${asset_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "Asset directory not found: $dir" >&2
    exit 1
  fi
done

if [[ "$SKIP_CERTBOT" != "1" && -z "$LE_EMAIL" ]]; then
  echo "LE_EMAIL is required unless SKIP_CERTBOT=1" >&2
  exit 1
fi

ssh_args=(-p "$SSH_PORT")
scp_args=(-P "$SSH_PORT")

if [[ -n "$SSH_KEY" ]]; then
  ssh_args+=(-i "$SSH_KEY")
  scp_args+=(-i "$SSH_KEY")
fi

remote_host="$REMOTE_USER@$REMOTE_HOST"

echo "==> Target host: $remote_host"
echo "==> Domain: $DOMAIN (and $WWW_DOMAIN)"
echo "==> Web root: $WEB_ROOT"

if [[ "$SKIP_SERVER_SETUP" != "1" ]]; then
  echo "==> Configuring Nginx + SSL on server"
  ssh "${ssh_args[@]}" "$remote_host" "bash -s" <<EOF
set -euo pipefail

DOMAIN="$DOMAIN"
WWW_DOMAIN="$WWW_DOMAIN"
WEB_ROOT="$WEB_ROOT"
LE_EMAIL="$LE_EMAIL"
SKIP_CERTBOT="$SKIP_CERTBOT"
CERTBOT_STAGING="$CERTBOT_STAGING"

sudo mkdir -p "\$WEB_ROOT"
sudo chown -R www-data:www-data "\$(dirname "\$WEB_ROOT")"
sudo find "\$(dirname "\$WEB_ROOT")" -type d -exec chmod 755 {} +

if ! command -v nginx >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y nginx
fi

if [[ "\$SKIP_CERTBOT" != "1" ]] && ! command -v certbot >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y certbot python3-certbot-nginx
fi

sudo tee "/etc/nginx/sites-available/\$DOMAIN" >/dev/null <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name \$DOMAIN \$WWW_DOMAIN;

    root \$WEB_ROOT;
    index index.html;

    location ^~ /promo/ {
      try_files \\$uri \\$uri/ /promo/index.html;
    }

    location / {
      try_files \\\$uri \\\$uri/ =404;
    }
}
NGINX

if [[ ! -L "/etc/nginx/sites-enabled/\$DOMAIN" ]]; then
  sudo ln -s "/etc/nginx/sites-available/\$DOMAIN" "/etc/nginx/sites-enabled/\$DOMAIN"
fi

sudo nginx -t
sudo systemctl reload nginx

if [[ "\$SKIP_CERTBOT" != "1" ]]; then
  certbot_args=(--nginx -d "\$DOMAIN" -d "\$WWW_DOMAIN" --redirect -m "\$LE_EMAIL" --agree-tos --no-eff-email -n)
  if [[ "\$CERTBOT_STAGING" == "1" ]]; then
    certbot_args+=(--staging)
  fi
  sudo certbot "\${certbot_args[@]}"
  sudo certbot renew --dry-run
fi
EOF
fi

if [[ "$SKIP_UPLOAD" != "1" ]]; then
  echo "==> Preparing deploy bundle"
  stage_dir="$(mktemp -d)"
  bundle="$(mktemp /tmp/byob-deploy-XXXXXX.tar.gz)"
  remote_bundle="/tmp/byob-deploy-$$.tar.gz"

  cleanup() {
    rm -rf "$stage_dir" "$bundle"
  }
  trap cleanup EXIT

  cp "$SOURCE_FILE" "$stage_dir/$TARGET_HTML"
  for dir in "${asset_dirs[@]}"; do
    cp -R "$dir" "$stage_dir/$dir"
  done

  tar -C "$stage_dir" -czf "$bundle" .

  echo "==> Uploading bundle"
  scp "${scp_args[@]}" "$bundle" "$remote_host:$remote_bundle"

  echo "==> Extracting bundle to web root"
  ssh "${ssh_args[@]}" "$remote_host" "bash -s" <<EOF
set -euo pipefail

WEB_ROOT="$WEB_ROOT"
REMOTE_BUNDLE="$remote_bundle"
REMOTE_FILE_CHMOD="$REMOTE_FILE_CHMOD"
REMOTE_DIR_CHMOD="$REMOTE_DIR_CHMOD"

sudo mkdir -p "\$WEB_ROOT"
sudo tar -xzf "\$REMOTE_BUNDLE" -C "\$WEB_ROOT"
sudo rm -f "\$REMOTE_BUNDLE"

sudo find "\$WEB_ROOT" -type d -exec chmod "\$REMOTE_DIR_CHMOD" {} +
sudo find "\$WEB_ROOT" -type f -exec chmod "\$REMOTE_FILE_CHMOD" {} +
sudo chown -R www-data:www-data "\$WEB_ROOT"
EOF
fi

echo "==> Done"
echo "Live URL: https://$DOMAIN/"
