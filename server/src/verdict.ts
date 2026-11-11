import { isIP } from 'node:net';
import { getDomain } from 'tldts';

export type Level = 'ok' | 'caution' | 'danger';
export interface Reason {
  code: string;
  message: string;
}
export interface Verdict {
  level: Level;
  reasons: Reason[];
}

export interface Evidence {
  requestedUrl: string;
  finalUrl: string;
  /** Number of redirects followed (hops minus the starting URL). */
  redirects: number;
  hopUrls: string[];
  download: boolean;
  asksPassword: boolean;
  asksPayment: boolean;
  /** Blocklist providers that list a host in the chain. */
  flaggedBy?: string[];
  /** Scheme of the app the chain hands over to, if any. */
  appScheme?: string | null;
}

const bareHost = (u: URL) => u.hostname.replace(/^\[|\]$/g, '');

/** Registrable domain (eTLD+1); for IP addresses and unknown suffixes, the host itself. */
export function registrableDomain(host: string): string {
  if (isIP(host)) return host;
  return getDomain(host, { allowPrivateDomains: true }) ?? host;
}

export function judge(e: Evidence): Verdict {
  const danger: Reason[] = [];
  const caution: Reason[] = [];
  const start = new URL(e.requestedUrl);
  const final = new URL(e.finalUrl);
  const finalHost = bareHost(final);

  if (e.flaggedBy?.length) {
    danger.push({ code: 'known_malicious', message: `Listed as malicious by ${new Intl.ListFormat('en', { type: 'conjunction' }).format(e.flaggedBy)}` });
  }
  if (e.download) danger.push({ code: 'download', message: 'The link tried to download a file' });
  if (final.protocol !== 'https:') danger.push({ code: 'not_https', message: 'The final page is not encrypted' });
  if (isIP(finalHost)) danger.push({ code: 'ip_address', message: 'The address is a bare number, not a name' });
  if (finalHost.split('.').some((l) => l.startsWith('xn--'))) {
    danger.push({ code: 'lookalike_domain', message: 'The address uses look-alike characters' });
  }
  const hasCreds = [e.requestedUrl, ...e.hopUrls].some((raw) => {
    try {
      const u = new URL(raw);
      return u.username !== '' || u.password !== '';
    } catch {
      return false;
    }
  });
  if (hasCreds) danger.push({ code: 'embedded_credentials', message: 'The link hides a login name inside the address' });

  if (registrableDomain(bareHost(start)) !== registrableDomain(finalHost)) {
    caution.push({ code: 'domain_changed', message: 'Ends at a different site than it starts' });
  }
  if (e.appScheme) caution.push({ code: 'opens_app', message: `The link tries to open another app (${e.appScheme})` });
  if (e.asksPayment) caution.push({ code: 'asks_for_payment', message: 'The page asks for card details' });
  if (e.asksPassword) caution.push({ code: 'asks_for_password', message: 'The page asks for a password' });
  if (e.redirects >= 3) caution.push({ code: 'many_redirects', message: `Passed through ${e.redirects} redirects` });

  return { level: danger.length ? 'danger' : caution.length ? 'caution' : 'ok', reasons: [...danger, ...caution] };
}
