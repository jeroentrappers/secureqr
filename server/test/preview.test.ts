import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import type { AddressInfo } from 'node:net';
import type { FastifyInstance } from 'fastify';
import { loadConfig } from '../src/config.ts';
import { PreviewError, type Previewer, type PreviewResult } from '../src/preview.ts';
import { noReputation, type Reputation } from '../src/reputation.ts';
import { buildApp } from '../src/server.ts';

let site: http.Server;
let port: number;
let open: { app: FastifyInstance; previewer: Previewer };
let strict: { app: FastifyInstance; previewer: Previewer };
let visits = 0;
let flagged: Reputation = { checked: [], flaggedBy: [], flaggedHost: null };

const page = (title: string, body: string) => `<!doctype html><html><head><title>${title}</title></head><body>${body}</body></html>`;

before(async () => {
  site = http.createServer((req, res) => {
    const html = (s: string) => res.writeHead(200, { 'content-type': 'text/html' }).end(s);
    switch (req.url) {
      case '/start': return void res.writeHead(301, { location: '/two' }).end();
      case '/two': return void res.writeHead(302, { location: '/js' }).end();
      case '/js': return html(page('hop', `<script>location.replace('http://127.0.0.1:${port}/final')</script>`));
      case '/final': return html(page('Sign in', '<h1>Sign in</h1><input type="password" name="pw">'));
      case '/counted': visits++; return html(page('Counted', '<h1>Hi</h1>'));
      case '/plain': return html(page('Plain', '<h1>Hello</h1>'));
      case '/pay': return html(page('Pay', '<input autocomplete="cc-number">'));
      case '/app': return void res.writeHead(302, { location: 'itsme://auth?session=abc' }).end();
      case '/file': return void res.writeHead(200, { 'content-type': 'application/octet-stream', 'content-disposition': 'attachment; filename="x.bin"' }).end('data');
      default: return void res.writeHead(404).end('nope');
    }
  });
  await new Promise<void>((r) => site.listen(0, '127.0.0.1', r));
  port = (site.address() as AddressInfo).port;

  const env = { RATE_LIMIT_PER_MIN: '1000', CHROMIUM_SANDBOX: process.env.CHROMIUM_SANDBOX ?? '1' };
  open = await buildApp(loadConfig({ ...env, ALLOW_PRIVATE: '1' }), { logger: false, reputation: async () => flagged });
  strict = await buildApp(loadConfig({ ...env, ALLOWED_PORTS: '*' }), { logger: false, reputation: noReputation });
});

after(async () => {
  await open.app.close();
  await strict.app.close();
  site.close();
  site.closeAllConnections();
});

const post = (app: FastifyInstance, url: unknown) => app.inject({ method: 'POST', url: '/v1/preview', payload: { url } });

test('follows http and script redirects, screenshots the final page, judges it', async () => {
  const res = await post(open.app, `http://localhost:${port}/start`);
  assert.equal(res.statusCode, 200, res.body);
  const r = res.json() as PreviewResult;
  assert.deepEqual(
    r.hops.map((h) => [new URL(h.url).pathname, h.status, h.kind, h.host]),
    [['/start', 301, 'start', 'localhost'], ['/two', 302, 'http', 'localhost'], ['/js', 200, 'http', 'localhost'], ['/final', 200, 'client', '127.0.0.1']],
  );
  assert.equal(r.finalUrl, `http://127.0.0.1:${port}/final`);
  assert.equal(r.finalHost, '127.0.0.1');
  assert.equal(r.finalDomain, '127.0.0.1');
  assert.equal(r.title, 'Sign in');
  assert.equal(r.https, false);
  assert.equal(r.verdict.level, 'danger');
  assert.deepEqual(r.verdict.reasons.map((x) => x.code), ['not_https', 'ip_address', 'domain_changed', 'asks_for_password', 'many_redirects']);

  assert.match(r.screenshotUrl ?? '', /^\/v1\/screenshots\/[0-9a-f]{16}\.jpg$/);
  const img = await open.app.inject({ method: 'GET', url: r.screenshotUrl! });
  assert.equal(img.statusCode, 200);
  assert.equal(img.headers['content-type'], 'image/jpeg');
  assert.deepEqual([...img.rawPayload.subarray(0, 2)], [0xff, 0xd8]);
  assert.ok(img.rawPayload.length > 2000);
});

