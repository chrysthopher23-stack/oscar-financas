import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

export class PersistentMarketCache {
  constructor(file, { lifetimeMs, now = Date.now }) {
    this.file = file;
    this.lifetimeMs = lifetimeMs;
    this.now = now;
    this.entries = new Map();
    try {
      const stored = JSON.parse(readFileSync(file, 'utf8'));
      for (const [key, entry] of Object.entries(stored)) {
        if (typeof entry?.body === 'string' && Number.isFinite(entry.savedAt)) {
          this.entries.set(key, entry);
        }
      }
    } catch {
      // A missing or invalid cache must never prevent the app preview starting.
    }
  }

  get(key) {
    return this.entries.get(key);
  }

  isFresh(entry) {
    return Boolean(entry && this.now() - entry.savedAt < this.lifetimeMs);
  }

  set(key, body) {
    const entry = { body, savedAt: this.now() };
    this.entries.set(key, entry);
    mkdirSync(dirname(this.file), { recursive: true });
    const temporaryFile = `${this.file}.tmp`;
    writeFileSync(temporaryFile, JSON.stringify(Object.fromEntries(this.entries)));
    renameSync(temporaryFile, this.file);
    return entry;
  }
}
