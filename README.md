# SecureQR

*See where it goes before you go.*

A QR scanner that never opens a link directly. Web links are followed by a
server in a sandboxed browser; the app shows the redirect chain, a screenshot
of the final page, blocklist results and a verdict, and only then lets the
user decide. Payment codes, Wi-Fi, contacts and other QR types are parsed on
the phone and shown as a card before anything happens.

| path | what |
|---|---|
| [`server/`](server/) | Preview API: Node, TypeScript, Fastify, Playwright |
| [`android/`](android/) | Android app: Kotlin, Compose, CameraX, ML Kit |
| [`ios/`](ios/) | iOS app: SwiftUI, AVFoundation, Vision |
| [`docs/api.md`](docs/api.md) | API contract shared by both apps |
| [`docs/qr-types.md`](docs/qr-types.md) | QR payload types, parsing rules, test vectors |
| [`design/`](design/) | Brand: tokens, logo, font, mock-ups |
| [`deploy/ansible/`](deploy/ansible/) | Server deploy to appmire-hetz1 (`https://qr.appmire.be`) |

## Deploy the server

```sh
cd deploy/ansible
cp secrets.example.yml secrets.yml   # once; put the app key in it (not in git)
ansible-playbook site.yml
```

Copies `server/` to `/opt/secureqr` on appmire-hetz1, builds the image there,
runs one container on loopback, and puts nginx with a certbot certificate in
front at `qr.appmire.be`. The play ends with self-tests, so a deploy that
leaves the service broken or exposed fails: a real preview comes back with a
picture, private addresses are refused, a caller without the app key is
refused, and from inside the container the internet answers while the host and
private networks do not.

What keeps it safe once it runs (all installed by the role):

- **App key.** The preview endpoints need the `X-SecureQR-Key` header. The
  accepted keys are in `deploy/ansible/secrets.yml`; the apps are built with
  the first one (`android/local.properties`, `ios/Config/Secrets.xcconfig`).
  To rotate: add a new key at the top, release the apps, then drop the old one.
- **Network wall.** The container sits on its own bridge (`br-secureqr`) and
  `secureqr-firewall.sh` rejects everything from it that is not the public
  internet: the host, other containers, the VPN, private ranges. It runs at
  boot and is re-applied every five minutes.
- **Browser updates.** `secureqr-update.timer` looks nightly for a newer
  Playwright (which brings a newer Chromium), rebuilds, restarts and runs a
  real preview; a release must be three days old, and a failed update goes
  back to the previous version. The version in `server/Dockerfile` is only a
  floor; the box may be ahead (`/opt/secureqr/.env`).
- **Alerts.** `secureqr-watch.timer` checks every five minutes and sends a
  notification through the host's `appmire-alert.sh` (ntfy) on a traffic
  spike, many requests without a valid key, many rate-limited requests,
  server errors, or a container that is not healthy. Thresholds are in
  `deploy/ansible/group_vars/all.yml`. Browser updates report the same way.

## License

MIT, see [LICENSE](LICENSE). Two bundled files keep their own licenses: the
Nunito Sans font (SIL Open Font License, `design/fonts/OFL.txt`) and
`server/seccomp_profile.json` (from Playwright, Apache-2.0).
