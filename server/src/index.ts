import { loadConfig } from './config.js';
import { buildApp } from './server.js';

const cfg = loadConfig();
const { app } = await buildApp(cfg);

if (cfg.allowPrivate) app.log.warn('ALLOW_PRIVATE is on: private network targets are reachable. Never use this in production.');
if (!cfg.chromiumSandbox) app.log.warn('CHROMIUM_SANDBOX is off: the browser sandbox is disabled.');

for (const sig of ['SIGINT', 'SIGTERM'] as const) {
  process.once(sig, () => {
    void app.close().then(() => process.exit(0));
  });
}

await app.listen({ port: cfg.port, host: cfg.host });
