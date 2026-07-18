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
ASSET_DIRS="${ASSET_DIRS:-images fonts promo video qr BAB852 HJT852 HND852 SMB852 KTH852 VIR852}"
EXTRA_FILES="${EXTRA_FILES:-virtual-code.html}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_DIR="${REMOTE_DIR:-}"
REMOTE_NAME="${REMOTE_NAME:-$SOURCE_FILE}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY="${SSH_KEY:-}"
REMOTE_FILE_CHMOD="${REMOTE_FILE_CHMOD:-${REMOTE_CHMOD:-644}}"
REMOTE_DIR_CHMOD="${REMOTE_DIR_CHMOD:-755}"
REMOTE_CHMOD_STRICT="${REMOTE_CHMOD_STRICT:-0}"
SSH_RETRIES="${SSH_RETRIES:-5}"
SSH_RETRY_DELAY="${SSH_RETRY_DELAY:-2}"
SSH_CONTROL_MASTER="${SSH_CONTROL_MASTER:-1}"
SSH_CONTROL_PERSIST="${SSH_CONTROL_PERSIST:-10m}"
SSH_CONTROL_PATH="${SSH_CONTROL_PATH:-$HOME/.ssh/cm-%r@%h:%p}"
CONFIGURE_PROMO_ROUTE="${CONFIGURE_PROMO_ROUTE:-1}"
REMOTE_NGINX_SITE="${REMOTE_NGINX_SITE:-/etc/nginx/sites-available/brrrr.app}"
PROMO_ROUTE_PREFIX="${PROMO_ROUTE_PREFIX:-/hkbeerco/byob/promo/}"
PROMO_ROUTE_FALLBACK="${PROMO_ROUTE_FALLBACK:-/hkbeerco/byob/promo/index.html}"
PROMO_ROUTE_AUTH_OFF="${PROMO_ROUTE_AUTH_OFF:-1}"
PROMO_AUTH_ENABLE="${PROMO_AUTH_ENABLE:-0}"
PROMO_AUTH_REALM="${PROMO_AUTH_REALM:-Promo Redemption}"
PROMO_AUTH_USER_FILE="${PROMO_AUTH_USER_FILE:-/etc/nginx/.htpasswd_promo}"
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

extra_files=()
if [[ -n "$EXTRA_FILES" ]]; then
  # shellcheck disable=SC2206
  extra_files=($EXTRA_FILES)
fi

for dir in "${asset_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "Asset directory not found: $dir" >&2
    exit 1
  fi
done

