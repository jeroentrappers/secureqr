import { test } from 'node:test';
import assert from 'node:assert/strict';
import { GuardError, isPublicAddress, resolveTarget } from '../src/netguard.ts';

test('private, loopback, link-local and special ranges are not public', () => {
  for (const ip of [
    '127.0.0.1', '10.1.2.3', '172.16.0.1', '172.31.255.255', '192.168.1.1', '169.254.169.254', '100.64.0.1',
    '0.0.0.0', '224.0.0.1', '255.255.255.255', '198.18.0.1',
    '::1', '::', 'fe80::1', 'fc00::1', 'fd12:3456::1', 'ff02::1', '::ffff:127.0.0.1', '::ffff:7f00:1',
    '::ffff:10.0.0.1', '64:ff9b::a00:1', '2002:7f00:1::', 'not-an-ip',
  ]) assert.equal(isPublicAddress(ip), false, ip);
});

test('ordinary internet addresses are public', () => {
  for (const ip of ['1.1.1.1', '8.8.8.8', '93.184.216.34', '172.32.0.1', '2606:4700:4700::1111', '::ffff:8.8.8.8']) {
    assert.equal(isPublicAddress(ip), true, ip);
  }
});

const strict = { allowPrivate: false, allowedPorts: new Set([80, 443]) };

test('resolveTarget refuses private literals, bracketed IPv6 and odd ports', async () => {
  await assert.rejects(resolveTarget('127.0.0.1', 80, strict), (e) => e instanceof GuardError && e.reason === 'blocked');
  await assert.rejects(resolveTarget('[::1]', 443, strict), (e) => e instanceof GuardError && e.reason === 'blocked');
  await assert.rejects(resolveTarget('localhost', 80, strict), (e) => e instanceof GuardError && e.reason === 'blocked');
  await assert.rejects(resolveTarget('1.1.1.1', 22, strict), (e) => e instanceof GuardError && e.reason === 'blocked');
  assert.deepEqual(await resolveTarget('1.1.1.1', 443, strict), { address: '1.1.1.1', family: 4 });
});

test('resolveTarget reports names that do not resolve', async () => {
  await assert.rejects(resolveTarget('does-not-exist.invalid', 443, strict), (e) => e instanceof GuardError && e.reason === 'dns');
});

test('allowPrivate lifts the address and port checks', async () => {
  assert.deepEqual(await resolveTarget('127.0.0.1', 12345, { allowPrivate: true, allowedPorts: new Set([80]) }), { address: '127.0.0.1', family: 4 });
});
