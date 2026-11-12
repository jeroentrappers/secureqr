import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readdir, readFile, rm, utimes, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ResultCache } from '../src/cache.ts';

const HOUR = 3600_000;
const MB = 1024 * 1024;
const link = 'https://shop.example/order/s3cret-token?x=1';

const inTempDir = async (fn: (dir: string) => Promise<void>) => {
  const dir = await mkdtemp(join(tmpdir(), 'secureqr-cache-'));
  try {
    await fn(dir);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
};

test('an entry comes back with its picture, also after a restart', () =>
  inTempDir(async (dir) => {
    const a = await ResultCache.open<{ title: string }>(dir, HOUR, MB);
    await a.put(link, { title: 'Order' }, Buffer.from('picture'));
    await a.put('https://other.example/', { title: 'No picture' }, null);

    const b = await ResultCache.open<{ title: string }>(dir, HOUR, MB);
    const hit = await b.get(link);
    assert.deepEqual(hit?.value, { title: 'Order' });
    assert.equal(hit?.blob?.toString(), 'picture');
    assert.equal((await b.get('https://other.example/'))?.blob, null);
    assert.equal(await b.get('https://shop.example/order/another'), null);
  }));

test('the files do not show the link or the answer', () =>
  inTempDir(async (dir) => {
    const cache = await ResultCache.open<{ title: string }>(dir, HOUR, MB);
    await cache.put(link, { title: 'Order for Jan' }, Buffer.from('picture'));
    const files = await readdir(dir);
    assert.equal(files.length, 1);
    assert.match(files[0]!, /^[0-9a-f]{64}\.bin$/);
    const raw = (await readFile(join(dir, files[0]!))).toString('latin1');
    for (const secret of ['shop.example', 's3cret', 'Order', 'picture']) assert.ok(!raw.includes(secret), secret);
  }));

test('entries expire, and a damaged file counts as absent', () =>
  inTempDir(async (dir) => {
    const cache = await ResultCache.open<number>(dir, HOUR, MB);
    await cache.put('https://old.example/', 1, null);
    const [oldFile] = await readdir(dir);
    await cache.put('https://bad.example/', 2, null);
    const badFile = (await readdir(dir)).find((f) => f !== oldFile);
    const longAgo = new Date(Date.now() - 2 * HOUR);
    await utimes(join(dir, oldFile!), longAgo, longAgo);
    await writeFile(join(dir, badFile!), 'not what was written');
    await writeFile(join(dir, 'half-written.tmp'), 'x');

    const reopened = await ResultCache.open<number>(dir, HOUR, MB);
    assert.equal(await reopened.get('https://old.example/'), null);
    assert.equal(await reopened.get('https://bad.example/'), null);
    assert.deepEqual(await readdir(dir), []);
  }));

test('the oldest entries make room when the cache is full', async () => {
  for (const dir of [null, await mkdtemp(join(tmpdir(), 'secureqr-cache-'))]) {
    const cache = await ResultCache.open<number>(dir, HOUR, 2500);
    for (let i = 0; i < 5; i++) await cache.put(`https://site${i}.example/`, i, Buffer.alloc(900));
    assert.equal(await cache.get('https://site0.example/'), null);
    assert.equal(await cache.get('https://site2.example/'), null);
    assert.equal((await cache.get('https://site3.example/'))?.value, 3);
    assert.equal((await cache.get('https://site4.example/'))?.value, 4);
    if (dir) {
      assert.equal((await readdir(dir)).length, 2);
      await rm(dir, { recursive: true, force: true });
    }
  }
});

test('a directory that cannot be used falls back to memory', async () => {
  await inTempDir(async (dir) => {
    await writeFile(join(dir, 'a-file'), '');
    const notes: string[] = [];
    const cache = await ResultCache.open<number>(join(dir, 'a-file', 'cache'), HOUR, MB, (m) => notes.push(m));
    await cache.put(link, 7, null);
    assert.equal((await cache.get(link))?.value, 7);
    assert.match(notes.join(), /cannot be used/);
  });
});
