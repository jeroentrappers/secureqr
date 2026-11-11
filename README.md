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
ansible-playbook site.yml --check   # dry run
ansible-playbook site.yml
```

Copies `server/` to `/opt/secureqr` on appmire-hetz1, builds the image there,
runs one container on loopback, and puts nginx with a certbot certificate in
front at `qr.appmire.be`. The play ends with a real preview and a check that
private addresses are refused, so a browser that cannot start fails the deploy.

## License

MIT, see [LICENSE](LICENSE). Two bundled files keep their own licenses: the
Nunito Sans font (SIL Open Font License, `design/fonts/OFL.txt`) and
`server/seccomp_profile.json` (from Playwright, Apache-2.0).
