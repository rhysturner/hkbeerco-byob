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
README.md               Operational notes
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

## Current Live Server Details

Current live deployment target:

- Host: `brrrr.app`
- Server IP: `139.59.109.77`
- Web root for this microsite: `/var/www/brrrr.app/html/hkbeerco/byob`
- Live file: `/var/www/brrrr.app/html/hkbeerco/byob/index.html`
- Public URL: `https://brrrr.app/hkbeerco/byob/`

The main site root in Nginx is:

```text
/var/www/brrrr.app/html
```

## Basic Auth

The site-wide basic auth for `brrrr.app` is configured in:

- `/etc/nginx/sites-available/brrrr.app`
- `/etc/nginx/sites-enabled/brrrr.app`

The actual password file is:

- `/etc/nginx/.htpasswd_brrrr`

Relevant directives in the Nginx config:

```nginx
auth_basic "Restricted";
auth_basic_user_file /etc/nginx/.htpasswd_brrrr;
```

The BYOB microsite is currently public because this location exception was added:

```nginx
location ^~ /hkbeerco/byob/ {
	auth_basic off;
}
```

That means:

- Most of `brrrr.app` is still protected by basic auth.
- `https://brrrr.app/hkbeerco/byob/` is publicly accessible.

### How to update the basic auth credentials

If you want to change the username/password in future, update the htpasswd file on the server.

Interactive update:

```sh
sudo htpasswd /etc/nginx/.htpasswd_brrrr your-username
```

Create or replace a user non-interactively:

```sh
sudo htpasswd -b /etc/nginx/.htpasswd_brrrr your-username your-password
```

If you change the Nginx config itself, validate and reload:

```sh
sudo nginx -t
sudo systemctl reload nginx
```

## Deployment Troubleshooting

### 403 Forbidden after deploy

Cause we hit in this repo:

- The uploaded `index.html` was owned by `root:root` and had mode `600`.
- Nginx could traverse the directory but could not read the file.

Fix:

```sh
chmod 644 /var/www/brrrr.app/html/hkbeerco/byob/index.html
chown root:www-data /var/www/brrrr.app/html/hkbeerco/byob/index.html
```

The deploy script now automatically runs a remote `chmod`, which prevents the `600` file-mode issue from recurring.

### 401 Unauthorized instead of the page

Cause:

- Nginx basic auth was applied to the whole `brrrr.app` site.
- The microsite needed its own `auth_basic off` location block.

Fix:

- Add `location ^~ /hkbeerco/byob/ { auth_basic off; }` to the `brrrr.app` server block.
- Run `nginx -t` and reload Nginx.

## Operational Notes

- The deploy script reads local config from `.env.deploy` by default.
- The script supports `REMOTE_CHMOD`, defaulting to `644`.
- If deploys start failing, check `SSH_KEY` first. It must reference the private key file, not `id_rsa.pub`.
- If the site is public but prompts for login, inspect `/etc/nginx/sites-enabled/brrrr.app` first.
