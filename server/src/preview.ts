import { chromium, type Browser, type BrowserContext, type Frame, type Page, type Request } from 'playwright';
import type { ResultCache } from './cache.js';
import type { Config } from './config.js';
import { GuardError, resolveTarget, type GuardOptions } from './netguard.js';
import { startEgressProxy, type EgressProxy } from './proxy.js';
import type { Reputation, ReputationCheck } from './reputation.js';
import type { ScreenshotStore } from './store.js';
import { judge, registrableDomain, type Evidence, type Verdict } from './verdict.js';

export type ErrorCode = 'invalid_url' | 'unauthorized' | 'blocked_target' | 'unreachable' | 'rate_limited' | 'timeout' | 'internal';

export class PreviewError extends Error {
  constructor(public readonly code: ErrorCode, message: string, public readonly status: number) {
    super(message);
  }
}

export interface Hop {
  url: string;
  host: string;
  status: number | null;
  kind: 'start' | 'http' | 'client';
}

export interface PreviewResult {
  id: string;
  requestedUrl: string;
  finalUrl: string;
  finalHost: string;
  finalDomain: string;
  title: string;
  https: boolean;
  hops: Hop[];
  screenshotUrl: string | null;
  reputation: Reputation;
  /** Set when the chain ends by handing over to another app (itsme://, intent://, …). */
  appLink: { scheme: string } | null;
  verdict: Verdict;
  durationMs: number;
  /** When the link was actually visited (ISO 8601). */
  checkedAt: string;
  /** True when this answer was reused from a recent check of the same link. */
  cached: boolean;
}

export type StepId = 'address' | 'blocklists' | 'redirects' | 'page' | 'forms' | 'picture';

/** Progress of a running check, in the order things happen. Labels are English, ready to display. */
export type ProgressEvent =
  | { type: 'step'; id: StepId; state: 'active' | 'done'; label: string }
  | { type: 'hop'; hop: Hop };

export interface PreviewOptions {
  skipPrecheck?: boolean;
  /** Called for each step of a fresh check. A reused answer reports no steps. */
  onProgress?: (e: ProgressEvent) => void;
}

/** What is kept for a checked link: the answer, and what the verdict was based on so it can be judged again. */
export interface KeptResult {
  result: PreviewResult;
  evidence: Evidence;
}

/** A browser tab with its own context and its own way out, used for one check and then thrown away. */
interface Slot {
  proxy: EgressProxy;
  context: BrowserContext;
  page: Page;
  close(): Promise<void>;
}

const VIEWPORT = { width: 390, height: 844 };
const MAX_URL_LENGTH = 2048;
const MAX_HOPS = 20;
const hostOf = (u: string) => new URL(u).hostname.replace(/^\[|\]$/g, '');

export function parseScannedUrl(raw: unknown): URL {
  if (typeof raw !== 'string' || raw.length === 0 || raw.length > MAX_URL_LENGTH) {
    throw new PreviewError('invalid_url', 'That is not a link we can check', 400);
  }
  let u: URL;
  try {
    u = new URL(raw.trim());
  } catch {
    throw new PreviewError('invalid_url', 'That is not a link we can check', 400);
  }
  if ((u.protocol !== 'http:' && u.protocol !== 'https:') || !u.hostname) {
    throw new PreviewError('invalid_url', 'Only web links can be checked', 400);
  }
  return u;
}

/**
 * Runs in the page: does it ask for a password or for card details?
 * Kept as source text so no build tool can rewrite it with helpers that do not exist in the page.
 */
const PROBE_FORMS = `(() => {
  const inputs = Array.from(document.querySelectorAll('input')).filter((i) => i.type !== 'hidden');
  const card = /card.?num|cc.?num|cardnumber|creditcard|\\bcvv\\b|\\bcvc\\b|kaartnummer|kartennummer|num[eé]ro de carte/i;
  return {
    password: inputs.some((i) => i.type === 'password'),
    payment: inputs.some((i) => {
      const ac = (i.getAttribute('autocomplete') || '').toLowerCase();
      if (ac.startsWith('cc-')) return true;
      return card.test([i.name, i.id, i.placeholder, i.getAttribute('aria-label') || ''].join(' '));
    }),
  };
})()`;

export class Previewer {
  private browser: Promise<Browser> | null = null;
  private active = 0;
  private waiting: (() => void)[] = [];
  private inFlight = new Map<string, Promise<PreviewResult>>();
  /** Tabs opened ahead of time, oldest first. */
  private spare: Promise<Slot>[] = [];
  private closed = false;
  private guard: GuardOptions;

