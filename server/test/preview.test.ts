import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdtemp, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
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

test('a kept answer is judged again when a blocklist lists the site later', async () => {
  const u = `http://localhost:${port}/plain#listed-later`;
  const first = (await post(open.app, u)).json() as PreviewResult;
  assert.ok(!first.verdict.reasons.some((x) => x.code === 'known_malicious'));
  flagged = { checked: ['Quad9'], flaggedBy: ['Quad9'], flaggedHost: 'localhost' };
  try {
    const again = (await post(open.app, u)).json() as PreviewResult;
    assert.equal(again.cached, true);
    assert.equal(again.verdict.level, 'danger');
    assert.equal(again.verdict.reasons[0]!.code, 'known_malicious');
    assert.deepEqual(again.reputation, flagged);
  } finally {
    flagged = { checked: [], flaggedBy: [], flaggedHost: null };
  }
});

test('answers kept on disk are reused after a restart, picture included', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'secureqr-results-'));
  const env = { RATE_LIMIT_PER_MIN: '1000', CHROMIUM_SANDBOX: process.env.CHROMIUM_SANDBOX ?? '1', ALLOW_PRIVATE: '1', CACHE_DIR: dir };
  const u = `http://127.0.0.1:${port}/counted#disk`;
  const before = visits;
  try {
    const one = await buildApp(loadConfig(env), { logger: false, reputation: noReputation });
    const first = (await post(one.app, u)).json() as PreviewResult;
    await one.app.close();
    assert.equal(first.cached, false);
    assert.equal((await readdir(dir)).length, 1);

    const two = await buildApp(loadConfig(env), { logger: false, reputation: noReputation });
    try {
      const again = (await post(two.app, u)).json() as PreviewResult;
      assert.equal(again.cached, true);
      assert.equal(again.checkedAt, first.checkedAt);
      assert.deepEqual(again.verdict, first.verdict);
      const img = await two.app.inject({ method: 'GET', url: again.screenshotUrl! });
      assert.equal(img.statusCode, 200);
      assert.deepEqual([...img.rawPayload.subarray(0, 2)], [0xff, 0xd8]);
    } finally {
      await two.app.close();
    }
    assert.equal(visits, before + 1);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('spare tabs are opened ahead of a check and replaced as they are used', async () => {
  const env = { RATE_LIMIT_PER_MIN: '1000', CHROMIUM_SANDBOX: process.env.CHROMIUM_SANDBOX ?? '1', ALLOW_PRIVATE: '1', WARM_PAGES: '2' };
  const warm = await buildApp(loadConfig(env), { logger: false, reputation: noReputation });
  const spare = () => (warm.previewer as unknown as { spare: Promise<{ page: { isClosed(): boolean } }>[] }).spare;
  try {
    warm.previewer.warm();
    assert.equal(spare().length, 2);
    const ready = await Promise.all(spare());
    const results = await Promise.all(['a', 'b', 'c'].map((x) => post(warm.app, `http://localhost:${port}/plain#warm-${x}`)));
    for (const res of results) assert.equal(res.statusCode, 200, res.body);
    // the two that waited were used and thrown away, and two new ones wait
    assert.ok(ready.every((s) => s.page.isClosed()));
    assert.equal(spare().length, 2);
    assert.ok((await Promise.all(spare())).every((s) => !s.page.isClosed()));
  } finally {
    await warm.app.close();
  }
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

const stream = async (app: FastifyInstance, url: unknown) => {
  const res = await app.inject({ method: 'POST', url: '/v1/preview/stream', payload: { url } });
  const lines = res.statusCode === 200 ? res.body.trim().split('\n').map((l) => JSON.parse(l)) : [];
  return { res, lines };
};

test('the stream reports each step and hop, then the result', async () => {
  const { res, lines } = await stream(open.app, `http://localhost:${port}/start#stream`);
  assert.equal(res.statusCode, 200, res.body);
  assert.match(String(res.headers['content-type']), /^application\/x-ndjson/);
  assert.equal(res.headers['x-accel-buffering'], 'no');

  const last = lines.at(-1);
  assert.equal(last.type, 'result');
  assert.equal(new URL(last.result.finalUrl).pathname, '/final', res.body);
  assert.ok(last.result.screenshotUrl);

  const hops = lines.filter((l) => l.type === 'hop').map((l) => new URL(l.hop.url).pathname);
  assert.deepEqual(hops, ['/start', '/two', '/js', '/final']);

  const steps = lines.filter((l) => l.type === 'step');
  for (const id of ['blocklists', 'redirects', 'page', 'forms', 'picture']) {
    const states = steps.filter((s) => s.id === id).map((s) => s.state);
    assert.deepEqual(states, ['active', 'done'], id);
  }
  const done = (id: string) => steps.find((s) => s.id === id && s.state === 'done').label;
  assert.equal(done('redirects'), '3 redirects');
  assert.equal(done('forms'), 'Asks for a password');
  assert.equal(done('blocklists'), 'Blocklists could not be reached');
  // nothing is reported after the result
  assert.equal(lines.filter((l) => l.type === 'result').length, 1);
});

test('the stream answers a repeated link with the result only', async () => {
  await stream(open.app, `http://localhost:${port}/plain#stream`);
  const { lines } = await stream(open.app, `http://localhost:${port}/plain#stream`);
  assert.deepEqual(lines.map((l) => l.type), ['result']);
  assert.equal(lines[0].result.cached, true);
});

test('the stream refuses bad links with a plain error and reports later failures as a line', async () => {
  const bad = await stream(open.app, 'ftp://example.com/x');
  assert.equal(bad.res.statusCode, 400);
  assert.equal(bad.res.json().error.code, 'invalid_url');

  const priv = await stream(strict.app, `http://127.0.0.1:${port}/plain`);
  assert.equal(priv.res.statusCode, 200);
  const last = priv.lines.at(-1);
  assert.equal(last.type, 'error');
  assert.equal(last.status, 400);
  assert.equal(last.error.code, 'blocked_target');
});

test('with app keys configured, the preview endpoints refuse callers without one', async () => {
  const env = { RATE_LIMIT_PER_MIN: '1000', CHROMIUM_SANDBOX: process.env.CHROMIUM_SANDBOX ?? '1', ALLOW_PRIVATE: '1', API_KEYS: 'first-key, second-key' };
  const keyed = await buildApp(loadConfig(env), { logger: false, reputation: noReputation });
  try {
    const call = (path: string, key?: string) =>
      keyed.app.inject({ method: 'POST', url: path, payload: { url: `http://localhost:${port}/plain#keyed` }, headers: key === undefined ? {} : { 'x-secureqr-key': key } });

    for (const path of ['/v1/preview', '/v1/preview/stream']) {
      for (const bad of [undefined, '', 'wrong', 'first-key2', 'first-key, second-key']) {
        const res = await call(path, bad);
        assert.equal(res.statusCode, 401, `${path} ${bad}`);
        assert.equal(res.json().error.code, 'unauthorized');
      }
    }
    assert.equal((await call('/v1/preview', 'first-key')).statusCode, 200);
    const s = await call('/v1/preview/stream', 'second-key');
    assert.equal(s.statusCode, 200);
    assert.equal(JSON.parse(s.body.trim().split('\n').at(-1)!).type, 'result');
    // no key needed for these
    assert.equal((await keyed.app.inject({ method: 'GET', url: '/healthz' })).statusCode, 200);
    assert.equal((await keyed.app.inject({ method: 'GET', url: '/v1/screenshots/0000000000000000.jpg' })).statusCode, 404);
  } finally {
    await keyed.app.close();
  }
});
