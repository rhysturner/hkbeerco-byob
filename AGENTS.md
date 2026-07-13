# AGENTS.md — BYOB (Bring Your Own Boss)

## What this is

A single-file, client-only microsite for generating calendar invites to a real bar
venue during the World Cup final context.

There is no backend, database, auth, or API key usage. Everything runs in one
HTML file with inline CSS/JS:

- `byob-boss-invite.html`

## Current behavior (implementation truth)

The form captures:

- `bossName` (optional, defaults to `there`)
- `bossEmail` (optional, but required for auto-attendee behavior)
- `topic` (required dropdown)
- `topicCustom` (conditionally required when `(write your own)` is selected)
- `venue` (required dropdown)
- `startTime`, `endTime` (`datetime-local`, prefilled)
- `note` (optional extra paragraph appended to invite body)

### Topic behavior

`#topic` options:

- Q3 Planning Sync
- Budgeting Discussion
- Culture & Alignment Check-in
- Cross-Team Strategy Review
- H2 Priorities Catch-up
- (write your own)

When `(write your own)` is selected (`value="__custom__"`), `#topicCustom`
becomes visible and required.

### Venue behavior

`#venue` is a required dropdown with fixed bar options.

A map link is generated with:

- `mapsUrl(place)` -> `https://www.google.com/maps/search/?api=1&query=<encoded venue>`

The on-page `#venueMapLink` appears only when a venue value exists.

## Invite/attendee rules

Tracking mailbox:

- `TRACKING_EMAIL = hkbeerco@proton.me`

Attendees are only attached when `bossEmail` is present:

- with boss email: boss + tracking mailbox
- without boss email: no attendees auto-attached

## Calendar paths

Selection state uses `selectedCal` with these values:

- `google`
- `outlook-personal`
- `outlook-work`
- `ics`

### Google

Opens `calendar.google.com/calendar/render?action=TEMPLATE` with:

- `text`, `dates`, `details`, `location`
- `ctz` from `Intl.DateTimeFormat().resolvedOptions().timeZone`
- `add` as comma-separated attendees when available

### Outlook personal

Opens `outlook.live.com/.../compose` with:

- `subject`, `startdt`, `enddt`, `body`, `location`
- `to` as semicolon-separated attendees when available

### Outlook work/school

Opens `outlook.office.com/.../compose` with the same parameter pattern as
Outlook personal.

### ICS download

`downloadIcs(invite)` writes a minimal `VCALENDAR/VEVENT` with:

- `METHOD:REQUEST`
- `ORGANIZER:mailto:noreply@hongkongbeer.example`
- boss attendee only when boss email exists
- HK Beer attendee only when boss email exists

## Invite body formatting

Body content is built as paragraph blocks and rendered per channel:

- `bodyText` -> plain text with `\r\n\r\n` separators (Google + ICS)
- `bodyOutlook` -> HTML line breaks using `<br><br>` (Outlook links)

Template currently includes:

- `Generated Invite Copy Template`
- greeting
- World Cup line
- movement-forward line
- humor line
- free beer line
- food for thought
- redemption line
- sign-off
- optional appended `note` paragraph

## UI/layout

Mobile-first responsive layout:

- small screens: single-column field groups + single-column calendar options
- `@media (min-width: 640px)`: two-column field groups + two-column calendar grid

Current desktop calendar layout intentionally stays 2x2 to avoid label squeeze.

## Important UX notes

- There is no preview card anymore.
- Status feedback is shown in `#status` below the CTA.
- Validation blocks event generation when topic/venue requirements are not met.

## Deploy/docs pointers

- Deploy helper: `deploy-scp.sh`
- Local deploy config template: `.env.deploy.example`
- Server/auth/deploy operations: `ops/server-notes.md`
- High-level project/deploy guide: `README.md`

## Smoke test checklist

1. Select each calendar type and verify destination opens.
2. Validate topic behavior:
   - preset topic works
   - custom topic required when `(write your own)` is selected
3. Validate attendee behavior:
   - with boss email: boss + tracking mailbox attached
   - without boss email: no auto-attendees
4. Validate venue behavior:
   - selection required
   - map link appears for selected venue
5. Validate ICS:
   - attendees included only when boss email exists