  constructor(
    private cfg: Config,
    private store: ScreenshotStore,
    private reputation: ReputationCheck,
    private cache: ResultCache<KeptResult>,
  ) {
    this.guard = { allowPrivate: cfg.allowPrivate, allowedPorts: cfg.allowedPorts };
  }

  private launch(): Promise<Browser> {
    if (!this.browser) {
      const p = chromium
        .launch({
          chromiumSandbox: this.cfg.chromiumSandbox,
          args: [
            // Chromium skips the proxy for loopback by default; send that through the guard too.
            '--proxy-bypass-list=<-loopback>',
            '--force-webrtc-ip-handling-policy=disable_non_proxied_udp',
            '--disable-quic',
            '--disable-background-networking',
            '--disable-sync',
            '--disable-extensions',
            '--no-first-run',
          ],
        })
        .then((b) => {
          b.on('disconnected', () => {
            if (this.browser === p) this.browser = null;
          });
          return b;
        });
      p.catch(() => {
        if (this.browser === p) this.browser = null;
      });
      this.browser = p;
    }
    return this.browser;
  }

  /** Start the browser and open the spare tabs ahead of the first scan, so that scan does not pay for them. */
  warm(): void {
    this.launch().catch(() => {});
    this.refill();
  }

  /** A fresh context, with nothing carried over, behind its own egress proxy, and a blank tab in it. */
  private async open(): Promise<Slot> {
    const browser = await this.launch();
    const proxy = await startEgressProxy(this.guard);
    let context: BrowserContext | undefined;
    try {
      const major = browser.version().split('.')[0];
      context = await browser.newContext({
        proxy: { server: proxy.url, bypass: '<-loopback>' },
        viewport: VIEWPORT,
        deviceScaleFactor: 2,
        isMobile: true,
        hasTouch: true,
        userAgent: `Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${major}.0.0.0 Mobile Safari/537.36`,
        locale: 'en-US',
        serviceWorkers: 'block',
        acceptDownloads: false,
        permissions: [],
      });
      const ctx = context;
      const page = await ctx.newPage();
      return {
        proxy,
        context: ctx,
        page,
        close: async () => {
          await ctx.close().catch(() => {});
          await proxy.close();
        },
      };
    } catch (e) {
      await context?.close().catch(() => {});
      await proxy.close();
      throw e;
    }
  }

  /** Open spare tabs until the configured number is waiting. */
  private refill(): void {
    while (!this.closed && this.spare.length < this.cfg.warmPages) {
      const s = this.open();
      s.catch(() => {
        const i = this.spare.indexOf(s);
        if (i >= 0) this.spare.splice(i, 1);
      });
      this.spare.push(s);
    }
  }

  /** A tab for one check: a spare one when there is one, and a replacement is started right away. */
  private async take(): Promise<Slot> {
    for (let s = this.spare.shift(); s; s = this.spare.shift()) {
      const slot = await s.catch(() => null);
      if (slot && !slot.page.isClosed() && slot.context.browser()?.isConnected()) {
        this.refill();
        return slot;
      }
      await slot?.close(); // its browser went away while it waited
    }
    const slot = await this.open();
    this.refill();
    return slot;
  }

  async close(): Promise<void> {
    this.closed = true;
    for (const s of this.spare.splice(0)) await s.then((slot) => slot.close(), () => {});
    const b = this.browser;
    this.browser = null;
    if (b) await b.then((x) => x.close()).catch(() => {});
  }

  private async acquire(): Promise<void> {
    if (this.active < this.cfg.maxConcurrency) {
      this.active++;
      return;
    }
    if (this.waiting.length >= this.cfg.maxQueue) {
      throw new PreviewError('rate_limited', 'The service is busy. Try again in a moment', 429);
    }
    await new Promise<void>((resolve) => this.waiting.push(resolve));
  }

  private release(): void {
    const next = this.waiting.shift();
    if (next) next();
    else this.active--;
  }

