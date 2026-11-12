export interface Config {
  port: number;
  host: string;
  rateLimitPerMinute: number;
  maxConcurrency: number;
  maxQueue: number;
  /** Ports the headless browser may connect to. null = any. */
  allowedPorts: Set<number> | null;
  /** Allow private/loopback targets. For tests and local development only. */
  allowPrivate: boolean;
  chromiumSandbox: boolean;
  trustProxy: boolean;
  screenshotTtlMs: number;
  navTimeoutMs: number;
  jobTimeoutMs: number;
  /** App keys accepted on the preview endpoints. Empty = no key needed (local development). */
  apiKeys: string[];
  /** Browser tabs kept open and ready, so a check starts without setting one up. 0 = none. */
  warmPages: number;
  /** Where answers for recent links are kept. null = in memory only. */
  cacheDir: string | null;
  /** How long the answer for a link is reused. */
  resultTtlMs: number;
  cacheMaxBytes: number;
}

const bool = (v: string | undefined, d: boolean) => (v === undefined ? d : v === '1' || v.toLowerCase() === 'true');
const int = (v: string | undefined, d: number) => {
  const n = Number(v);
  return v !== undefined && Number.isFinite(n) && n > 0 ? Math.floor(n) : d;
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const ports = (env.ALLOWED_PORTS ?? '80,443,8080,8443').trim();
  return {
    port: int(env.PORT, 8080),
    host: env.HOST ?? '0.0.0.0',
    rateLimitPerMinute: int(env.RATE_LIMIT_PER_MIN, 20),
    maxConcurrency: int(env.MAX_CONCURRENCY, 3),
    maxQueue: int(env.MAX_QUEUE, 12),
    allowedPorts: ports === '*' ? null : new Set(ports.split(',').map((p) => Number(p.trim())).filter((p) => p > 0)),
    allowPrivate: bool(env.ALLOW_PRIVATE, false),
    chromiumSandbox: bool(env.CHROMIUM_SANDBOX, true),
    trustProxy: bool(env.TRUST_PROXY, false),
    screenshotTtlMs: int(env.SCREENSHOT_TTL_SEC, 900) * 1000,
    navTimeoutMs: int(env.NAV_TIMEOUT_MS, 15000),
    jobTimeoutMs: int(env.JOB_TIMEOUT_MS, 30000),
    apiKeys: (env.API_KEYS ?? '').split(',').map((k) => k.trim()).filter((k) => k.length > 0),
    warmPages: /^\d+$/.test(env.WARM_PAGES ?? '') ? Number(env.WARM_PAGES) : 2,
    cacheDir: env.CACHE_DIR?.trim() || null,
    resultTtlMs: int(env.RESULT_TTL_SEC, 3600) * 1000,
    cacheMaxBytes: int(env.CACHE_MAX_MB, 256) * 1024 * 1024,
  };
}
