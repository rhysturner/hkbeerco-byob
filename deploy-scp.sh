#!/usr/bin/env bash

set -euo pipefail

ENV_FILE="${ENV_FILE:-.env.deploy}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

SOURCE_FILE="${SOURCE_FILE:-byob-boss-invite.html}"
ASSET_DIRS="${ASSET_DIRS:-images fonts promo}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_DIR="${REMOTE_DIR:-}"
REMOTE_NAME="${REMOTE_NAME:-$SOURCE_FILE}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY="${SSH_KEY:-}"
REMOTE_FILE_CHMOD="${REMOTE_FILE_CHMOD:-${REMOTE_CHMOD:-644}}"
REMOTE_DIR_CHMOD="${REMOTE_DIR_CHMOD:-755}"
REMOTE_CHMOD_STRICT="${REMOTE_CHMOD_STRICT:-0}"
CONFIGURE_PROMO_ROUTE="${CONFIGURE_PROMO_ROUTE:-1}"
REMOTE_NGINX_SITE="${REMOTE_NGINX_SITE:-/etc/nginx/sites-available/brrrr.app}"
PROMO_ROUTE_PREFIX="${PROMO_ROUTE_PREFIX:-/hkbeerco/byob/promo/}"
PROMO_ROUTE_FALLBACK="${PROMO_ROUTE_FALLBACK:-/hkbeerco/byob/promo/index.html}"
PROMO_ROUTE_AUTH_OFF="${PROMO_ROUTE_AUTH_OFF:-1}"
PROMO_ROUTE_STRICT="${PROMO_ROUTE_STRICT:-0}"
VERIFY_PROMO_ROUTE="${VERIFY_PROMO_ROUTE:-1}"
VERIFY_PROMO_BASE_URL="${VERIFY_PROMO_BASE_URL:-https://brrrr.app/hkbeerco/byob/promo}"
VERIFY_PROMO_CODE="${VERIFY_PROMO_CODE:-BAB852}"
VERIFY_PROMO_EXPECT="${VERIFY_PROMO_EXPECT:-Thank you! Beer redeemed.}"
VERIFY_PROMO_STRICT="${VERIFY_PROMO_STRICT:-0}"

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

if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" || -z "$REMOTE_DIR" ]]; then
  cat >&2 <<'EOF'
Missing required configuration.

Set these values in $ENV_FILE or export them before running:
  REMOTE_USER   SSH username
  REMOTE_HOST   SSH hostname or IP
  REMOTE_DIR    Destination directory on the server

