# SecureQR brand (direction B, "Clear")

Reference mock-up: `design/branding-v1.html` (direction B section). Match it.

- Name: **SecureQR** (wordmark: "Secure" in ink, "QR" in accent, weight 800, tight tracking)
- Tagline: "See where it goes before you go."
- Voice: plain, calm, no jargon. "We open the link on our server, never on your phone."

## Colour

| token | light | dark | use |
|---|---|---|---|
| bg | `#F5F7FB` | `#0E1324` | screen background |
| surface | `#FFFFFF` | `#171D33` | cards |
| line | `#E1E6F0` | `#29314D` | 1 px card borders, dividers |
| ink | `#111933` | `#EEF1FA` | primary text |
| muted | `#5F6B85` | `#9AA5C0` | secondary text, labels |
| accent | `#3B5BFF` | `#6B84FF` | primary buttons, reticle, links |
| onAccent | `#FFFFFF` | `#0B1020` | text on accent |
| ok | `#0E9F6E` | `#34C38F` | ok verdict, completed hops |
| warn | `#C77700` | `#F0A93B` | caution verdict |
| danger | `#D92D3A` | `#F2616B` | danger verdict |

Verdict banner: background is the level colour at ~15% over surface, 1 px
border in the level colour, text in ink. Follow the system light/dark setting.
The scanner screen is always dark (camera) with white text.

## Shape

- Corner radius: 22 for cards, buttons and banners; pills/chips fully rounded.
- Borders 1 px `line`; no heavy shadows.
- Screen padding 16, card padding 14, gaps 12.

## Type

- UI: **Nunito Sans** (bundled, `design/fonts/NunitoSans-Variable.ttf`, OFL).
  Headings/wordmark/buttons 800 or 700, body 400, emphasised 600.
- URLs, hosts, small uppercase labels: system monospace.
- Card labels: 10-11 pt mono, uppercase, letter-spaced, `muted`.

## Logo

- `design/logo/mark.svg`: rounded blue square, white QR finder ring, white check.
- `design/logo/icon-full-bleed.svg` / `icon-1024.png`: app icon source (no rounding; the OS masks it).

## Screens

1. **Scan**: full-bleed camera, top bar with mark + "SecureQR", four accent
   corner brackets as reticle, hint pill "Point at a QR code. **Nothing opens**
   until you say so.", bottom row of round buttons: torch, pick image from
   gallery, history.
2. **Checking**: card "THE QR CODE SAYS" with the scanned URL (mono); card
   "FOLLOWING THE LINK FOR YOU" with progress; footer note "We open the link
   on our server, never on your phone."
3. **Decide**: verdict banner, screenshot of the final page (with its host in a
   small browser-chrome strip), card "YOU WOULD LAND ON" with the final host
   (registrable domain highlighted) and chips (HTTPS / Not encrypted, "N
   redirects"), expandable list of hops, then two buttons: "Open anyway"
   (ghost) and "Don't open" (primary). When the verdict is `ok`, the primary
   button becomes "Open" and the ghost one "Cancel".
4. **History**: on-device list of past scans (host, verdict dot, time); tap to
   re-check; clear-all.
5. **Non-link content**: typed card per `docs/qr-types.md` (bank transfer,
   payment, Wi-Fi, contact, …): title, label/value rows, notice banner,
   action buttons, collapsed raw content.