  /**
   * Preview a link, reusing a kept answer for the same link. Reuse keeps a
   * popular code (a poster, a menu) from hitting its target on every scan, and
   * means a single-use link is visited once rather than once per viewer.
   */
  async preview(rawUrl: unknown, opts: PreviewOptions = {}): Promise<PreviewResult> {
    const url = parseScannedUrl(rawUrl);
    const key = url.href;
    const joined = (running: Promise<PreviewResult>) => running.then((r) => ({ ...r, cached: true }));
    let running = this.inFlight.get(key);
    if (running) return joined(running);
    const kept = await this.cache.get(key);
    if (kept) return this.reuse(kept.value, kept.blob);
    running = this.inFlight.get(key); // started while the cache was being read
    if (running) return joined(running);

    // Kept before the visit counts as over, so a request arriving in between finds one or the other.
    const fresh = this.visit(url, opts).then(async (v) => {
      await this.cache.put(key, { result: v.result, evidence: v.evidence }, v.shot);
      return v.result;
    });
    this.inFlight.set(key, fresh);
    try {
      return await fresh;
    } finally {
      this.inFlight.delete(key);
    }
  }

  /**
   * Answer from a kept result. The page is not visited again, but the
   * blocklists are asked again: a site can be listed after it was checked.
   */
  private async reuse(kept: KeptResult, shot: Buffer | null): Promise<PreviewResult> {
    const r = kept.result;
    if (shot && this.store.get(r.id) === null) this.store.put(r.id, shot);
    let { reputation, verdict } = r;
    const now = await this.reputation([...r.hops.map((h) => h.host), r.finalHost]).catch(() => null);
    // A listing always counts. "Not listed" only replaces the kept answer when every service that answered then answers now.
    if (now && (now.flaggedBy.length > 0 || (now.checked.length > 0 && reputation.checked.every((p) => now.checked.includes(p))))) {
      if (now.flaggedBy.join() !== reputation.flaggedBy.join()) verdict = judge({ ...kept.evidence, flaggedBy: now.flaggedBy });
      reputation = now;
    }
    return { ...r, screenshotUrl: shot ? r.screenshotUrl : null, reputation, verdict, cached: true };
  }

  private async visit(url: URL, opts: PreviewOptions): Promise<Visit> {
    const started = Date.now();
    const guard = this.guard;
    const emit = (e: ProgressEvent) => {
      try {
        opts.onProgress?.(e);
      } catch {
        // a listener that went away must not fail the check
      }
    };

    // Blocklist lookups do not need the browser: start them now, alongside everything else.
    const lookups = new Map<string, Promise<unknown>>();
    const lookUp = (host: string) => {
      if (!lookups.has(host)) lookups.set(host, this.reputation([host]).catch(() => null));
    };
    emit({ type: 'step', id: 'blocklists', state: 'active', label: 'Checking threat blocklists' });
    lookUp(url.hostname.replace(/^\[|\]$/g, ''));

    if (!opts.skipPrecheck) {
      emit({ type: 'step', id: 'address', state: 'active', label: 'Looking up the address' });
      try {
        await resolveTarget(url.hostname, url.port ? Number(url.port) : url.protocol === 'https:' ? 443 : 80, guard);
      } catch (e) {
        if (e instanceof GuardError && e.reason === 'blocked') throw blockedError();
        throw new PreviewError('unreachable', 'That site could not be found', 422);
      }
      emit({ type: 'step', id: 'address', state: 'done', label: 'Address found' });
    }

    await this.acquire();
    let timer: NodeJS.Timeout | undefined;
    const job = this.run(url, started, emit, lookUp, lookups);
    try {
      return await Promise.race([
        job.result,
        new Promise<never>((_, reject) => {
          timer = setTimeout(() => reject(new PreviewError('timeout', 'The page took too long to load', 504)), this.cfg.jobTimeoutMs);
        }),
      ]);
    } finally {
      clearTimeout(timer);
      job.result.catch(() => {});
      await job.dispose();
      this.release();
    }
  }

