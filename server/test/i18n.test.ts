import assert from 'node:assert/strict';
import { test } from 'node:test';
import { english, LANGUAGES, pickLanguage, translateError, translator } from '../src/i18n.js';
import en from '../src/messages/en.js';
import { judge } from '../src/verdict.js';

test('picks the best supported language from Accept-Language', () => {
  assert.equal(pickLanguage(undefined), 'en');
  assert.equal(pickLanguage(''), 'en');
  assert.equal(pickLanguage('nl-BE,nl;q=0.9,en;q=0.8'), 'nl');
  assert.equal(pickLanguage('pt-BR'), 'pt');
  assert.equal(pickLanguage('zh-Hans-CN'), 'zh');
  assert.equal(pickLanguage('in-ID'), 'id');
  assert.equal(pickLanguage('xx, de;q=0.5, fr;q=0.7'), 'fr');
  assert.equal(pickLanguage('sv-SE, *;q=0.1'), 'en');
  assert.equal(pickLanguage('de;q=0'), 'en');
});

test('every language has the languages the site and apps offer', () => {
  for (const c of ['en', 'zh', 'hi', 'es', 'ar', 'fr', 'bn', 'pt', 'ru', 'id', 'ur', 'de', 'ja', 'mr', 'vi', 'te', 'tr', 'ta', 'ko', 'it', 'nl']) {
    assert.ok(LANGUAGES.includes(c), c);
  }
});

test('fills in values and plural forms', () => {
  assert.equal(english('step.redirects', { count: 0 }), 'No redirects');
  assert.equal(english('step.redirects', { count: 1 }), '1 redirect');
  assert.equal(english('step.redirects', { count: 4 }), '4 redirects');
  assert.equal(english('reason.known_malicious', { providers: ['Quad9', 'Cloudflare', 'DNS4EU'] }), 'Listed as malicious by Quad9, Cloudflare, and DNS4EU');
  assert.equal(english('reason.opens_app', { scheme: 'tg' }), 'The link tries to open another app (tg)');
});

test('every language keeps the placeholders of the English text', () => {
  const names = (s: string) => (s.match(/\{\w+\}/g) ?? []).sort().join();
  for (const lang of LANGUAGES) {
    const t = translator(lang);
    for (const [key, v] of Object.entries(en)) {
      const forms = typeof v === 'string' ? { other: v } : v;
      const want = names(forms.other);
      for (const n of [0, 1, 2, 3, 5, 11, 21]) {
        const out = t.t(key, { count: n, providers: ['A', 'B'], scheme: 'tg' });
        assert.ok(!/\{\w+\}/.test(out), `${lang} ${key}: unfilled placeholder in "${out}"`);
        if (want.includes('{scheme}')) assert.ok(out.includes('tg'), `${lang} ${key}: scheme missing`);
        if (want.includes('{providers}')) assert.ok(out.includes('A') && out.includes('B'), `${lang} ${key}: providers missing`);
      }
    }
  }
});

test('verdict reasons keep their values, so they can be translated later', () => {
  const v = judge({
    requestedUrl: 'https://a.example/',
    finalUrl: 'https://b.example/',
    redirects: 3,
    hopUrls: [],
    download: false,
    asksPassword: false,
    asksPayment: false,
    appScheme: null,
  });
  const many = v.reasons.find((r) => r.code === 'many_redirects');
  assert.deepEqual(many?.params, { count: 3 });
  assert.equal(many?.message, 'Passed through 3 redirects');
});

test('errors thrown in English come out translated, unknown ones unchanged', () => {
  const t = translator('en');
  assert.equal(translateError(t, 'The site did not respond'), 'The site did not respond');
  assert.equal(translateError(t, 'something else'), 'something else');
  assert.equal(translator('xx').lang, 'en');
});
