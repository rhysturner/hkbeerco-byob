# hkbeerco-byob

## Overview

This repo contains a single-file static microsite for the BYOB campaign.

- Main app: `byob-boss-invite.html`
- Deployment helper: `deploy-scp.sh`
- Local deploy template: `.env.deploy.example`
- Internal project notes: `AGENTS.md`

There is no backend, build step, or package manager. The site is deployed by copying the HTML file directly to the server.

## Repo Structure

```text
byob-boss-invite.html   Main microsite
deploy-scp.sh           SCP deploy script
.env.deploy.example     Template for local deploy config
ops/server-notes.md     Live server and auth notes
README.md               Project overview and deploy guide
AGENTS.md               Project-specific implementation notes
```

## Local Editing

Open `byob-boss-invite.html` directly in a browser, or serve the folder locally:

```sh
python3 -m http.server 8000
```

## Deploy with SCP

This project is a single static HTML file, so deployment is a straight `scp` upload.

For safer repeated deploys, keep server settings in a local env file and keep the actual private key in `~/.ssh` or your SSH agent. Do not store raw private key contents in the repo.

### Reusable helper script

The repo includes `deploy-scp.sh` so you can avoid retyping the command:

```sh
chmod +x deploy-scp.sh
cp .env.deploy.example .env.deploy
# edit .env.deploy
./deploy-scp.sh
```

Example `.env.deploy`:

```sh
REMOTE_USER=user
REMOTE_HOST=example.com
REMOTE_DIR=/var/www/html
REMOTE_NAME=index.html
SSH_PORT=22
SSH_KEY=~/.ssh/your-key
SOURCE_FILE=byob-boss-invite.html
```

Notes:

- `SSH_KEY` must point to the private key, not the `.pub` file.
- If you use `ssh-agent`, you can omit `SSH_KEY` entirely.
- `.env.deploy` and `.env.deploy.local` are gitignored.
- The deploy script now runs a remote `chmod` after upload so the file stays readable by Nginx.

If you want to use a different env file name:

```sh
ENV_FILE=.env.production ./deploy-scp.sh
```

### One-off manual command

```sh
scp byob-boss-invite.html user@example.com:/var/www/html/index.html
```

If your server uses a custom SSH port or private key:

```sh
scp -P 2222 -i ~/.ssh/your-key byob-boss-invite.html user@example.com:/var/www/html/index.html
```

## Operations

Live server details, Nginx auth notes, and troubleshooting steps are in [ops/server-notes.md](/Users/rhysturner/Development/Publicis/hk-beer-co/ops/server-notes.md).

That file covers:

- Current production host and filesystem paths
- Where `brrrr.app` basic auth is configured
- Where the htpasswd file lives
- The public exception for `/hkbeerco/byob/`
- Deployment troubleshooting for the 403 and 401 issues already encountered

## Operational Notes

- The deploy script reads local config from `.env.deploy` by default.
- The script supports `REMOTE_CHMOD`, defaulting to `644`.
- If deploys start failing, check `SSH_KEY` first. It must reference the private key file, not `id_rsa.pub`.
