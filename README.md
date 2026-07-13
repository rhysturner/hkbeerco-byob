# hkbeerco-byob

## Overview

This repo contains a single-file static microsite for the BYOB campaign.

- Main app: `byob-boss-invite.html`
- Deployment helper: `deploy-scp.sh`
- Local deploy template: `.env.deploy.example`
- Internal project notes: `AGENTS.md`

There is no backend, build step, or package manager. The site is deployed by copying the HTML file directly to the server.

## Current App Behavior

- Single-page static microsite with inline CSS/JS in `byob-boss-invite.html`.
- Mobile-first responsive form layout (single column on small screens, two columns on larger screens).
- Required dropdowns for:
	- Meeting Topic (`#topic`) with preset options and a custom fallback field (`#topicCustom`).
	- Venue (`#venue`) with fixed bar options.
- Optional fields:
	- Boss Name (`#bossName`) defaults to `there`.
	- Boss Email (`#bossEmail`) controls whether attendees are auto-attached.
	- Pre-template Event Details (`#note`) appends a final extra paragraph.
- Calendar options:
	- Google Calendar
	- Outlook.com (personal)
	- Outlook (work/school)
	- Desktop App (`.ics` download)
- Tracking attendee rule:
	- `hkbeerco@proton.me` is only added when Boss Email is present.
- Invite body formatting:
	- Paragraph-based template with blank lines.
	- Plain text body used for Google/ICS.
	- HTML `<br><br>` body used for Outlook deep links.

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

## Manual Smoke Test

1. Select each calendar type and confirm the expected destination opens.
2. Validate topic flow:
	- Preset topic selected.
	- `(write your own)` selected and custom value required.
3. Validate guest flow:
	- Without Boss Email: no attendees auto-added.
	- With Boss Email: boss + `hkbeerco@proton.me` auto-added.
4. Validate venue flow:
	- Venue is required.
	- Map link appears after venue selection.
5. Validate `.ics` file content:
	- Includes boss attendee and HK Beer attendee only when boss email exists.
