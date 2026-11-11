import Fastify, { type FastifyInstance } from 'fastify';
import rateLimit from '@fastify/rate-limit';
import type { Config } from './config.js';
import { PreviewError, Previewer } from './preview.js';
import { dnsReputation, type ReputationCheck } from './reputation.js';
import { ScreenshotStore } from './store.js';

export interface AppDeps {
  reputation?: ReputationCheck;
  logger?: boolean;
}

export async function buildApp(cfg: Config, deps: AppDeps = {}): Promise<{ app: FastifyInstance; previewer: Previewer }> {
  const app = Fastify({ logger: deps.logger ?? true, trustProxy: cfg.trustProxy, bodyLimit: 8 * 1024 });
  const store = new ScreenshotStore(cfg.screenshotTtlMs);
  const previewer = new Previewer(cfg, store, deps.reputation ?? dnsReputation((msg) => app.log.info(msg)));

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

  app.post('/v1/preview', { config: { rateLimit: {} } }, async (req) => {
    const body = req.body as { url?: unknown } | null;
    const result = await previewer.preview(body?.url);
    // Log hosts only, never full URLs: paths and queries can carry personal tokens.
    req.log.info({ start: result.hops[0]?.host, final: result.finalHost, level: result.verdict.level, ms: result.durationMs }, 'preview');
    return result;
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
