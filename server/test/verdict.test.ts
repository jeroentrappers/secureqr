import { test } from 'node:test';
import assert from 'node:assert/strict';
import { judge, registrableDomain, type Evidence } from '../src/verdict.ts';

const base: Evidence = {
  requestedUrl: 'https://www.example.com/a',
  finalUrl: 'https://shop.example.com/b',
  redirects: 1,
  hopUrls: ['https://www.example.com/a', 'https://shop.example.com/b'],
  download: false,
  asksPassword: false,
  asksPayment: false,
};
const codes = (e: Partial<Evidence>) => judge({ ...base, ...e }).reasons.map((r) => r.code);

test('same registrable domain over https is ok', () => {
  assert.deepEqual(judge(base), { level: 'ok', reasons: [] });
});

test('caution signals', () => {
  assert.deepEqual(codes({ finalUrl: 'https://other.org/' }), ['domain_changed']);
  assert.deepEqual(codes({ redirects: 3 }), ['many_redirects']);
  assert.deepEqual(codes({ asksPassword: true, asksPayment: true }), ['asks_for_payment', 'asks_for_password']);
  assert.equal(judge({ ...base, redirects: 3 }).level, 'caution');
});

test('danger signals come first', () => {
  const v = judge({ ...base, finalUrl: 'http://192.0.2.7/x', download: true, flaggedBy: ['Quad9', 'Cloudflare'] });
  assert.equal(v.level, 'danger');
  assert.deepEqual(v.reasons.map((r) => r.code), ['known_malicious', 'download', 'not_https', 'ip_address', 'domain_changed']);
  assert.equal(v.reasons[0]!.message, 'Listed as malicious by Quad9 and Cloudflare');
});

test('three blocklists read naturally', () => {
  assert.equal(judge({ ...base, flaggedBy: ['Quad9', 'DNS4EU', 'Phishing.Database'] }).reasons[0]!.message, 'Listed as malicious by Quad9, DNS4EU, and Phishing.Database');
});

test('punycode and embedded credentials', () => {
  assert.deepEqual(codes({ requestedUrl: 'https://xn--pypal-4ve.com/', finalUrl: 'https://xn--pypal-4ve.com/' }), ['lookalike_domain']);
  assert.deepEqual(codes({ requestedUrl: 'https://paypal.com@example.com/a' }), ['embedded_credentials']);
});

test('registrable domain', () => {
  assert.equal(registrableDomain('a.b.example.co.uk'), 'example.co.uk');
  assert.equal(registrableDomain('192.0.2.1'), '192.0.2.1');
  assert.equal(registrableDomain('localhost'), 'localhost');
});
