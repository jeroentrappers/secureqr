import http from 'node:http';
import net from 'node:net';
import type { AddressInfo } from 'node:net';
import type { Duplex } from 'node:stream';
import { GuardError, resolveTarget, type GuardOptions } from './netguard.js';

export interface EgressFailure {
  host: string;
  reason: 'blocked' | 'dns' | 'connect' | 'limit';
}

export interface EgressProxy {
  url: string;
  failures: EgressFailure[];
  close(): Promise<void>;
}

export interface EgressLimits {
  maxBytes: number;
  maxConnections: number;
}

const DEFAULT_LIMITS: EgressLimits = { maxBytes: 60 * 1024 * 1024, maxConnections: 400 };
const UPSTREAM_TIMEOUT_MS = 20_000;

/**
 * A single-use forward proxy that one browser context sends all its traffic
 * through. Every connection is name-resolved and checked here, and the proxy
 * dials the checked IP itself, so the browser has no direct network path.
 */
export async function startEgressProxy(guard: GuardOptions, limits: EgressLimits = DEFAULT_LIMITS): Promise<EgressProxy> {
  const failures: EgressFailure[] = [];
  const sockets = new Set<Duplex>();
  let bytes = 0;
  let connections = 0;
  let closed = false;

  const track = <T extends Duplex>(s: T): T => {
    sockets.add(s);
    s.once('close', () => sockets.delete(s));
    s.on('error', () => {});
    return s;
  };
  const count = (n: number): boolean => {
    bytes += n;
    if (bytes <= limits.maxBytes) return true;
    for (const s of sockets) s.destroy();
    return false;
  };
  const admit = (host: string): boolean => {
    if (closed) return false;
    if (++connections > limits.maxConnections || bytes > limits.maxBytes) {
      failures.push({ host, reason: 'limit' });
      return false;
    }
    return true;
  };
  const fail = (host: string, err: unknown) => {
    failures.push({ host, reason: err instanceof GuardError ? err.reason : 'connect' });
  };

  const server = http.createServer();

  // HTTPS and WebSocket traffic: CONNECT host:port
  server.on('connect', (req, client: Duplex, head: Buffer) => {
    track(client);
    let host = '';
    let port = 443;
    try {
      const u = new URL(`http://${req.url}`);
      host = u.hostname.replace(/^\[|\]$/g, '');
      port = u.port ? Number(u.port) : 80;
    } catch {
      client.end('HTTP/1.1 400 Bad Request\r\n\r\n');
      return;
    }
    if (!admit(host)) {
      client.end('HTTP/1.1 403 Forbidden\r\n\r\n');
      return;
    }
    resolveTarget(host, port, guard).then(
      (target) => {
        const upstream = track(net.connect({ host: target.address, port, family: target.family }));
        upstream.setTimeout(UPSTREAM_TIMEOUT_MS, () => upstream.destroy());
        let established = false;
        upstream.once('connect', () => {
          established = true;
          client.write('HTTP/1.1 200 Connection Established\r\n\r\n');
          if (head.length) upstream.write(head);
          upstream.on('data', (d: Buffer) => void count(d.length));
          upstream.pipe(client);
          client.pipe(upstream);
        });
        upstream.once('error', (err) => {
          if (!established) {
            fail(host, err);
            client.end('HTTP/1.1 502 Bad Gateway\r\n\r\n');
          } else client.destroy();
        });
        upstream.once('close', () => client.destroy());
        client.once('close', () => upstream.destroy());
      },
      (err) => {
        fail(host, err);
        client.end(`HTTP/1.1 ${err instanceof GuardError && err.reason === 'blocked' ? '403 Forbidden' : '502 Bad Gateway'}\r\n\r\n`);
      },
    );
  });

  // Plain HTTP: absolute-form request line
  server.on('request', (req, res) => {
    track(req.socket);
    let u: URL;
    try {
      u = new URL(req.url ?? '');
      if (u.protocol !== 'http:') throw new Error('unsupported');
    } catch {
      res.writeHead(400).end();
      return;
    }
    const host = u.hostname.replace(/^\[|\]$/g, '');
    const port = u.port ? Number(u.port) : 80;
    if (!admit(host)) {
      req.socket.destroy();
      return;
    }
    resolveTarget(host, port, guard).then(
      (target) => {
        const headers = { ...req.headers };
        delete headers['proxy-connection'];
        delete headers['proxy-authorization'];
        const up = http.request(
          { host: target.address, family: target.family, port, method: req.method, path: u.pathname + u.search, headers, setHost: false, timeout: UPSTREAM_TIMEOUT_MS },
          (upRes) => {
            track(upRes.socket);
            res.writeHead(upRes.statusCode ?? 502, upRes.headers);
            upRes.on('data', (d: Buffer) => void count(d.length));
            upRes.pipe(res);
          },
        );
        up.on('timeout', () => up.destroy());
        up.on('error', (err) => {
          if (!res.headersSent) fail(host, err);
          req.socket.destroy();
        });
        req.pipe(up);
      },
      (err) => {
        // Never answer with a proxy-generated page: the browser would render it as if it were the site.
        fail(host, err);
        req.socket.destroy();
      },
    );
  });

  server.on('clientError', (_e, socket) => socket.destroy());
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const { port } = server.address() as AddressInfo;

  return {
    url: `http://127.0.0.1:${port}`,
    failures,
    close: () =>
      new Promise<void>((resolve) => {
        closed = true;
        for (const s of sockets) s.destroy();
        server.close(() => resolve());
        server.closeAllConnections();
      }),
  };
}
