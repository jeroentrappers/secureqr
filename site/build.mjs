// Builds the landing page in every language into site/public/.
//
//   node site/build.mjs            build
//   node site/build.mjs --check    only validate the translations (exit 1 on a problem)
//
// site/src/index.html is the template, site/src/i18n/<code>.json holds the text
// per language (en.json is the source; a key missing from another language falls
// back to English and is reported). site/static/ is copied as is: assets and the
// privacy, terms and support pages, which exist in English only.
// English is served at /, every other language at /<code>/.
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ORIGIN = 'https://qr.appmire.be';
const PLAY_URL = 'https://play.google.com/store/apps/details?id=be.appmire.secureqr';
// Set once the app is live on the App Store; until then the button says "coming soon".
const APP_STORE_URL = null;

// The order of the language menu: English first, then by number of speakers, Dutch last.
const ORDER = ['en', 'zh', 'hi', 'es', 'ar', 'fr', 'bn', 'pt', 'ru', 'id', 'ur', 'de', 'ja', 'mr', 'vi', 'te', 'tr', 'ta', 'ko', 'it', 'nl'];

const root = dirname(fileURLToPath(import.meta.url));
const src = join(root, 'src');
const out = join(root, 'public');

const read = (code) => JSON.parse(readFileSync(join(src, 'i18n', `${code}.json`), 'utf8'));
const en = read('en');
const codes = ORDER.filter((c) => existsSync(join(src, 'i18n', `${c}.json`)));
const extra = readdirSync(join(src, 'i18n')).map((f) => f.replace(/\.json$/, '')).filter((c) => !ORDER.includes(c));
if (extra.length) throw new Error(`Languages not in ORDER: ${extra.join(', ')}`);

const template = readFileSync(join(src, 'index.html'), 'utf8');
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const path = (code) => (code === 'en' ? '/' : `/${code}/`);
const tags = (s) => (String(s).match(/<\/?[a-z]+/g) || []).sort().join(' ');

const langs = Object.fromEntries(codes.map((c) => [c, read(c)]));
let problems = 0;
const warn = (msg) => { problems++; console.warn(`  ! ${msg}`); };

function merged(code) {
  const t = langs[code];
  const out = { ...en, ...t, demo: { ...en.demo, ...(t.demo || {}) } };
  if (code === 'en') return out;
  for (const k of Object.keys(en)) if (k !== 'demo' && !(k in t)) warn(`${code}: missing ${k}`);
  for (const k of Object.keys(en.demo)) if (!(t.demo && k in t.demo)) warn(`${code}: missing demo.${k}`);
  for (const k of Object.keys(t)) if (!(k in en)) warn(`${code}: unknown key ${k}`);
  for (const [k, v] of Object.entries(t)) {
    if (typeof v !== 'string' || !(k in en)) continue;
    if (k.endsWith('_html')) { if (tags(v) !== tags(en[k])) warn(`${code}: ${k} has different markup than English`); }
    else if (/[<>]/.test(v)) warn(`${code}: ${k} contains markup`);
  }
  return out;
}

const alternates = [
  ...codes.map((c) => `<link rel="alternate" hreflang="${langs[c]._lang.hreflang}" href="${ORIGIN}${path(c)}">`),
  `<link rel="alternate" hreflang="x-default" href="${ORIGIN}/">`,
].join('\n');

const check = process.argv.includes('--check');
if (!check) {
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });
  cpSync(join(root, 'static'), out, { recursive: true });
}

for (const code of codes) {
  const t = merged(code);
  const menu = codes.map((c) => {
    const l = langs[c]._lang;
    const cur = c === code ? ' aria-current="page"' : '';
    return `<li><a href="${path(c)}" hreflang="${l.hreflang}" lang="${l.hreflang}" data-lang="${c}"${cur}>${esc(l.name)}</a></li>`;
  }).join('');
  const appStore = APP_STORE_URL
    ? `<a class="store" href="${APP_STORE_URL}"><small>${esc(t.store_appstore_small)}</small>App Store</a>`
    : `<span class="store off" aria-disabled="true"><small>${esc(t.store_soon_small)}</small>App Store</span>`;
  const specials = {
    url: ORIGIN + path(code),
    home: path(code),
    alternates,
    languages: menu,
    playUrl: PLAY_URL,
    appStore,
    englishNote: t.footer_english_note ? `<br><small>${esc(t.footer_english_note)}</small>` : '',
    demoJson: JSON.stringify(t.demo).replace(/</g, '\\u003c'),
  };
  const html = template.replace(/\{\{(@?)([\w.]+)\}\}/g, (m, at, key) => {
    if (at) {
      if (!(key in specials)) throw new Error(`Unknown special {{@${key}}}`);
      return specials[key];
    }
    const v = key.split('.').reduce((o, k) => (o == null ? o : o[k]), t);
    if (typeof v !== 'string') throw new Error(`Template key {{${key}}} has no text`);
    return key.endsWith('_html') ? v : esc(v);
  });
  if (check) continue;
  const dir = code === 'en' ? out : join(out, code);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'index.html'), html);
}

console.log(`${check ? 'Checked' : 'Built'} ${codes.length} languages into ${out}${problems ? `, ${problems} problem(s)` : ''}: ${codes.join(' ')}`);
if (problems && (check || process.argv.includes('--strict'))) process.exit(1);
