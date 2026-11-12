import { randomBytes } from 'node:crypto';

/** Short-lived in-memory screenshot store, for pictures the apps are about to fetch. */
export class ScreenshotStore {
  private items = new Map<string, { data: Buffer; expires: number }>();
  constructor(private ttlMs: number, private maxItems = 300) {}

  newId(): string {
    return randomBytes(8).toString('hex');
  }

  put(id: string, data: Buffer): void {
    this.sweep();
    while (this.items.size >= this.maxItems) {
      const oldest = this.items.keys().next().value;
      if (oldest === undefined) break;
      this.items.delete(oldest);
    }
    this.items.set(id, { data, expires: Date.now() + this.ttlMs });
  }

  get(id: string): Buffer | null {
    const it = this.items.get(id);
    if (!it) return null;
    if (it.expires < Date.now()) {
      this.items.delete(id);
      return null;
    }
    return it.data;
  }

  private sweep(): void {
    const now = Date.now();
    for (const [id, it] of this.items) if (it.expires < now) this.items.delete(id);
  }
}
