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
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_DIR="${REMOTE_DIR:-}"
REMOTE_NAME="${REMOTE_NAME:-$SOURCE_FILE}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY="${SSH_KEY:-}"
REMOTE_CHMOD="${REMOTE_CHMOD:-644}"

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Source file not found: $SOURCE_FILE" >&2
  exit 1
fi

if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" || -z "$REMOTE_DIR" ]]; then
  cat >&2 <<'EOF'
Missing required configuration.

Set these values in $ENV_FILE or export them before running:
  REMOTE_USER   SSH username
  REMOTE_HOST   SSH hostname or IP
  REMOTE_DIR    Destination directory on the server

Optional variables:
  SOURCE_FILE   File to upload (default: byob-boss-invite.html)
  REMOTE_NAME   Filename to use on the server (default: same as SOURCE_FILE)
  SSH_PORT      SSH port (default: 22)
  SSH_KEY       Path to a private key file
  REMOTE_CHMOD  File mode applied after upload (default: 644)
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
ssh "${ssh_args[@]}" "$REMOTE_USER@$REMOTE_HOST" "chmod '$REMOTE_CHMOD' '$REMOTE_DIR/$REMOTE_NAME'"
echo "Upload complete"