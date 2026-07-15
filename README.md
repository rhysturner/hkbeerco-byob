# hkbeerco-byob

## Overview

This repo contains a single-file static microsite for the BYOB campaign.

- Main app: `byob-boss-invite.html`
- Promo redeem app: `promo/index.html`
- Deployment helper: `deploy-scp.sh`
- Local deploy template: `.env.deploy.example`
- Internal project notes: `AGENTS.md`

There is no backend, build step, or package manager. The site is deployed by copying the HTML file directly to the server.

## Current App Behavior

- Single-page static microsite with inline CSS/JS in `byob-boss-invite.html`.
- Mobile-first responsive form layout (single column on small screens, two columns on larger screens).
- Age gate (18+) plus Promotion Terms modal before main interaction.
- Form inputs:
	- Boss Name (`#bossName`) is optional and defaults to `there`.
	- Meeting Topic (`#topic`) is required with a custom fallback field (`#topicCustom`) when `(write your own)` is selected.
	- Location mode toggle supports `Bar / Venue` and `Virtual`.
	- Venue (`#venue`) is required in bar mode and hidden in virtual mode.
	- Time field is shown in bar mode and hidden/blank in virtual mode.
- Calendar options:
	- Google Calendar
	- Outlook.com (personal)
	- Outlook (work/school)
	- Desktop App (`.ics` download)
- Venue map link behavior:
	- In bar mode, `#venueMapLink` points to Google Maps for the selected venue.
	- In virtual mode, map link text shows `Virtual` and is non-clickable.
- Promo code and URL mapping:
	- `Central: Belly and the Beer` -> `BAB852` -> `https://byob-hkbeer.co/promo/BAB852/`
	- `Wan Chai: Hoppy Junction` -> `HJT852` -> `https://byob-hkbeer.co/promo/HJT852/`
	- `Prince Edward: HANDS` -> `HND852` -> `https://byob-hkbeer.co/promo/HND852/`
	- `Kennedy Town: Smash'd Burger` -> `SMB852` -> `https://byob-hkbeer.co/promo/SMB852/`
	- `KT HK Beer Co` -> `KTH852` -> `https://byob-hkbeer.co/promo/KTH852/`
	- `Virtual` -> `VIR852` -> `https://byob-hkbeer.co/promo/VIR852/`
- Invite body formatting:
	- Paragraph-based template with blank lines.
	- Separate copy variants for bar mode vs virtual mode.
	- Plain text body used for Google/ICS.
	- HTML `<br><br>` body used for Outlook deep links.
	- Outlook note appends a `Promo QR` image generated at runtime from the promo URL and embedded as a base64 data URL.
- Promo redemption landing:
	- Dynamic single-page redemption UI at `promo/index.html`.
	- Reads promo code from either:
		- path style: `/promo/<PROMOCODE>/`
		- query style: `/promo/?code=<PROMOCODE>`
	- Displays a tick, promo code, venue mapping, and redemption copy (`Thank you! Beer redeemed.`).
	- Shows an invalid-code state when mapping is not found.

## Repo Structure

```text
byob-boss-invite.html   Main microsite
promo/index.html        Promo redemption landing app
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
- Default `ASSET_DIRS` now includes `promo`, so `promo/index.html` deploys with images/fonts.

### Nginx routing for dynamic promo paths

To make `/promo/<PROMOCODE>/` resolve to `promo/index.html` on static hosting, add a location fallback:

```nginx
location ^~ /promo/ {
	try_files $uri $uri/ /promo/index.html;
}
```

If you host under a subpath (for example `/hkbeerco/byob/`), use:

```nginx
location ^~ /hkbeerco/byob/promo/ {
	try_files $uri $uri/ /hkbeerco/byob/promo/index.html;
}
```

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

Live server details, Nginx auth notes, and troubleshooting steps are in [ops/server-notes.md](ops/server-notes.md).

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
3. Validate location mode flow:
	- Bar mode: venue dropdown visible and required; time field visible.
	- Virtual mode: venue dropdown hidden; time field hidden and blank.
4. Validate venue map link behavior:
	- Bar mode: map link opens selected venue in Google Maps.
	- Virtual mode: link displays `Virtual` and is non-clickable.
5. Validate promo mapping:
	- Each venue maps to its expected promo code and URL.
	- Virtual maps to `VIR852`.
6. Validate note copy behavior:
	- Bar mode uses bar-focused invite copy.
	- Virtual mode uses virtual-specific invite copy.
7. Validate Outlook note rendering:
	- `Promo QR` heading appears with embedded QR image.
8. Validate promo redemption routes:
	- Open a known code URL like `/promo/BAB852/` and verify tick + code + venue.
	- Open an unknown code URL like `/promo/NOPE123/` and verify invalid-code state.
