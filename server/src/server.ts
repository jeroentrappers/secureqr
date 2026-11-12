import { createHash, timingSafeEqual } from 'node:crypto';
import { PassThrough } from 'node:stream';
import Fastify, { type FastifyInstance, type FastifyRequest } from 'fastify';
import rateLimit from '@fastify/rate-limit';
import { ResultCache } from './cache.js';
import type { Config } from './config.js';
import { parseScannedUrl, PreviewError, Previewer, type KeptResult } from './preview.js';
import { dnsReputation, type ReputationCheck } from './reputation.js';
import { ScreenshotStore } from './store.js';

export interface AppDeps {
  reputation?: ReputationCheck;
  logger?: boolean;
}

export async function buildApp(cfg: Config, deps: AppDeps = {}): Promise<{ app: FastifyInstance; previewer: Previewer }> {
  const app = Fastify({ logger: deps.logger ?? true, trustProxy: cfg.trustProxy, bodyLimit: 8 * 1024 });
  const store = new ScreenshotStore(cfg.screenshotTtlMs);
  const cache = await ResultCache.open<KeptResult>(cfg.cacheDir, cfg.resultTtlMs, cfg.cacheMaxBytes, (msg) => app.log.info(msg));
  const previewer = new Previewer(cfg, store, deps.reputation ?? dnsReputation((msg) => app.log.info(msg)), cache);

  const fail = (code: string, message: string) => ({ error: { code, message } });

  await app.register(rateLimit, {
    global: false,
    max: cfg.rateLimitPerMinute,
    timeWindow: '1 minute',
    errorResponseBuilder: () => ({ statusCode: 429, ...fail('rate_limited', 'Too many scans. Wait a minute and try again') }),
  });

  app.setErrorHandler((err: Error & { statusCode?: number; validation?: unknown }, req, reply) => {
    if (err instanceof PreviewError) return reply.code(err.status).send(fail(err.code, err.message));
    if (err.statusCode === 429) return reply.code(429).send(fail('rate_limited', 'Too many scans. Wait a minute and try again'));
    if (err.statusCode && err.statusCode >= 400 && err.statusCode < 500) {
      return reply.code(400).send(fail('invalid_url', 'That is not a link we can check'));
    }
    req.log.error({ err }, 'preview failed');
    return reply.code(500).send(fail('internal', 'Something went wrong on our side'));
  });
  app.setNotFoundHandler((_req, reply) => reply.code(404).send(fail('not_found', 'Not found')));

  app.get('/healthz', async () => ({ ok: true }));

  // The app key keeps casual callers out. Compared as digests so the check takes the same time for any input.
  const digest = (k: string) => createHash('sha256').update(k).digest();
  const accepted = cfg.apiKeys.map(digest);
  const needsKey = async (req: FastifyRequest) => {
    if (accepted.length === 0) return;
    const given = req.headers['x-secureqr-key'];
    const d = digest(typeof given === 'string' ? given : '');
    // no early exit: every accepted key is compared
    const ok = accepted.reduce((hit, k) => timingSafeEqual(k, d) || hit, false);
    if (!ok) throw new PreviewError('unauthorized', 'This copy of the app can no longer use the service. Update SecureQR and try again.', 401);
  };
  // One line per preview request, for the traffic alert on the host. No URLs, no keys.
  app.addHook('onResponse', async (req, reply) => {
    if (req.method === 'POST' && req.url.startsWith('/v1/preview')) req.log.info({ status: reply.statusCode }, 'api');
  });

  app.post('/v1/preview', { config: { rateLimit: {} }, preHandler: needsKey }, async (req) => {
    const body = req.body as { url?: unknown } | null;
    const result = await previewer.preview(body?.url);
    // Log hosts only, never full URLs: paths and queries can carry personal tokens.
    req.log.info({ start: result.hops[0]?.host, final: result.finalHost, level: result.verdict.level, ms: result.durationMs }, 'preview');
    return result;
  });

  // The same check, reported step by step as newline-delimited JSON. The last line is the result or an error.
  app.post('/v1/preview/stream', { config: { rateLimit: {} }, preHandler: needsKey }, async (req, reply) => {
    const body = req.body as { url?: unknown } | null;
    parseScannedUrl(body?.url); // a link we cannot check at all is a plain 400, not a stream
    const out = new PassThrough();
    const line = (o: unknown) => {
      if (!out.writableEnded) out.write(JSON.stringify(o) + '\n');
    };
    previewer
      .preview(body?.url, { onProgress: line })
      .then(
        (result) => {
          req.log.info({ start: result.hops[0]?.host, final: result.finalHost, level: result.verdict.level, ms: result.durationMs }, 'preview');
          line({ type: 'result', result });
        },
        (err: unknown) => {
          if (err instanceof PreviewError) return line({ type: 'error', status: err.status, error: { code: err.code, message: err.message } });
          req.log.error({ err }, 'preview failed');
          line({ type: 'error', status: 500, error: { code: 'internal', message: 'Something went wrong on our side' } });
        },
      )
      .finally(() => out.end());
    return reply
      .header('content-type', 'application/x-ndjson; charset=utf-8')
      .header('cache-control', 'no-store')
      .header('x-accel-buffering', 'no') // nginx: pass each line on as it is written
      .send(out);
  });

  app.get<{ Params: { file: string } }>('/v1/screenshots/:file', async (req, reply) => {
    const m = /^([0-9a-f]{16})\.jpg$/.exec(req.params.file);
    const data = m ? store.get(m[1]!) : null;
    if (!data) return reply.code(404).send(fail('not_found', 'This preview has expired'));
    return reply.header('content-type', 'image/jpeg').header('cache-control', 'private, max-age=600').send(data);
  });

  app.addHook('onClose', async () => {
    await previewer.close();
  });

  return { app, previewer };
}
