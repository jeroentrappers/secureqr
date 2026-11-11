import { BlockList, isIP } from 'node:net';
import { lookup } from 'node:dns/promises';

/**
 * Decides which network targets the headless browser may reach. Everything
 * that is not a public unicast address is refused, so a scanned link (or any
 * redirect or sub-resource behind it) cannot be used to reach the server's own
 * network, cloud metadata endpoints or loopback services.
 */

const blocked = new BlockList();
for (const [net, prefix] of [
  ['0.0.0.0', 8], ['10.0.0.0', 8], ['100.64.0.0', 10], ['127.0.0.0', 8], ['169.254.0.0', 16],
  ['172.16.0.0', 12], ['192.0.0.0', 24], ['192.0.2.0', 24], ['192.88.99.0', 24], ['192.168.0.0', 16],
  ['198.18.0.0', 15], ['198.51.100.0', 24], ['203.0.113.0', 24], ['224.0.0.0', 4], ['240.0.0.0', 4],
] as const) blocked.addSubnet(net, prefix, 'ipv4');
for (const [net, prefix] of [
  ['::', 128], ['::1', 128], ['64:ff9b::', 96], ['64:ff9b:1::', 48], ['100::', 64], ['2001::', 23],
  ['2001:db8::', 32], ['2002::', 16], ['fc00::', 7], ['fe80::', 10], ['fec0::', 10], ['ff00::', 8],
] as const) blocked.addSubnet(net, prefix, 'ipv6');

/** Extract the IPv4 address from an IPv4-mapped/compatible IPv6 address, if it is one. */
function embeddedV4(ip: string): string | null {
  const m = /^::(?:ffff:)?(\d+\.\d+\.\d+\.\d+)$/i.exec(ip);
  if (m) return m[1]!;
  const h = /^::ffff:([0-9a-f]{1,4}):([0-9a-f]{1,4})$/i.exec(ip);
  if (h) {
    const a = parseInt(h[1]!, 16), b = parseInt(h[2]!, 16);
    return `${a >> 8}.${a & 255}.${b >> 8}.${b & 255}`;
  }
  return null;
}

export function isPublicAddress(ip: string): boolean {
  const family = isIP(ip);
  if (family === 4) return !blocked.check(ip, 'ipv4');
  if (family === 6) {
    const v4 = embeddedV4(ip);
    if (v4) return isIP(v4) === 4 && !blocked.check(v4, 'ipv4');
    return !blocked.check(ip, 'ipv6');
  }
  return false;
}

export interface GuardOptions {
  allowPrivate: boolean;
  allowedPorts: Set<number> | null;
}

export class GuardError extends Error {
  constructor(public readonly reason: 'blocked' | 'dns', message: string) {
    super(message);
  }
}

export interface Target {
  address: string;
  family: 4 | 6;
}

/**
 * Resolve `host` and return the one address the caller must connect to.
 * The caller connects to the returned IP, never to the name again, so a DNS
 * answer that changes between check and use cannot slip a private address past.
 * A name is refused if any of its addresses is non-public.
 */
export async function resolveTarget(host: string, port: number, opts: GuardOptions): Promise<Target> {
  const name = host.replace(/^\[|\]$/g, '');
  if (!opts.allowPrivate && opts.allowedPorts && !opts.allowedPorts.has(port)) {
    throw new GuardError('blocked', `port ${port} is not allowed`);
  }
  let addrs: { address: string; family: number }[];
  const literal = isIP(name);
  if (literal) {
    addrs = [{ address: name, family: literal }];
  } else {
    try {
      addrs = await lookup(name, { all: true, verbatim: false });
    } catch {
      throw new GuardError('dns', `could not resolve ${name}`);
    }
    if (addrs.length === 0) throw new GuardError('dns', `could not resolve ${name}`);
  }
  if (!opts.allowPrivate && addrs.some((a) => !isPublicAddress(a.address))) {
    throw new GuardError('blocked', `${name} is not a public address`);
  }
  const pick = addrs.find((a) => a.family === 4) ?? addrs[0]!;
  return { address: pick.address, family: pick.family as 4 | 6 };
}
