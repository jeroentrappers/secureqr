import { loadConfig } from './config.js';
import { buildApp } from './server.js';

const cfg = loadConfig();
const { app, previewer } = await buildApp(cfg);

if (cfg.allowPrivate) app.log.warn('ALLOW_PRIVATE is on: private network targets are reachable. Never use this in production.');
if (cfg.apiKeys.length === 0) app.log.warn('API_KEYS is not set: the preview endpoints accept anyone.');
if (!cfg.chromiumSandbox) app.log.warn('CHROMIUM_SANDBOX is off: the browser sandbox is disabled.');

for (const sig of ['SIGINT', 'SIGTERM'] as const) {
  process.once(sig, () => {
    void app.close().then(() => process.exit(0));
  });
}

await app.listen({ port: cfg.port, host: cfg.host });
previewer.warm();
