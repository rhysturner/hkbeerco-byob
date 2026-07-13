# AGENTS.md — BYOB (Bring Your Own Boss)

## What this is

A single-file, client-only microsite. Someone fills in their boss's name/email,
a cover-story meeting topic, and a real bar venue + time. One button opens
their own calendar app's native "create event" screen — pre-filled, with the
boss already added as a guest — so saving it there both blocks their own
calendar and sends a real invite to the boss in the same action.

**There is no backend.** No server, no database, no auth, no API keys. It's
one HTML file with inline CSS/JS. Ship it by hosting the static file
(Netlify Drop, GitHub Pages, Vercel, S3 — anything that serves static HTML).

File: `byob-boss-invite.html`

## Brand assets

- Logo (`BYOB` wordmark with bottle photo in the "O") is embedded directly
  in the HTML as a base64 `data:image/png` URI so the file stays single-file
  and portable. Source PNG is 1540×864, RGBA, transparent background around
  the letters.
- If the logo needs to change, swap the base64 string in
  `<img class="logo-img" src="data:image/png;base64,...">` — regenerate with:
  ```
  base64 -i new-logo.png | tr -d '\n'
  ```
- Palette (CSS custom properties at the top of `<style>`):
  | Token | Hex | Use |
  |---|---|---|
  | `--maroon-dark` | `#2A0B09` | hero gradient bottom |
  | `--maroon` | `#5C1712` | hero gradient mid |
  | `--maroon-light` | `#8C2A1E` | hero gradient top |
  | `--ember` | `#E8542E` | primary accent, links, buttons |
  | `--black` | `#140503` | page background, input fields |
  | `--panel` | `#1C0A08` | preview card background |
  | `--cream` | `#FBEFE6` | primary text |
- Fonts: **Anton** (display/headers), **Inter** (body), **Space Mono**
  (labels/meta) — loaded from Google Fonts via `<link>` in `<head>`. Requires
  internet access to render correctly; no local font fallback is bundled.

## Form fields → what they do

| Field | id | Required | Notes |
|---|---|---|---|
| Boss Name | `bossName` | no (defaults to "there") | Used in salutation + as ATTENDEE `CN` in .ics |
| Boss Email | `bossEmail` | no, but needed for auto-invite | Without it, the event still gets created but no guest is attached — user has to add the boss manually |
| Meeting Topic | `topic` | no (defaults to "Team Sync") | The corporate-sounding cover subject line |
| Bar / Venue | `venue` | no (defaults to "a bar TBD") | Shown honestly as the real location — also drives the Google Maps link |
| Doors Open / Last Order | `startTime` / `endTime` | pre-filled | `datetime-local` inputs, defaulted to **Sun Jul 19, 2026 11:30 PM → Mon Jul 20, 2026 4:00 AM** (World Cup 2026 final, adjusted to HKT). Hardcoded in JS as `defaultStart`/`defaultEnd` — **update this every time the target event changes.** |
| Pre-template Event Details | `note` | no | Free text appended into the generated message body |

## Calendar delivery — the four paths

Selection state lives in the JS variable `selectedCal`, set by clicking a
`.cal-option` tile (`data-cal` attribute holds the value). Default on load is
`outlook-work`.

1. **`google`** — Opens `calendar.google.com/calendar/render?action=TEMPLATE`
   with `&add=<bossEmail>` to attach the boss as a guest, and `&ctz=<IANA tz>`
   (from `Intl.DateTimeFormat().resolvedOptions().timeZone`) so the time
   doesn't get misread as UTC. **This was a real bug we hit** — omitting
   `ctz` caused Google to sometimes show the wrong hour. Don't remove it.

2. **`outlook-personal`** — `outlook.live.com/calendar/.../compose` for
   personal Microsoft accounts (@outlook.com, @hotmail.com, @live.com).

