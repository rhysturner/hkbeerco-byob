# hkbeerco-byob

## Overview

This repo contains a single-file static microsite for the BYOB campaign.

- Main app: `byob-boss-invite.html`
- Promo redeem app: `promo/index.html`
- Dev deploy helper (`brrrr.app`): `deploy-scp.sh`
- Live bootstrap+deploy (`byob-hkbeer.co`): `deploy-byob-server.sh`
- Local deploy templates: `.env.deploy.example` and `.env.byob.example`
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
deploy-scp.sh           Dev deploy script (brrrr.app)
deploy-byob-server.sh   Live server setup + deploy script (byob-hkbeer.co)
.env.deploy.example     Template for local deploy config
.env.byob.example       Template for live domain/server bootstrap config
ops/server-notes.md     Live server and auth notes
README.md               Project overview and deploy guide
AGENTS.md               Project-specific implementation notes
```

## Local Editing

Open `byob-boss-invite.html` directly in a browser, or serve the folder locally:

```sh
python3 -m http.server 8000
```

## Deployment Scripts

This repo has two deployment scripts for different targets.

### 1) Dev deploy (`brrrr.app`) using `deploy-scp.sh`

Use this script to deploy to the existing `brrrr.app` path (`/hkbeerco/byob/`) and keep promo redemption routes working.

Run:

```sh
chmod +x deploy-scp.sh
cp .env.deploy.example .env.deploy
# edit .env.deploy
./deploy-scp.sh
```

What it does:

- Uploads `SOURCE_FILE` (usually `byob-boss-invite.html`) as `REMOTE_NAME`.
- Uploads asset directories (default `images fonts promo`).
- Applies remote file/dir chmods.
- Ensures Nginx promo fallback exists for dynamic promo URLs under `/hkbeerco/byob/promo/`.
- Optionally verifies a known promo URL after deploy.

Important `.env.deploy` variables:

- Core SSH/paths:
	- `REMOTE_USER`, `REMOTE_HOST`, `REMOTE_DIR`, `REMOTE_NAME`, `SSH_PORT`, `SSH_KEY`
- Upload payload:
	- `SOURCE_FILE`, `ASSET_DIRS`
- File permissions:
	- `REMOTE_FILE_CHMOD`, `REMOTE_DIR_CHMOD`
	- `REMOTE_CHMOD_STRICT` (default `0` warns instead of failing on chmod step)
- Promo route config:
	- `CONFIGURE_PROMO_ROUTE` (default `1`)
	- `REMOTE_NGINX_SITE` (default `/etc/nginx/sites-available/brrrr.app`)
	- `PROMO_ROUTE_PREFIX` (default `/hkbeerco/byob/promo/`)
	- `PROMO_ROUTE_FALLBACK` (default `/hkbeerco/byob/promo/index.html`)
	- `PROMO_ROUTE_AUTH_OFF` (default `1`)
	- `PROMO_AUTH_ENABLE` (default `0`)
	- `PROMO_AUTH_REALM` (default `Promo Redemption`)
	- `PROMO_AUTH_USER_FILE` (default `/etc/nginx/.htpasswd_promo`)
	- `PROMO_ROUTE_STRICT` (default `0`)
- Promo verification:
	- `VERIFY_PROMO_ROUTE` (default `1`)
	- `VERIFY_PROMO_BASE_URL` (default `https://brrrr.app/hkbeerco/byob/promo`)
	- `VERIFY_PROMO_CODE` (default `BAB852`)
	- `VERIFY_PROMO_EXPECT` (quote this value if it contains spaces)
	- `VERIFY_PROMO_STRICT` (default `0`)

Useful overrides:

```sh
# strict mode for both route config + URL verification
PROMO_ROUTE_STRICT=1 VERIFY_PROMO_STRICT=1 ./deploy-scp.sh

# run with a different env file
ENV_FILE=.env.staging ./deploy-scp.sh
```

### 2) Live domain bootstrap + deploy (`byob-hkbeer.co`) using `deploy-byob-server.sh`

Use this script for the dedicated live domain. It can install/configure Nginx + certbot and then upload the site bundle.

Run:

```sh
chmod +x deploy-byob-server.sh
cp .env.byob.example .env.byob
# edit .env.byob
./deploy-byob-server.sh
```

What it does:

- Server setup phase (optional):
	- Installs Nginx/certbot (if needed)
	- Writes Nginx server config for `DOMAIN` + `WWW_DOMAIN`
	- Configures promo fallback route:
		- `location ^~ /promo/ { try_files $uri $uri/ /promo/index.html; }`
	- Enables site, validates Nginx, reloads
	- Issues/renews certbot certs unless disabled
- Upload phase:
	- Bundles `SOURCE_FILE` plus `ASSET_DIRS` and extracts to `WEB_ROOT`
	- Applies chmod/chown recursively

Important `.env.byob` variables:

- SSH: `REMOTE_USER`, `REMOTE_HOST`, `SSH_PORT`, `SSH_KEY`
- Domain/SSL: `DOMAIN`, `WWW_DOMAIN`, `LE_EMAIL`, `SKIP_CERTBOT`, `CERTBOT_STAGING`
- Promo auth (optional): `PROMO_AUTH_ENABLE`, `PROMO_AUTH_REALM`, `PROMO_AUTH_USER_FILE`
- Paths/payload: `WEB_ROOT`, `SOURCE_FILE`, `TARGET_HTML`, `ASSET_DIRS`
- Permissions: `REMOTE_FILE_CHMOD`, `REMOTE_DIR_CHMOD`
- Toggles: `SKIP_SERVER_SETUP`, `SKIP_UPLOAD`

To password-protect `/promo/*` on the live domain:

```sh
# on server
sudo htpasswd -c /etc/nginx/.htpasswd_promo your-username
```

Then set in `.env.byob`:

```sh
PROMO_AUTH_ENABLE=1
PROMO_AUTH_REALM="Promo Redemption"
PROMO_AUTH_USER_FILE=/etc/nginx/.htpasswd_promo
```

Useful runs:

```sh
# upload only (skip server/bootstrap changes)
SKIP_SERVER_SETUP=1 ./deploy-byob-server.sh

# setup only (skip content upload)
SKIP_UPLOAD=1 ./deploy-byob-server.sh
```

### Troubleshooting quick notes

- If deploy ends with SSH connection errors after uploads, content may already be live.
- If `.env` sourcing fails with `command not found`, check for unquoted values with spaces.
- If promo verification returns 404, confirm Nginx promo fallback block is present and reloaded.

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