Optional variables:
  SOURCE_FILE   File to upload (default: byob-boss-invite.html)
  ASSET_DIRS    Space-separated directories to upload recursively
                (default: "images fonts promo")
  REMOTE_NAME   Filename to use on the server (default: same as SOURCE_FILE)
  SSH_PORT      SSH port (default: 22)
  SSH_KEY       Path to a private key file
  REMOTE_FILE_CHMOD  File mode applied to uploaded files (default: 644)
  REMOTE_DIR_CHMOD   Directory mode applied to uploaded dirs (default: 755)
  REMOTE_CHMOD_STRICT  Fail deploy when chmod step fails (default: 0)
  CONFIGURE_PROMO_ROUTE  Configure nginx promo route fallback (default: 1)
  REMOTE_NGINX_SITE  Remote nginx site file path (default: /etc/nginx/sites-available/brrrr.app)
  PROMO_ROUTE_PREFIX  URL prefix for promo routes (default: /hkbeerco/byob/promo/)
  PROMO_ROUTE_FALLBACK  Fallback file for dynamic promo paths
                        (default: /hkbeerco/byob/promo/index.html)
  PROMO_ROUTE_AUTH_OFF  Add auth_basic off in promo location block (default: 1)
  PROMO_ROUTE_STRICT  Fail deploy if promo route config step fails (default: 0)
  VERIFY_PROMO_ROUTE  Run post-deploy promo URL check (default: 1)
  VERIFY_PROMO_BASE_URL  Promo base URL without trailing code
                         (default: https://brrrr.app/hkbeerco/byob/promo)
  VERIFY_PROMO_CODE  Promo code used for verification (default: BAB852)
  VERIFY_PROMO_EXPECT  Text expected in promo landing response
                       (default: "Thank you! Beer redeemed.")
  VERIFY_PROMO_STRICT  Fail deploy if verification fails (default: 0)
  REMOTE_CHMOD       Legacy alias for REMOTE_FILE_CHMOD
  ENV_FILE      Alternate env file to source before deploy

Example:
  cp .env.deploy.example .env.deploy
  # edit .env.deploy, then run:
  ./deploy-scp.sh
EOF
  exit 1
fi

scp_args=(-P "$SSH_PORT")
ssh_args=(-p "$SSH_PORT")

if [[ -n "$SSH_KEY" ]]; then
  scp_args+=(-i "$SSH_KEY")
  ssh_args+=(-i "$SSH_KEY")
fi

target="$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/$REMOTE_NAME"

echo "Uploading $SOURCE_FILE to $target"
scp "${scp_args[@]}" "$SOURCE_FILE" "$target"

if [[ ${#asset_dirs[@]} -gt 0 ]]; then
  echo "Uploading asset directories: ${asset_dirs[*]}"
  for dir in "${asset_dirs[@]}"; do
    scp "${scp_args[@]}" -r "$dir" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
  done
fi

chmod_cmd="chmod '$REMOTE_FILE_CHMOD' '$REMOTE_DIR/$REMOTE_NAME'"
if [[ ${#asset_dirs[@]} -gt 0 ]]; then
  for dir in "${asset_dirs[@]}"; do
    chmod_cmd+=" && find '$REMOTE_DIR/$dir' -type d -exec chmod '$REMOTE_DIR_CHMOD' {} +"
    chmod_cmd+=" && find '$REMOTE_DIR/$dir' -type f -exec chmod '$REMOTE_FILE_CHMOD' {} +"
  done
fi

if ! ssh "${ssh_args[@]}" "$REMOTE_USER@$REMOTE_HOST" "$chmod_cmd"; then
  echo "Warning: Post-upload chmod step failed (upload may still be complete)." >&2
  if [[ "$REMOTE_CHMOD_STRICT" == "1" ]]; then
    echo "Failing because REMOTE_CHMOD_STRICT=1." >&2
    exit 1
  fi
fi

if [[ "$CONFIGURE_PROMO_ROUTE" == "1" ]]; then
  echo "Ensuring nginx promo route fallback exists in $REMOTE_NGINX_SITE"
  if ! ssh "${ssh_args[@]}" "$REMOTE_USER@$REMOTE_HOST" "bash -s" <<EOF
set -euo pipefail

REMOTE_NGINX_SITE="$REMOTE_NGINX_SITE"
PROMO_ROUTE_PREFIX="$PROMO_ROUTE_PREFIX"
PROMO_ROUTE_FALLBACK="$PROMO_ROUTE_FALLBACK"
PROMO_ROUTE_AUTH_OFF="$PROMO_ROUTE_AUTH_OFF"

if [[ ! -f "\$REMOTE_NGINX_SITE" ]]; then
  echo "Nginx site file not found: \$REMOTE_NGINX_SITE" >&2
  exit 1
fi

if sudo grep -Fq "location ^~ \$PROMO_ROUTE_PREFIX" "\$REMOTE_NGINX_SITE"; then
  sudo nginx -t >/dev/null
  sudo systemctl reload nginx
  exit 0
fi

tmp_file=\$(mktemp)
awk \
  -v routePrefix="\$PROMO_ROUTE_PREFIX" \
  -v routeFallback="\$PROMO_ROUTE_FALLBACK" \
  -v authOff="\$PROMO_ROUTE_AUTH_OFF" '
  {
    lines[NR] = \$0
  }
  END {
    inserted = 0
    for (i = 1; i <= NR; i++) {
      if (!inserted && i == NR && lines[i] ~ /^[[:space:]]*}[[:space:]]*$/) {
        print "    location ^~ " routePrefix " {"
        if (authOff == "1") {
          print "        auth_basic off;"
        }
        print "        try_files \\\$uri \\\$uri/ " routeFallback ";"
        print "    }"
        inserted = 1
      }
      print lines[i]
    }

    if (!inserted) {
      print ""
      print "location ^~ " routePrefix " {"
      if (authOff == "1") {
        print "    auth_basic off;"
      }
      print "    try_files \\\$uri \\\$uri/ " routeFallback ";"
      print "}"
    }
  }
' "\$REMOTE_NGINX_SITE" > "\$tmp_file"

sudo mv "\$tmp_file" "\$REMOTE_NGINX_SITE"
sudo nginx -t
sudo systemctl reload nginx
EOF
  then
    echo "Promo route configuration applied or already present."
  else
    echo "Warning: Promo route configuration step failed." >&2
    if [[ "$PROMO_ROUTE_STRICT" == "1" ]]; then
      echo "Failing because PROMO_ROUTE_STRICT=1." >&2
      exit 1
    fi
  fi
fi

if [[ "$VERIFY_PROMO_ROUTE" == "1" ]]; then
  verify_url="${VERIFY_PROMO_BASE_URL%/}/$VERIFY_PROMO_CODE/"
  echo "Verifying promo route: $verify_url"
  if curl -fsSL "$verify_url" | grep -Fq "$VERIFY_PROMO_EXPECT"; then
    echo "Promo route verification passed."
  else
    echo "Warning: Promo route verification failed for $verify_url" >&2
    if [[ "$VERIFY_PROMO_STRICT" == "1" ]]; then
      echo "Failing because VERIFY_PROMO_STRICT=1." >&2
      exit 1
    fi
  fi
fi

echo "Upload complete"