for file in "${extra_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Extra file not found: $file" >&2
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
                (default: "images fonts promo video qr BAB852 HJT852 HND852 SMB852 KTH852 VIR852")
  EXTRA_FILES   Space-separated root files to upload
                (default: "virtual-code.html")
  REMOTE_NAME   Filename to use on the server (default: same as SOURCE_FILE)
  SSH_PORT      SSH port (default: 22)
  SSH_KEY       Path to a private key file
  REMOTE_FILE_CHMOD  File mode applied to uploaded files (default: 644)
  REMOTE_DIR_CHMOD   Directory mode applied to uploaded dirs (default: 755)
  REMOTE_CHMOD_STRICT  Fail deploy when chmod step fails (default: 0)
  SSH_RETRIES   Number of SSH retries for post-upload steps (default: 5)
  SSH_RETRY_DELAY  Seconds between SSH retries (default: 2)
  SSH_CONTROL_MASTER  Reuse one SSH connection to reduce prompts (default: 1)
  SSH_CONTROL_PERSIST  Keep master connection alive (default: 10m)
  SSH_CONTROL_PATH  Control socket path pattern
                    (default: ~/.ssh/cm-%r@%h:%p)
  CONFIGURE_PROMO_ROUTE  Configure nginx promo route fallback (default: 1)
  REMOTE_NGINX_SITE  Remote nginx site file path (default: /etc/nginx/sites-available/brrrr.app)
  PROMO_ROUTE_PREFIX  URL prefix for promo routes (default: /hkbeerco/byob/promo/)
  PROMO_ROUTE_FALLBACK  Fallback file for dynamic promo paths
                        (default: /hkbeerco/byob/promo/index.html)
  PROMO_ROUTE_AUTH_OFF  Add auth_basic off in promo location block (default: 1)
  PROMO_AUTH_ENABLE  Protect /promo/* with basic auth (default: 0)
  PROMO_AUTH_REALM  Basic auth realm for /promo/* (default: "Promo Redemption")
  PROMO_AUTH_USER_FILE  Remote htpasswd file for /promo/*
                        (default: /etc/nginx/.htpasswd_promo)
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

if [[ "$SSH_CONTROL_MASTER" == "1" ]]; then
  scp_args+=(-o ControlMaster=auto -o "ControlPersist=$SSH_CONTROL_PERSIST" -o "ControlPath=$SSH_CONTROL_PATH")
  ssh_args+=(-o ControlMaster=auto -o "ControlPersist=$SSH_CONTROL_PERSIST" -o "ControlPath=$SSH_CONTROL_PATH")
fi

target="$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/$REMOTE_NAME"

ssh_retry_run() {
  local command="$1"
  local attempt=1
  while true; do
    if ssh "${ssh_args[@]}" "$REMOTE_USER@$REMOTE_HOST" "$command"; then
      return 0
    fi
    if [[ "$attempt" -ge "$SSH_RETRIES" ]]; then
      return 1
    fi
    echo "SSH command failed (attempt $attempt/$SSH_RETRIES). Retrying in ${SSH_RETRY_DELAY}s..." >&2
    attempt=$((attempt + 1))
    sleep "$SSH_RETRY_DELAY"
  done
}

ssh_retry_script() {
  local script="$1"
  local attempt=1
  while true; do
    if ssh "${ssh_args[@]}" "$REMOTE_USER@$REMOTE_HOST" "bash -s" <<<"$script"; then
      return 0
    fi
    if [[ "$attempt" -ge "$SSH_RETRIES" ]]; then
      return 1
    fi
    echo "SSH script failed (attempt $attempt/$SSH_RETRIES). Retrying in ${SSH_RETRY_DELAY}s..." >&2
    attempt=$((attempt + 1))
    sleep "$SSH_RETRY_DELAY"
  done
}

if [[ "$SSH_CONTROL_MASTER" == "1" ]]; then
  # Prime a single SSH master connection so subsequent scp/ssh calls reuse it.
  if ! ssh_retry_run "true"; then
    echo "Warning: Could not pre-establish SSH control master. Continuing without warm connection." >&2
  fi
fi

echo "Uploading $SOURCE_FILE to $target"
scp "${scp_args[@]}" "$SOURCE_FILE" "$target"

if [[ ${#asset_dirs[@]} -gt 0 ]]; then
  echo "Uploading asset directories: ${asset_dirs[*]}"
  for dir in "${asset_dirs[@]}"; do
    scp "${scp_args[@]}" -r "$dir" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
  done
fi

if [[ ${#extra_files[@]} -gt 0 ]]; then
  echo "Uploading extra files: ${extra_files[*]}"
  for file in "${extra_files[@]}"; do
    scp "${scp_args[@]}" "$file" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
  done
fi

chmod_cmd="chmod '$REMOTE_FILE_CHMOD' '$REMOTE_DIR/$REMOTE_NAME'"
if [[ ${#asset_dirs[@]} -gt 0 ]]; then
  for dir in "${asset_dirs[@]}"; do
    chmod_cmd+=" && find '$REMOTE_DIR/$dir' -type d -exec chmod '$REMOTE_DIR_CHMOD' {} +"
    chmod_cmd+=" && find '$REMOTE_DIR/$dir' -type f -exec chmod '$REMOTE_FILE_CHMOD' {} +"
  done
fi

if [[ ${#extra_files[@]} -gt 0 ]]; then
  for file in "${extra_files[@]}"; do
    chmod_cmd+=" && chmod '$REMOTE_FILE_CHMOD' '$REMOTE_DIR/$file'"
  done
fi

if ! ssh_retry_run "$chmod_cmd"; then
  echo "Warning: Post-upload chmod step failed (upload may still be complete)." >&2
  if [[ "$REMOTE_CHMOD_STRICT" == "1" ]]; then
    echo "Failing because REMOTE_CHMOD_STRICT=1." >&2
    exit 1
  fi
fi

promo_route_configured=1
if [[ "$CONFIGURE_PROMO_ROUTE" == "1" ]]; then
  echo "Ensuring nginx promo route fallback exists in $REMOTE_NGINX_SITE"
  route_script=$(cat <<EOF
set -euo pipefail

REMOTE_NGINX_SITE="$REMOTE_NGINX_SITE"
PROMO_ROUTE_PREFIX="$PROMO_ROUTE_PREFIX"
PROMO_ROUTE_FALLBACK="$PROMO_ROUTE_FALLBACK"
PROMO_ROUTE_AUTH_OFF="$PROMO_ROUTE_AUTH_OFF"
PROMO_AUTH_ENABLE="$PROMO_AUTH_ENABLE"
PROMO_AUTH_REALM="$PROMO_AUTH_REALM"
PROMO_AUTH_USER_FILE="$PROMO_AUTH_USER_FILE"

if [[ ! -f "\$REMOTE_NGINX_SITE" ]]; then
  echo "Nginx site file not found: \$REMOTE_NGINX_SITE" >&2
  exit 1
fi

if [[ "\$PROMO_AUTH_ENABLE" == "1" && ! -f "\$PROMO_AUTH_USER_FILE" ]]; then
  echo "Promo auth file not found: \$PROMO_AUTH_USER_FILE" >&2
  echo "Create it with: sudo htpasswd -c \$PROMO_AUTH_USER_FILE <username>" >&2
  exit 1
fi

tmp_file=\$(mktemp)
awk \
  -v routePrefix="\$PROMO_ROUTE_PREFIX" \
  -v routeFallback="\$PROMO_ROUTE_FALLBACK" \
  -v authOff="\$PROMO_ROUTE_AUTH_OFF" \
  -v authEnable="\$PROMO_AUTH_ENABLE" \
  -v authRealm="\$PROMO_AUTH_REALM" \
  -v authUserFile="\$PROMO_AUTH_USER_FILE" '
  function print_block() {
    print "    location ^~ " routePrefix " {"
    if (authEnable == "1") {
      print "        auth_basic \"" authRealm "\";"
      print "        auth_basic_user_file " authUserFile ";"
    } else if (authOff == "1") {
      print "        auth_basic off;"
    }
    print "        try_files " sprintf("%c", 36) "uri " sprintf("%c", 36) "uri/ " routeFallback ";"
    print "    }"
  }

  function delta_braces(line,    a, b, opens, closes) {
    a = line
    b = line
    opens = gsub(/\{/, "{", a)
    closes = gsub(/\}/, "}", b)
    return opens - closes
  }

  {
    lines[NR] = \$0
  }
  END {
    i = 1
    inserted = 0
    replaced = 0
    while (i <= NR) {
      if (!replaced && index(lines[i], "location ^~ " routePrefix " {") > 0) {
        print_block()
        replaced = 1
        depth = 0
        do {
          depth += delta_braces(lines[i])
          i++
        } while (i <= NR && depth > 0)
        continue
      }

      if (!replaced && !inserted && i == NR && lines[i] ~ /^[[:space:]]*}[[:space:]]*$/) {
        print_block()
        inserted = 1
      }

      print lines[i]
      i++
    }

    if (!replaced && !inserted) {
      print ""
      print_block()
    }
  }
' \
  "\$REMOTE_NGINX_SITE" > "\$tmp_file"

sudo mv "\$tmp_file" "\$REMOTE_NGINX_SITE"
sudo nginx -t
sudo systemctl reload nginx
EOF
)
  if ssh_retry_script "$route_script"
  then
    echo "Promo route configuration applied or already present."
  else
    promo_route_configured=0
    echo "Warning: Promo route configuration step failed." >&2
    if [[ "$PROMO_ROUTE_STRICT" == "1" ]]; then
      echo "Failing because PROMO_ROUTE_STRICT=1." >&2
      exit 1
    fi
  fi
fi

if [[ "$VERIFY_PROMO_ROUTE" == "1" ]]; then
  if [[ "$CONFIGURE_PROMO_ROUTE" == "1" && "$promo_route_configured" == "0" ]]; then
    echo "Skipping promo route verification because route configuration failed."
    echo "Re-run deploy or fix SSH connectivity, then verify route again." >&2
    echo "Upload complete"
    exit 0
  fi

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

if [[ "$SSH_CONTROL_MASTER" == "1" ]]; then
  ssh "${ssh_args[@]}" -O exit "$REMOTE_USER@$REMOTE_HOST" >/dev/null 2>&1 || true
fi

echo "Upload complete"