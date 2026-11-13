// Builds the store graphics from the raw captures in design/screens:
//   node design/store/build.mjs        (needs server/node_modules: Playwright, and ImageMagick's `magick`)
// Output: ios/fastlane/screenshots/en-US (6.9" iPhone, 1320 x 2868) and
// android/fastlane/metadata/android/en-US/images (phone screenshots 1080 x 1920,
// feature graphic 1024 x 500, icon 512 x 512). The iOS pictures are copied to nl-NL as well: App Store
// Connect falls back only to the primary language, which is nl-NL, and that one must have its own.
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { cpSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const { chromium } = createRequire(join(root, 'server/package.json'))('playwright');

const font = pathToFileURL(join(root, 'design/fonts/NunitoSans-Variable.ttf')).href;
const mark = readFileSync(join(root, 'design/logo/mark.svg'), 'utf8');

// One headline per screen; the order is the order in the stores.
const SHOTS = [
  { head: 'See where it goes<br>before you go', sub: 'Scan a QR code. Nothing opens until you say so.', ios: 'scanner-light', android: '02-scan' },
  { head: 'We follow the link<br>for you', sub: 'Every check, step by step, on our server.', ios: 'checking-steps-light', android: '24-checking-steps-light' },
  { head: 'See the page<br>before you open it', sub: 'The real address and a picture of where you would land.', ios: 'link-ok-light', android: '04-decide-ok' },
  { head: 'Warned about<br>known bad sites', sub: 'Every stop is checked against threat blocklists.', ios: 'link-danger-light', android: '06-decide-danger' },
  { head: 'More than links', sub: 'Wi-Fi, payments and contacts are read on your phone, never sent to us.', ios: 'wifi-light', android: '11-card-wifi' },
  { head: 'Plain words for<br>every code', sub: 'Know what a code does before anything happens.', ios: 'otp-light', android: '12-card-otp' },
];

const TARGETS = {
  ios: { w: 1320, h: 2868, shotW: 1000, top: 610, head: 108, sub: 46, radius: 110, bezel: 16, pad: 90,
         src: (n) => join(root, 'design/screens/ios', `${n}.png`), out: join(root, 'ios/fastlane/screenshots/en-US') },
  android: { w: 1080, h: 1920, shotW: 640, top: 420, head: 78, sub: 34, radius: 56, bezel: 12, pad: 70,
             src: (n) => join(root, 'design/screens/android', `${n}.png`), out: join(root, 'android/fastlane/metadata/android/en-US/images/phoneScreenshots') },
};

const base = `
  @font-face { font-family: "Nunito Sans"; src: url("${font}"); font-weight: 200 1000; }
  * { box-sizing: border-box; margin: 0; }
  body { font-family: "Nunito Sans", sans-serif; color: #fff; overflow: hidden;
         background: radial-gradient(120% 70% at 50% 0%, #5D78FF 0%, #3B5BFF 45%, #2740D0 100%); }`;

function shotPage(t, s, platform) {
  return `<!doctype html><meta charset="utf-8"><style>${base}
    body { width: ${t.w}px; height: ${t.h}px; text-align: center; }
    h1 { font-size: ${t.head}px; line-height: 1.06; font-weight: 800; letter-spacing: -0.03em; padding: ${t.pad * 1.5}px ${t.pad}px 0; }
    p { font-size: ${t.sub}px; line-height: 1.3; font-weight: 600; opacity: .9; padding: ${t.sub * 0.6}px ${t.pad * 1.4}px 0; }
    .phone { position: absolute; left: 50%; top: ${t.top}px; transform: translateX(-50%); width: ${t.shotW + 2 * t.bezel}px;
             border: ${t.bezel}px solid #070A14; border-radius: ${t.radius}px; overflow: hidden; background: #070A14;
             box-shadow: 0 40px 90px rgba(5, 12, 50, .45); }
    .phone img { display: block; width: ${t.shotW}px; }
  </style><h1>${s.head}</h1><p>${s.sub}</p>
  <div class="phone"><img src="${pathToFileURL(t.src(s[platform])).href}"></div>`;
}

const feature = `<!doctype html><meta charset="utf-8"><style>${base}
  body { width: 1024px; height: 500px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 26px; }
  .brand { display: flex; align-items: center; gap: 26px; font-size: 112px; font-weight: 800; letter-spacing: -0.035em; }
  .brand svg { width: 132px; height: 132px; border-radius: 30px; box-shadow: 0 0 0 5px rgba(255,255,255,.9); }
  p { font-size: 38px; font-weight: 600; opacity: .92; }
</style><div class="brand">${mark}<span>SecureQR</span></div><p>See where it goes before you go.</p>`;

const browser = await chromium.launch();
async function render(html, w, h, out) {
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  // A file:// base so the local font and captures load.
  await page.goto(pathToFileURL(join(here, 'build.mjs')).href.replace(/build\.mjs$/, ''), { waitUntil: 'commit' }).catch(() => {});
  await page.setContent(html, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: out, type: 'png' });
  await page.close();
  // The stores refuse pictures with an alpha channel.
  execFileSync('magick', [out, '-alpha', 'off', '-strip', out]);
  console.log(out.replace(root + '/', ''));
}

for (const [platform, t] of Object.entries(TARGETS)) {
  rmSync(t.out, { recursive: true, force: true });
  mkdirSync(t.out, { recursive: true });
  for (const [i, s] of SHOTS.entries()) {
    await render(shotPage(t, s, platform), t.w, t.h, join(t.out, `${String(i + 1).padStart(2, '0')}-${s[platform]}.png`));
  }
}
const nl = join(root, 'ios/fastlane/screenshots/nl-NL');
rmSync(nl, { recursive: true, force: true });
cpSync(TARGETS.ios.out, nl, { recursive: true });
console.log('ios/fastlane/screenshots/nl-NL (same pictures)');

const images = join(root, 'android/fastlane/metadata/android/en-US/images');
await render(feature, 1024, 500, join(images, 'featureGraphic.png'));
await browser.close();

execFileSync('magick', [join(root, 'design/logo/icon-1024.png'), '-resize', '512x512', '-strip', join(images, 'icon.png')]);
console.log('android/fastlane/metadata/android/en-US/images/icon.png');
