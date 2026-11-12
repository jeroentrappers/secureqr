// The words the server sends to the app (warnings, progress steps, errors), in the
// language the phone asks for with Accept-Language. English is the source and the
// fallback: a missing language or key falls back to English.
//
// The check itself works in English (that is what is cached and logged); texts are
// put into the asker's language only when the answer is sent, from a key and its
// values. A cached answer can so be reused for someone with another language.
import ar from './messages/ar.js';
import bn from './messages/bn.js';
import de from './messages/de.js';
import en from './messages/en.js';
import es from './messages/es.js';
import fr from './messages/fr.js';
import hi from './messages/hi.js';
import id from './messages/id.js';
import it from './messages/it.js';
import ja from './messages/ja.js';
import ko from './messages/ko.js';
import mr from './messages/mr.js';
import nl from './messages/nl.js';
import pt from './messages/pt.js';
import ru from './messages/ru.js';
import ta from './messages/ta.js';
import te from './messages/te.js';
import tr from './messages/tr.js';
import ur from './messages/ur.js';
import vi from './messages/vi.js';
import zh from './messages/zh.js';
import type { Catalog } from './messages/types.js';

export type { Catalog, MessageKey } from './messages/types.js';
export type Params = Record<string, string | number | string[]>;

const CATALOGS: Record<string, Catalog> = { ar, bn, de, en, es, fr, hi, id, it, ja, ko, mr, nl, pt, ru, ta, te, tr, ur, vi, zh };
export const LANGUAGES = Object.keys(CATALOGS);

/** Older and regional codes that mean one of our languages. */
const ALIASES: Record<string, string> = { in: 'id' };

/** The best language for an Accept-Language header, English when none of ours is asked for. */
export function pickLanguage(header: string | string[] | undefined): string {
  const raw = Array.isArray(header) ? header.join(',') : (header ?? '');
  const wanted = raw
    .split(',')
    .map((part, i) => {
      const [tag = '', ...rest] = part.trim().split(';');
      const q = rest.map((r) => /^\s*q=([\d.]+)\s*$/.exec(r)?.[1]).find(Boolean);
      return { tag: tag.trim().toLowerCase(), q: q === undefined ? 1 : Number(q), i };
    })
    .filter((w) => w.tag && w.tag !== '*' && w.q > 0)
    .sort((a, b) => b.q - a.q || a.i - b.i);
  for (const w of wanted) {
    const base = w.tag.split(/[-_]/)[0] ?? '';
    const code = ALIASES[base] ?? base;
    if (code in CATALOGS) return code;
  }
  return 'en';
}

export interface Translator {
  lang: string;
  t(key: string, params?: Params): string;
}

function render(lang: string, key: string, params: Params = {}): string | null {
  const pick = (cat: Catalog | undefined): string | null => {
    const v = cat?.[key as keyof Catalog];
    if (v == null) return null;
    if (typeof v === 'string') return v;
    const n = typeof params.count === 'number' ? params.count : NaN;
    const form = n === 0 && v.zero ? 'zero' : (new Intl.PluralRules(lang).select(n) as keyof typeof v);
    return v[form] ?? v.other ?? null;
  };
  const text = pick(CATALOGS[lang]) ?? pick(CATALOGS.en);
  if (text == null) return null;
  return text.replace(/\{(\w+)\}/g, (m, name: string) => {
    const p = params[name];
    if (p == null) return m;
    if (Array.isArray(p)) return new Intl.ListFormat(lang, { type: 'conjunction' }).format(p);
    return typeof p === 'number' ? new Intl.NumberFormat(lang).format(p) : p;
  });
}

export function translator(lang: string): Translator {
  const l = lang in CATALOGS ? lang : 'en';
  return { lang: l, t: (key, params) => render(l, key, params) ?? key };
}

/** English text for a key, as used inside the check. */
export const english = (key: string, params?: Params): string => render('en', key, params) ?? key;

// Errors are thrown with their English text; find the key back to translate it.
const errorKeys = new Map<string, string>();
for (const [k, v] of Object.entries(en)) if (k.startsWith('error.') && typeof v === 'string') errorKeys.set(v, k);

/** An error text in the asker's language; unknown texts are passed on as they are. */
export function translateError(tr: Translator, message: string): string {
  const key = errorKeys.get(message);
  return key ? tr.t(key) : message;
}
