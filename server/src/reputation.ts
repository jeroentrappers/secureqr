import { Resolver } from 'node:dns/promises';
import { isIP } from 'node:net';
import { getDomain } from 'tldts';

/**
 * Checks host names against public threat-blocking DNS resolvers. No API key
 * is needed: a blocking resolver refuses names on its threat list, and the
 * same provider's unfiltered resolver tells us whether the name really exists.
 *
 *  - Quad9: 9.9.9.9 answers NXDOMAIN for blocked names; 9.9.9.10 is unfiltered.
 *  - Cloudflare for Families (malware): 1.1.1.2 answers 0.0.0.0 for blocked names; 1.1.1.1 is unfiltered.
 *  - DNS4EU (protective): 86.54.11.1 answers with its block-page address for blocked names; 86.54.11.100 is unfiltered.
 *
 * Plus one downloaded list, Phishing.Database (MIT licence), matched on host name.
 */

export interface Reputation {
  /** Providers that answered for at least one host. */
  checked: string[];
  /** Providers that list at least one host in the chain. */
  flaggedBy: string[];
  /** The first listed host, or null. */
  flaggedHost: string | null;
}

export type ReputationCheck = (hosts: string[]) => Promise<Reputation>;

type Outcome = { kind: 'addrs'; addrs: string[] } | { kind: 'nxdomain' } | { kind: 'nodata' } | { kind: 'error' };

const mk = (servers: string[]) => {
  const r = new Resolver({ timeout: 1500, tries: 2 });
  r.setServers(servers);
  return r;
};

async function ask(r: Resolver, host: string): Promise<Outcome> {
  try {
    return { kind: 'addrs', addrs: await r.resolve4(host) };
  } catch (e) {
    const code = (e as NodeJS.ErrnoException).code;
    if (code === 'ENOTFOUND') return { kind: 'nxdomain' };
    if (code === 'ENODATA') return { kind: 'nodata' };
    return { kind: 'error' };
  }
}

interface Provider {
  name: string;
  /** true = listed, false = not listed, null = could not tell. */
  check(host: string): Promise<boolean | null>;
}

const DNS4EU_SINKHOLE = '51.15.69.11';

function dnsProviders(): Provider[] {
  const q9 = mk(['9.9.9.9', '149.112.112.112']);
  const q9open = mk(['9.9.9.10', '149.112.112.10']);
  const cf = mk(['1.1.1.2', '1.0.0.2']);
  const cfOpen = mk(['1.1.1.1', '1.0.0.1']);
  const eu = mk(['86.54.11.1', '86.54.11.201']);
  const euOpen = mk(['86.54.11.100', '86.54.11.200']);
  const sinkTo = (ip: string) => (x: Outcome) => x.kind === 'addrs' && x.addrs.includes(ip);
  return [
    {
      name: 'Quad9',
      async check(host) {
        const [f, o] = await Promise.all([ask(q9, host), ask(q9open, host)]);
        if (f.kind === 'error' || o.kind === 'error') return null;
        return f.kind === 'nxdomain' && o.kind !== 'nxdomain';
      },
    },
    {
      name: 'Cloudflare',
      async check(host) {
        const [f, o] = await Promise.all([ask(cf, host), ask(cfOpen, host)]);
        if (f.kind === 'error' || o.kind === 'error') return null;
        const sink = sinkTo('0.0.0.0');
        return sink(f) && !sink(o);
      },
    },
    {
      name: 'DNS4EU',
      async check(host) {
        const [f, o] = await Promise.all([ask(eu, host), ask(euOpen, host)]);
        if (f.kind === 'error' || o.kind === 'error') return null;
        const sink = sinkTo(DNS4EU_SINKHOLE);
        return sink(f) && !sink(o);
      },
    },
  ];
}

const PHISHDB_URL = 'https://raw.githubusercontent.com/Phishing-Database/Phishing.Database/master/phishing-domains-ACTIVE.txt';
const FEED_REFRESH_MS = 6 * 60 * 60 * 1000;

/** A downloaded list of phishing host names, refreshed in the background. */
export function domainListProvider(name: string, url: string, log: (msg: string) => void = () => {}): Provider & { stop(): void } {
  let hosts: Set<string> | null = null;
  let etag: string | null = null;
  const load = async () => {
    try {
      const res = await fetch(url, { headers: etag ? { 'if-none-match': etag } : {}, signal: AbortSignal.timeout(120_000) });
      if (res.status === 304) return;
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const next = new Set<string>();
      for (const line of (await res.text()).split('\n')) {
        const h = line.trim().toLowerCase();
        if (h && !h.startsWith('#') && !isIP(h)) next.add(h);
      }
      // A truncated or empty download must not wipe a good list.
      if (next.size < 1000) throw new Error(`only ${next.size} entries`);
      hosts = next;
      etag = res.headers.get('etag');
      log(`${name}: loaded ${next.size} hosts`);
    } catch (e) {
      log(`${name}: refresh failed (${(e as Error).message})`);
    }
  };
  void load();
  const timer = setInterval(() => void load(), FEED_REFRESH_MS);
  timer.unref();
  return {
    name,
    async check(host) {
      if (!hosts) return null;
      // The host itself, then each parent down to the registrable domain.
      const stop = getDomain(host, { allowPrivateDomains: true }) ?? host;
      let h = host;
      for (;;) {
        if (hosts.has(h)) return true;
        if (h === stop || !h.includes('.')) return false;
        h = h.slice(h.indexOf('.') + 1);
      }
    },
    stop: () => clearInterval(timer),
  };
}

const MAX_HOSTS = 6;
const HOST_CACHE_MS = 30 * 60 * 1000;
const HOST_CACHE_MAX = 5000;

export function buildReputation(list: Provider[]): ReputationCheck {
  const cache = new Map<string, { listed: boolean; expires: number }>();
  const lookup = async (p: Provider, host: string): Promise<boolean | null> => {
    const key = `${p.name}\n${host}`;
    const hit = cache.get(key);
    if (hit && hit.expires > Date.now()) return hit.listed;
    const listed = await p.check(host).catch(() => null);
    if (listed !== null) {
      if (cache.size >= HOST_CACHE_MAX) cache.clear();
      cache.set(key, { listed, expires: Date.now() + HOST_CACHE_MS });
    }
    return listed;
  };
  return async (hosts) => {
    const names = [...new Set(hosts.map((h) => h.toLowerCase()))].filter((h) => !isIP(h.replace(/^\[|\]$/g, ''))).slice(0, MAX_HOSTS);
    const checked = new Set<string>();
    const flaggedBy = new Set<string>();
    let flaggedHost: string | null = null;
    await Promise.all(
      names.flatMap((host) =>
        list.map(async (p) => {
          const listed = await lookup(p, host);
          if (listed === null) return;
          checked.add(p.name);
          if (listed) {
            flaggedBy.add(p.name);
            // keep the earliest host in chain order
            if (flaggedHost === null || names.indexOf(host) < names.indexOf(flaggedHost)) flaggedHost = host;
          }
        }),
      ),
    );
    const order = list.map((p) => p.name);
    return { checked: order.filter((n) => checked.has(n)), flaggedBy: order.filter((n) => flaggedBy.has(n)), flaggedHost };
  };
}

/** The production set: three filtering resolvers and the Phishing.Database list. */
export function dnsReputation(log?: (msg: string) => void): ReputationCheck {
  return buildReputation([...dnsProviders(), domainListProvider('Phishing.Database', PHISHDB_URL, log)]);
}

export const noReputation: ReputationCheck = async () => ({ checked: [], flaggedBy: [], flaggedHost: null });
