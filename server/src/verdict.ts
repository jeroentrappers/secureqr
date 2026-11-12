import { isIP } from 'node:net';
import { getDomain } from 'tldts';
import { english, type Params } from './i18n.js';

export type Level = 'ok' | 'caution' | 'danger';
export interface Reason {
  code: string;
  /** English; put into the asker's language from code and params when the answer is sent. */
  message: string;
  params?: Params;
}

const reason = (code: string, params?: Params): Reason => ({ code, message: english(`reason.${code}`, params), ...(params ? { params } : {}) });
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
    danger.push(reason('known_malicious', { providers: e.flaggedBy }));
  }
  if (e.download) danger.push(reason('download'));
  if (final.protocol !== 'https:') danger.push(reason('not_https'));
  if (isIP(finalHost)) danger.push(reason('ip_address'));
  if (finalHost.split('.').some((l) => l.startsWith('xn--'))) {
    danger.push(reason('lookalike_domain'));
  }
  const hasCreds = [e.requestedUrl, ...e.hopUrls].some((raw) => {
    try {
      const u = new URL(raw);
      return u.username !== '' || u.password !== '';
    } catch {
      return false;
    }
  });
  if (hasCreds) danger.push(reason('embedded_credentials'));

  if (registrableDomain(bareHost(start)) !== registrableDomain(finalHost)) {
    caution.push(reason('domain_changed'));
  }
  if (e.appScheme) caution.push(reason('opens_app', { scheme: e.appScheme }));
  if (e.asksPayment) caution.push(reason('asks_for_payment'));
  if (e.asksPassword) caution.push(reason('asks_for_password'));
  if (e.redirects >= 3) caution.push(reason('many_redirects', { count: e.redirects }));

  return { level: danger.length ? 'danger' : caution.length ? 'caution' : 'ok', reasons: [...danger, ...caution] };
}
