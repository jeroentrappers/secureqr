import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildReputation } from '../src/reputation.ts';

test('combines providers, keeps chain order, skips IPs and caches per host', async () => {
  let calls = 0;
  const rep = buildReputation([
    { name: 'A', check: async (h) => (calls++, h === 'bad.example') },
    { name: 'B', check: async () => null },
    { name: 'C', check: async (h) => h === 'bad.example' || h === 'worse.example' },
  ]);
  const r = await rep(['ok.example', 'worse.example', 'BAD.example', '192.0.2.1', 'ok.example']);
  assert.deepEqual(r, { checked: ['A', 'C'], flaggedBy: ['A', 'C'], flaggedHost: 'worse.example' });
  assert.equal(calls, 3);
  await rep(['ok.example', 'bad.example']);
  assert.equal(calls, 3);
  assert.deepEqual(await rep(['ok.example']), { checked: ['A', 'C'], flaggedBy: [], flaggedHost: null });
});