  private run(
    url: URL,
    started: number,
    emit: (e: ProgressEvent) => void,
    lookUp: (host: string) => void,
    lookups: Map<string, Promise<unknown>>,
  ) {
    let slot: Slot | null = null;
    let disposed = false;
    const dispose = async () => {
      disposed = true;
      await slot?.close().catch(() => {});
    };

    const result = (async (): Promise<Visit> => {
      const taken = await this.take();
      if (disposed) {
        // The check was given up on while the tab was being opened.
        await taken.close().catch(() => {});
        throw new PreviewError('timeout', 'The page took too long to load', 504);
      }
      slot = taken;
      const { proxy, context, page } = taken;
      context.on('page', (p) => {
        if (p !== page) void p.close().catch(() => {});
      });
      page.on('dialog', (d) => void d.dismiss().catch(() => {}));

      let download = false;
      page.on('download', (d) => {
        download = true;
        void d.cancel().catch(() => {});
      });

      const hops: (Hop & { req: Request })[] = [];
      page.on('request', (req) => {
        let main: Frame;
        try {
          if (!req.isNavigationRequest()) return;
          main = page.mainFrame();
          if (req.frame() !== main) return;
        } catch {
          return;
        }
        if (hops.length >= MAX_HOPS || !/^https?:/i.test(req.url())) return;
        const kind = hops.length === 0 ? 'start' : req.redirectedFrom() ? 'http' : 'client';
        const hop = { url: req.url(), host: hostOf(req.url()), status: null, kind } as const;
        const repeat = hops.at(-1)?.url === hop.url;
        hops.push({ ...hop, req });
        if (!repeat) {
          lookUp(hop.host);
          emit({ type: 'hop', hop });
        }
      });
      let appScheme: string | null = null;
      page.on('response', (res) => {
        const hop = hops.find((h) => h.req === res.request());
        if (!hop) return;
        hop.status = res.status();
        // A redirect to a non-web scheme hands over to an app; the browser cannot follow it.
        const loc = res.status() >= 300 && res.status() < 400 ? res.headers()['location'] : undefined;
        const m = loc ? /^([a-z][a-z0-9+.-]*):/i.exec(loc.trim()) : null;
        if (m && !/^https?$/i.test(m[1]!)) appScheme = m[1]!.toLowerCase();
      });

      emit({ type: 'step', id: 'redirects', state: 'active', label: 'Following the link' });
      let navError: unknown = null;
      try {
        await page.goto(url.href, { waitUntil: 'domcontentloaded', timeout: this.cfg.navTimeoutMs });
      } catch (e) {
        navError = e;
        // A link that answers with a file never commits a page; the download event can trail the error.
        if (/Download is starting/i.test(String((e as Error).message))) download = true;
      }

      const lastHopUrl = hops.at(-1)?.url ?? url.href;
      const committed = /^https?:/i.test(page.url());

      if (navError && !download && !appScheme && !committed) {
        const msg = String((navError as Error).message ?? navError);
        const lastHost = hostOf(lastHopUrl);
        const f = proxy.failures.find((x) => x.host === lastHost) ?? proxy.failures.find((x) => x.reason === 'blocked');
        if (f?.reason === 'blocked') throw blockedError();
        if (/Timeout .* exceeded/i.test(msg)) throw new PreviewError('timeout', 'The page took too long to load', 504);
        if (f?.reason === 'dns') throw new PreviewError('unreachable', 'That site could not be found', 422);
        if (/ERR_CERT|ERR_SSL|ERR_BAD_SSL/i.test(msg)) throw new PreviewError('unreachable', 'The site has a broken security certificate', 422);
        throw new PreviewError('unreachable', 'The site did not respond', 422);
      }

      // Blocklists: the per-host lookups started along the way have filled the cache; this adds them up.
      const sumUpBlocklists = async (): Promise<Reputation> => {
        const hosts = [...hops.map((h) => h.host), hostOf(committed ? page.url() : lastHopUrl)];
        hosts.forEach(lookUp);
        await Promise.all(lookups.values());
        const reputation = await this.reputation(hosts).catch((): Reputation => ({ checked: [], flaggedBy: [], flaggedHost: null }));
        emit({
          type: 'step',
          id: 'blocklists',
          state: 'done',
          label:
            reputation.flaggedBy.length > 0
              ? `Listed as malicious by ${reputation.flaggedBy.join(', ')}`
              : reputation.checked.length > 0
                ? `Not on ${reputation.checked.length === 1 ? 'the blocklist' : `${reputation.checked.length} blocklists`}`
                : 'Blocklists could not be reached',
        });
        return reputation;
      };
      let judging: Promise<Reputation>;

      let title = '';
      let asksPassword = false;
      let asksPayment = false;
      let shot = null as Buffer | null;

      if (committed) {
        emit({ type: 'step', id: 'page', state: 'active', label: 'Loading the page' });
        // Let the page finish and give script/meta redirects a chance to fire.
        await page.waitForLoadState('load', { timeout: 8000 }).catch(() => {});
        // "networkidle" already means half a second without traffic, so a page that reaches it needs a shorter look.
        let quiet = await page.waitForLoadState('networkidle', { timeout: 3000 }).then(
          () => true,
          () => false,
        );
        for (let i = 0; i < 4; i++) {
          const before = page.url();
          await page.waitForTimeout(quiet ? 300 : 700);
          if (page.url() === before) break;
          quiet = false;
          await page.waitForLoadState('load', { timeout: 5000 }).catch(() => {});
        }
        const moved = new Set(hops.map((h) => h.url)).size - 1;
        emit({ type: 'step', id: 'redirects', state: 'done', label: moved === 0 ? 'No redirects' : moved === 1 ? '1 redirect' : `${moved} redirects` });
        emit({ type: 'step', id: 'page', state: 'done', label: 'Page loaded' });
        judging = sumUpBlocklists(); // every site in the chain is known now

        // The form check and the picture read the same settled page; do them together.
        emit({ type: 'step', id: 'forms', state: 'active', label: 'Looking for sign-in and payment forms' });
        emit({ type: 'step', id: 'picture', state: 'active', label: 'Taking a picture of the page' });
        const probing = (async () => {
          title = (await page.title().catch(() => '')).slice(0, 200);
          await Promise.all(
            page
              .frames()
              .slice(0, 15)
              .map(async (frame) => {
                const r = await frame.evaluate<{ password: boolean; payment: boolean }>(PROBE_FORMS).catch(() => null);
                if (r?.password) asksPassword = true;
                if (r?.payment) asksPayment = true;
              }),
          );
          const found = asksPassword && asksPayment ? 'Asks for a password and card details' : asksPassword ? 'Asks for a password' : asksPayment ? 'Asks for card details' : 'No sign-in or payment forms';
          emit({ type: 'step', id: 'forms', state: 'done', label: found });
        })();
        const shooting = page
          .screenshot({ type: 'jpeg', quality: 72, animations: 'disabled', caret: 'hide', timeout: 10_000 })
          .catch(() => null)
          .then((b) => {
            shot = b;
            emit({ type: 'step', id: 'picture', state: 'done', label: b ? 'Picture taken' : 'No picture could be taken' });
          });
        await Promise.all([probing, shooting]);
      } else {
        const moved = new Set(hops.map((h) => h.url)).size - 1;
        emit({ type: 'step', id: 'redirects', state: 'done', label: moved <= 0 ? 'No redirects' : moved === 1 ? '1 redirect' : `${moved} redirects` });
        judging = sumUpBlocklists();
      }

      const finalUrl = committed ? page.url() : lastHopUrl;
      const cleanHops: Hop[] = [];
      for (const h of hops) {
        const prev = cleanHops.at(-1);
        if (prev && prev.url === h.url) {
          prev.status = h.status ?? prev.status;
          continue;
        }
        cleanHops.push({ url: h.url, host: h.host, status: h.status, kind: h.kind });
      }
      if (cleanHops.length === 0) cleanHops.push({ url: url.href, host: hostOf(url.href), status: null, kind: 'start' });

      const finalHost = hostOf(finalUrl);
      const reputation = await judging;

      const id = this.store.newId();
      if (shot) this.store.put(id, shot);

      const evidence: Evidence = {
        requestedUrl: url.href,
        finalUrl,
        redirects: cleanHops.length - 1,
        hopUrls: cleanHops.map((h) => h.url),
        download,
        asksPassword,
        asksPayment,
        flaggedBy: reputation.flaggedBy,
        appScheme,
      };
      const result: PreviewResult = {
        id,
        requestedUrl: url.href,
        finalUrl,
        finalHost,
        finalDomain: registrableDomain(finalHost),
        title,
        https: new URL(finalUrl).protocol === 'https:',
        hops: cleanHops,
        screenshotUrl: shot ? `/v1/screenshots/${id}.jpg` : null,
        reputation,
        appLink: appScheme ? { scheme: appScheme } : null,
        verdict: judge(evidence),
        durationMs: Date.now() - started,
        checkedAt: new Date(started).toISOString(),
        cached: false,
      };
      return { result, evidence, shot };
    })();

    return { result, dispose };
  }
}

/** A finished visit: the answer, what its verdict rests on, and the picture. */
interface Visit {
  result: PreviewResult;
  evidence: Evidence;
  shot: Buffer | null;
}

function blockedError(): PreviewError {
  return new PreviewError('blocked_target', 'This link points at a private network address, so it cannot be previewed', 400);
}