3. **`outlook-work`** — `outlook.office.com/calendar/.../compose` for
   Microsoft 365 / organizational accounts. **These two Outlook domains are
   not interchangeable** — pointing a work account at `outlook.live.com` (or
   vice versa) throws the user into a sign-in loop that appears to fail
   silently. This is why the UI splits Outlook into two explicit options
   instead of one, with copy explaining which to pick.

4. **`ics`** (labeled "Desktop App" in the UI) — Generates an `.ics` file
   client-side (`downloadIcs()`) with a proper `ATTENDEE` field for the boss
   and downloads it via a `Blob` + temporary `<a download>`. This is the
   **only path that opens a native desktop app** (Outlook desktop, Apple
   Calendar, etc. — whatever's set as the OS default calendar handler) and
   the only one with zero web sign-in dependency. Recommend this as the
   fallback whenever the web options misbehave.

All four build the **same underlying subject/body/location** — see
`addEventBtn` click handler for the single source of truth on invite content.

## Google Maps integration

`mapsUrl(place)` builds a plain search URL:
`https://www.google.com/maps/search/?api=1&query=<venue text>`. No API key,
no geocoding — it's a dumb search link, so accuracy depends entirely on how
specific the typed venue string is (recommend placeholder copy nudges users
toward "Venue Name, Neighborhood, City").

This link appears in three places, all built from the same `mapLink` value:
1. Live preview link under the Venue field (`#venueMapLink`), toggled via
   the `input` event listener on `#venue`.
2. Inline in the generated message body (`Map: <link>`).
3. In the on-page preview card (`#pvWhere`).

If this ever needs real geocoding/place accuracy (e.g. autocomplete, verified
addresses), that requires the Google Places API and a key — currently
intentionally avoided to keep this a zero-backend, zero-key static file.

## The .ics generator (`downloadIcs`)

Builds a minimal but valid `VCALENDAR`/`VEVENT` block manually (no library).
Notable fields:
- `METHOD:REQUEST` + `ORGANIZER` + `ATTENDEE;RSVP=TRUE` — this combination is
  what makes calendar apps treat it as an actual invite (prompting "notify
  attendee?") rather than a plain personal event.
- `ORGANIZER` is currently a placeholder (`noreply@hongkongbeer.example`) —
  **replace with a real sending address** if this goes further than a demo,
  otherwise some mail/calendar clients may flag or reject it.
- Times are emitted as floating local time (no `Z`, no `TZID`) — consistent
  with the rest of the app, but worth revisiting if the team wants strict
  timezone correctness in the .ics path the way `ctz` fixed it for Google.

## Known limitations / things to fix next

- **No timezone parameter on the Outlook links or the .ics file** — only the
  Google Calendar link got the `ctz` fix. If users report wrong times on
  Outlook or .ics, this is the next place to look.
- **No input validation** — empty boss email just silently skips the guest
  attachment; there's no format-checking on the email field.
- **No analytics/tracking** — there's currently no way to know how many
  people actually completed an invite vs. just loaded the page.
- **Hardcoded event date** — `defaultStart`/`defaultEnd` in the `<script>`
  block need to be manually updated for any future event; nothing is
  data-driven.
- **Fonts require network access** — no bundled/self-hosted font fallback,
  so the page will fall back to system fonts if Google Fonts is blocked
  (e.g. corporate proxies).
- **No backend means no real send-tracking or RSVP handling** — this is by
  design for now, but if the team wants to move to Phase 2 (real
  OAuth-connected app), that's a different architecture entirely and should
  be scoped separately, not bolted onto this file.

## How to test locally

No build step. Just open the HTML file directly in a browser, or serve it:
```
python3 -m http.server 8000
```
There's no test suite. Recommended smoke test before any deploy:
1. Fill all fields, pick each of the 4 calendar options in turn, click
   **+ Add Event**, confirm the right destination opens/downloads.
2. Check the generated `.ics` in a text editor — confirm `ATTENDEE` line
   appears when an email is provided, and is absent when it isn't.
3. Verify the Maps link updates live as you type in the Venue field.