test('detects card fields and reports blocklist hits first', async () => {
  flagged = { checked: ['Quad9', 'Cloudflare'], flaggedBy: ['Quad9'], flaggedHost: '127.0.0.1' };
  try {
    const r = (await post(open.app, `http://127.0.0.1:${port}/pay`)).json() as PreviewResult;
    assert.deepEqual(r.verdict.reasons.map((x) => x.code), ['known_malicious', 'not_https', 'ip_address', 'asks_for_payment']);
    assert.deepEqual(r.reputation, flagged);
  } finally {
    flagged = { checked: [], flaggedBy: [], flaggedHost: null };
  }
});

test('a link that only downloads a file is reported without a screenshot', async () => {
  const res = await post(open.app, `http://127.0.0.1:${port}/file`);
  assert.equal(res.statusCode, 200, res.body);
  const r = res.json() as PreviewResult;
  assert.equal(r.screenshotUrl, null);
  assert.equal(r.verdict.reasons[0]!.code, 'download');
});

test('a chain that hands over to an app is reported, not treated as a dead link', async () => {
  const res = await post(open.app, `http://127.0.0.1:${port}/app`);
  assert.equal(res.statusCode, 200, res.body);
  const r = res.json() as PreviewResult;
  assert.deepEqual(r.appLink, { scheme: 'itsme' });
  assert.equal(r.finalUrl, `http://127.0.0.1:${port}/app`);
  assert.ok(r.verdict.reasons.some((x) => x.code === 'opens_app'));
});

test('a repeated link is answered from the recent result without a second visit', async () => {
  const u = `http://127.0.0.1:${port}/counted`;
  const first = (await post(open.app, u)).json() as PreviewResult;
  const [a, b] = await Promise.all([post(open.app, u), post(open.app, u)]);
  assert.equal(first.cached, false);
  for (const res of [a, b]) {
    const r = res.json() as PreviewResult;
    assert.equal(r.cached, true);
    assert.equal(r.id, first.id);
    assert.equal(r.checkedAt, first.checkedAt);
  }
  assert.equal(visits, 1);
  assert.equal((await open.app.inject({ method: 'GET', url: first.screenshotUrl! })).statusCode, 200);
});

test('rejects things that are not web links', async () => {
  for (const bad of ['ftp://example.com/x', 'javascript:alert(1)', 'not a url', '', 42, undefined, `https://example.com/${'a'.repeat(2100)}`]) {
    const res = await post(open.app, bad);
    assert.equal(res.statusCode, 400, String(bad));
    assert.equal(res.json().error.code, 'invalid_url');
  }
});

test('reports an unreachable site', async () => {
  const res = await post(open.app, 'http://127.0.0.1:1/');
  assert.equal(res.statusCode, 422, res.body);
  assert.equal(res.json().error.code, 'unreachable');
});

test('refuses private targets up front', async () => {
  for (const u of [`http://127.0.0.1:${port}/plain`, `http://localhost:${port}/plain`, 'http://169.254.169.254/latest/meta-data/', 'http://[::1]/', 'http://10.0.0.1/']) {
    const res = await post(strict.app, u);
    assert.equal(res.statusCode, 400, u);
    assert.equal(res.json().error.code, 'blocked_target', u);
  }
});

test('the browser itself cannot reach loopback even if the up-front check is skipped', async () => {
  for (const u of [`http://127.0.0.1:${port}/plain`, `http://localhost:${port}/plain`]) {
    await assert.rejects(
      strict.previewer.preview(u, { skipPrecheck: true }),
      (e) => e instanceof PreviewError && e.code === 'blocked_target',
      u,
    );
  }
});

test('expired or unknown screenshots are 404', async () => {
  assert.equal((await open.app.inject({ method: 'GET', url: '/v1/screenshots/0000000000000000.jpg' })).statusCode, 404);
  assert.equal((await open.app.inject({ method: 'GET', url: '/v1/screenshots/..%2f..%2fetc.jpg' })).statusCode, 404);
});

test('health check', async () => {
  assert.deepEqual((await open.app.inject({ method: 'GET', url: '/healthz' })).json(), { ok: true });
});
