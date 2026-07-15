# Server Notes

## Live Deployment

- Host: `brrrr.app`
- Server IP: `139.59.109.77`
- Main Nginx root: `/var/www/brrrr.app/html`
- Microsite directory: `/var/www/brrrr.app/html/hkbeerco/byob`
- Live file: `/var/www/brrrr.app/html/hkbeerco/byob/index.html`
- Public URL: `https://brrrr.app/hkbeerco/byob/`

## Basic Auth

Site-wide basic auth for `brrrr.app` is configured in:

- `/etc/nginx/sites-available/brrrr.app`
- `/etc/nginx/sites-enabled/brrrr.app`

Password file:

- `/etc/nginx/.htpasswd_brrrr`

Relevant directives:

```nginx
auth_basic "Restricted";
auth_basic_user_file /etc/nginx/.htpasswd_brrrr;
```

The BYOB microsite is public because this exception was added:

```nginx
location ^~ /hkbeerco/byob/ {
    auth_basic off;
}
```

To support dynamic promo redemption URLs like `/hkbeerco/byob/promo/BAB852/`, add:

```nginx
location ^~ /hkbeerco/byob/promo/ {
    auth_basic off;
    try_files $uri $uri/ /hkbeerco/byob/promo/index.html;
}
```

That means most of `brrrr.app` is still behind basic auth, but `https://brrrr.app/hkbeerco/byob/` is public.

## Updating Basic Auth

Interactive update:

```sh
sudo htpasswd /etc/nginx/.htpasswd_brrrr your-username
```

Non-interactive update:

```sh
sudo htpasswd -b /etc/nginx/.htpasswd_brrrr your-username your-password
```

After Nginx config changes:

```sh
sudo nginx -t
sudo systemctl reload nginx
```

## Deploy Notes

The repo deploy helper is `deploy-scp.sh`.

Local config is read from `.env.deploy` by default.

Important settings:

- `REMOTE_USER`
- `REMOTE_HOST`
- `REMOTE_DIR`
- `REMOTE_NAME`
- `SSH_PORT`
- `SSH_KEY`
- `REMOTE_CHMOD`

Important caveat:

- `SSH_KEY` must point to the private key, not the `.pub` file.
- If you use `ssh-agent`, `SSH_KEY` can be omitted.

The deploy script now runs a remote `chmod` after upload so the web server can read the file.

## Troubleshooting

### 403 Forbidden

Cause encountered here:

- Uploaded `index.html` had mode `600` and was unreadable by Nginx.

Manual fix:

```sh
chmod 644 /var/www/brrrr.app/html/hkbeerco/byob/index.html
chown root:www-data /var/www/brrrr.app/html/hkbeerco/byob/index.html
```

### 401 Unauthorized

Cause encountered here:

- Site-wide basic auth was active for `brrrr.app`.
- The microsite needed its own `auth_basic off` location block.

Fix:

- Add `location ^~ /hkbeerco/byob/ { auth_basic off; }` to the `brrrr.app` server block.
- Validate and reload Nginx.