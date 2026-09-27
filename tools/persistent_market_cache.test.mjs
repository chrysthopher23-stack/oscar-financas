import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { PersistentMarketCache } from './persistent_market_cache.mjs';

test('market cache survives reconstruction and expires after its TTL', (t) => {
  const directory = mkdtempSync(join(tmpdir(), 'oscar-market-cache-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const file = join(directory, 'history.json');
  const start = 1_800_000_000_000;
  let now = start;

  const firstRun = new PersistentMarketCache(file, {
    lifetimeMs: 6 * 60 * 60 * 1000,
    now: () => now,
  });
  firstRun.set('AAPL', '{"Time Series (Daily)":{}}');
  now += 1;
  firstRun.set('AAPL', '{"Time Series (Daily)":{"new":"series"}}');

  const afterRestart = new PersistentMarketCache(file, {
    lifetimeMs: 6 * 60 * 60 * 1000,
    now: () => now,
  });
  assert.equal(
    afterRestart.get('AAPL')?.body,
    '{"Time Series (Daily)":{"new":"series"}}',
  );
  assert.equal(afterRestart.isFresh(afterRestart.get('AAPL')), true);

  now += 6 * 60 * 60 * 1000;
  assert.equal(afterRestart.isFresh(afterRestart.get('AAPL')), false);
  assert.ok(afterRestart.get('AAPL'), 'expired data remains available as fallback');
});
