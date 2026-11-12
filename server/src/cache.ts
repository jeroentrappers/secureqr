import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';
import { mkdir, readdir, readFile, rename, stat, unlink, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

/**
 * Answers for recently checked links, on disk so they outlive a restart, or in
 * memory when no directory is given.
 *
 * Nothing in an entry says who asked: no address, no key, no count of scans.
 * A link can itself be personal (a token in the path), so each entry is
 * encrypted with a key derived from the link, and stored under a different
 * hash of it. The files can only be read by someone who already has the link.
 */

export interface CacheEntry<T> {
  value: T;
  /** Bytes kept next to the value (the picture of the page). */
  blob: Buffer | null;
  /** When the entry was written (ms since the epoch). */
  created: number;
}

const FILE = /^[0-9a-f]{64}\.bin$/;
const IV = 12;
const TAG = 16;
const digest = (purpose: string, link: string) => createHash('sha256').update(`secureqr-cache-${purpose}\n${link}`).digest();

export class ResultCache<T> {
  /** Oldest first. `data` is set only when there is no directory. */
  private index = new Map<string, { created: number; size: number; data?: Buffer }>();
  private bytes = 0;

  private constructor(
    private dir: string | null,
    private ttlMs: number,
    private maxBytes: number,
  ) {}

  /** A directory that cannot be used is reported and the cache falls back to memory. */
  static async open<T>(dir: string | null, ttlMs: number, maxBytes: number, log: (msg: string) => void = () => {}): Promise<ResultCache<T>> {
    if (dir === null) return new ResultCache<T>(null, ttlMs, maxBytes);
    const cache = new ResultCache<T>(dir, ttlMs, maxBytes);
    try {
      await mkdir(dir, { recursive: true, mode: 0o700 });
      const found: { name: string; created: number; size: number }[] = [];
      for (const file of await readdir(dir)) {
        const path = join(dir, file);
        // Anything else in here is a write that was cut short.
        if (!FILE.test(file)) {
          if (file.endsWith('.tmp')) await unlink(path).catch(() => {});
          continue;
        }
        const s = await stat(path);
        if (s.mtimeMs + ttlMs <= Date.now()) await unlink(path).catch(() => {});
        else found.push({ name: file.slice(0, 64), created: s.mtimeMs, size: s.size });
      }
      found.sort((a, b) => a.created - b.created);
      for (const f of found) {
        cache.index.set(f.name, { created: f.created, size: f.size });
        cache.bytes += f.size;
      }
      await cache.trim();
      log(`result cache: ${cache.index.size} entries in ${dir}`);
      return cache;
    } catch (e) {
      log(`result cache: ${dir} cannot be used (${(e as Error).message}); keeping results in memory`);
      return new ResultCache<T>(null, ttlMs, maxBytes);
    }
  }

  async get(link: string): Promise<CacheEntry<T> | null> {
    const name = digest('name', link).toString('hex');
    const known = this.index.get(name);
    if (!known) return null;
    if (known.created + this.ttlMs <= Date.now()) {
      await this.drop(name);
      return null;
    }
    try {
      const sealed = known.data ?? (await readFile(this.path(name)));
      const d = createDecipheriv('aes-256-gcm', digest('key', link), sealed.subarray(0, IV));
      d.setAuthTag(sealed.subarray(IV, IV + TAG));
      const plain = Buffer.concat([d.update(sealed.subarray(IV + TAG)), d.final()]);
      const jsonLength = plain.readUInt32BE(0);
      const value = JSON.parse(plain.subarray(4, 4 + jsonLength).toString('utf8')) as T;
      const blob = plain.subarray(4 + jsonLength);
      return { value, blob: blob.length > 0 ? blob : null, created: known.created };
    } catch {
      // Missing, damaged or written by an older version: as good as absent.
      await this.drop(name);
      return null;
    }
  }

  /** Never throws: a full or broken disk must not fail the check that produced the answer. */
  async put(link: string, value: T, blob: Buffer | null): Promise<void> {
    const name = digest('name', link).toString('hex');
    try {
      const json = Buffer.from(JSON.stringify(value), 'utf8');
      const head = Buffer.alloc(4);
      head.writeUInt32BE(json.length);
      const iv = randomBytes(IV);
      const c = createCipheriv('aes-256-gcm', digest('key', link), iv);
      const body = Buffer.concat([c.update(head), c.update(json), c.update(blob ?? Buffer.alloc(0)), c.final()]);
      const sealed = Buffer.concat([iv, c.getAuthTag(), body]);
      if (sealed.length > this.maxBytes) return;

      if (this.dir) {
        const tmp = join(this.dir, `${name}.${randomBytes(4).toString('hex')}.tmp`);
        await writeFile(tmp, sealed, { mode: 0o600 });
        await rename(tmp, this.path(name));
      }
      const old = this.index.get(name);
      if (old) this.bytes -= old.size;
      this.index.delete(name); // so the new entry goes to the young end
      this.index.set(name, { created: Date.now(), size: sealed.length, ...(this.dir ? {} : { data: sealed }) });
      this.bytes += sealed.length;
      await this.trim();
    } catch {
      await this.drop(name);
    }
  }

  private path(name: string): string {
    return join(this.dir!, `${name}.bin`);
  }

  private async drop(name: string): Promise<void> {
    const known = this.index.get(name);
    if (known) {
      this.bytes -= known.size;
      this.index.delete(name);
    }
    if (this.dir) await unlink(this.path(name)).catch(() => {});
  }

  /** Removes what has expired, then the oldest entries until the rest fits. */
  private async trim(): Promise<void> {
    const now = Date.now();
    for (const [name, e] of this.index) {
      if (e.created + this.ttlMs > now && this.bytes <= this.maxBytes) break;
      await this.drop(name);
    }
  }
}
