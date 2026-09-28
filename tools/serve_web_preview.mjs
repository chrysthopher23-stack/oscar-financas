import { execFile } from 'node:child_process';
import { getCoinMarketCapMetrics, serveCoinMarketCap } from './coinmarketcap_proxy.mjs';
import { createReadStream, existsSync, readFileSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize } from 'node:path';
import { PersistentMarketCache } from './persistent_market_cache.mjs';

const root = normalize(join(import.meta.dirname, '..', 'app', 'build', 'web'));
const port = Number(process.env.PORT ?? process.env.OSCAR_PREVIEW_PORT ?? 8765);
const host = process.env.HOST ?? '127.0.0.1';
const secretPath = join(process.env.LOCALAPPDATA ?? '', 'OscarFinancas', 'awesome-api-key.txt');
const alphaSecretPath = join(process.env.LOCALAPPDATA ?? '', 'OscarFinancas', 'alpha-vantage-api-key.txt');
const hgSecretPath = join(process.env.LOCALAPPDATA ?? '', 'OscarFinancas', 'hg-brasil-api-key.txt');
const marketCacheLifetime = 6 * 60 * 60 * 1000;
const manualRefreshInterval = 6 * 60 * 60 * 1000;
const assetCache = new PersistentMarketCache(
  join(import.meta.dirname, '.cache', 'asset-history.json'),
  { lifetimeMs: marketCacheLifetime },
);
const hgAssetCache = new PersistentMarketCache(
  join(import.meta.dirname, '.cache', 'hg-asset-quotes.json'),
  { lifetimeMs: marketCacheLifetime },
);
const upstreamCalls = {fx: 0, alphaVantage: 0, hgBrasil: 0};
const mime = {
  '.css': 'text/css; charset=utf-8', '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.png': 'image/png',
  '.svg': 'image/svg+xml', '.wasm': 'application/wasm',
};

if (!existsSync(join(root, 'index.html'))) {
  console.error('A previa ainda nao foi compilada. Avise o Codex.');
  process.exit(1);
}

async function serveQuotes(response) {
  try {
    const apiKey = (process.env.AWESOME_API_KEY ??
      (existsSync(secretPath) ? readFileSync(secretPath, 'utf8') : '')).trim();
    if (!apiKey) throw new Error('missing key');
    upstreamCalls.fx++;
    const upstream = await fetch(
      'https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL,INR-BRL',
      { headers: { 'x-api-key': apiKey } },
    );
    if (!upstream.ok) throw new Error(`upstream ${upstream.status}`);
    const body = await upstream.text();
    response.writeHead(200, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    response.end(body);
  } catch {
    response.writeHead(503, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    response.end('{"error":"quotes_unavailable"}');
  }
}

async function serveAssetHistory(request, response) {
  let cached;
  try {
    const requestUrl = new URL(request.url ?? '/', 'http://127.0.0.1');
    const symbol = (requestUrl.searchParams.get('symbol') ?? '').trim().toUpperCase();
    if (!/^[A-Z0-9.^-]{1,24}$/.test(symbol)) throw new Error('invalid symbol');
    cached = assetCache.get(symbol);
    const refresh = requestUrl.searchParams.get('refresh') === '1';
    const canRefresh = refresh && cached && Date.now() - cached.savedAt >= manualRefreshInterval;
    if (assetCache.isFresh(cached) && !canRefresh) {
      response.writeHead(200, {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'private, max-age=300',
        'X-Market-Cache': 'hit',
      });
      response.end(cached.body);
      return;
    }
    const apiKey = (process.env.ALPHA_VANTAGE_API_KEY ??
      (existsSync(alphaSecretPath) ? readFileSync(alphaSecretPath, 'utf8') : '')).trim();
    if (!apiKey) throw new Error('missing key');
    const upstreamUrl = new URL('https://www.alphavantage.co/query');
    upstreamUrl.searchParams.set('function', 'TIME_SERIES_DAILY');
    upstreamUrl.searchParams.set('symbol', symbol);
    upstreamUrl.searchParams.set('outputsize', 'compact');
    upstreamUrl.searchParams.set('apikey', apiKey);
    upstreamCalls.alphaVantage++;
    const upstream = await fetch(upstreamUrl);
    if (!upstream.ok) throw new Error(`upstream ${upstream.status}`);
    const body = await upstream.text();
    const parsed = JSON.parse(body);
    if (!parsed['Time Series (Daily)']) throw new Error('series unavailable');
    assetCache.set(symbol, body);
    response.writeHead(200, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'private, max-age=300',
      'X-Market-Cache': 'miss',
    });
    response.end(body);
  } catch {
    if (cached) {
      response.writeHead(200, {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'private, max-age=60',
        'X-Market-Cache': 'stale',
      });
      response.end(cached.body);
      return;
    }
    response.writeHead(503, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    response.end('{"error":"asset_history_unavailable"}');
  }
}

async function serveHgAsset(request, response) {
  let cached;
  try {
    const requestUrl = new URL(request.url ?? '/', 'http://127.0.0.1');
    const symbol = (requestUrl.searchParams.get('symbol') ?? '').trim().toUpperCase();
    if (!/^[A-Z0-9.^-]{1,24}$/.test(symbol)) throw new Error('invalid symbol');
    cached = hgAssetCache.get(symbol);
    const refresh = requestUrl.searchParams.get('refresh') === '1';
    const canRefresh = refresh && cached && Date.now() - cached.savedAt >= manualRefreshInterval;
    if (hgAssetCache.isFresh(cached) && !canRefresh) {
      response.writeHead(200, {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'private, max-age=300',
        'X-Market-Cache': 'hit',
      });
      response.end(cached.body);
      return;
    }
    const apiKey = (process.env.HG_BRASIL_API_KEY ??
      (existsSync(hgSecretPath) ? readFileSync(hgSecretPath, 'utf8') : '')).trim();
    if (!apiKey) throw new Error('missing key');
    const upstreamUrl = new URL('https://api.hgbrasil.com/finance/stock_price');
    upstreamUrl.searchParams.set('key', apiKey);
    upstreamUrl.searchParams.set('symbol', symbol);
    upstreamCalls.hgBrasil++;
    const upstream = await fetch(upstreamUrl);
    if (!upstream.ok) throw new Error(`upstream ${upstream.status}`);
    const body = await upstream.text();
    const parsed = JSON.parse(body);
    if (!parsed.results || parsed.valid_key === false) throw new Error('quote unavailable');
    hgAssetCache.set(symbol, body);
    response.writeHead(200, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'private, max-age=300',
      'X-Market-Cache': 'miss',
    });
    response.end(body);
  } catch {
    if (cached) {
      response.writeHead(200, {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'private, max-age=60',
        'X-Market-Cache': 'stale',
      });
      response.end(cached.body);
      return;
    }
    response.writeHead(503, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    response.end('{"error":"hg_asset_unavailable"}');
  }
}
const server = createServer(async (request, response) => {
  const rawPath = decodeURIComponent((request.url ?? '/').split('?')[0]);
  if (rawPath === '/health') {
    response.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    response.end('{"ok":true}');
    return;
  }
  if (rawPath === '/api/metrics') {
    response.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
    response.end(JSON.stringify({upstreamCalls: {...upstreamCalls, coinMarketCap: getCoinMarketCapMetrics()}}));
    return;
  }
  if (rawPath === '/api/crypto/quotes' || rawPath === '/api/crypto/search') {
    await serveCoinMarketCap(request, response);
    return;
  }
  if (rawPath === '/api/fx') {
    await serveQuotes(response);
    return;
  }
  if (rawPath === '/api/assets/history') {
    await serveAssetHistory(request, response);
    return;
  }
  if (rawPath === '/api/assets/hg') {
    await serveHgAsset(request, response);
    return;
  }
  const relative = rawPath === '/' ? 'index.html' : rawPath.replace(/^\/+/, '');
  let file = normalize(join(root, relative));
  if (!file.startsWith(root) || !existsSync(file) || !statSync(file).isFile()) {
    file = join(root, 'index.html');
  }
  response.writeHead(200, {
    'Content-Type': mime[extname(file)] ?? 'application/octet-stream',
    'Cache-Control': 'no-store',
  });
  createReadStream(file).pipe(response);
});

server.listen(port, host, () => {
  const displayHost = host === '0.0.0.0' ? 'localhost' : host;
  const url = `http://${displayHost}:${port}`;
  if (
    process.platform === 'win32' &&
    process.env.OSCAR_PREVIEW_OPEN_BROWSER !== '0'
  ) {
    execFile('cmd.exe', ['/c', 'start', '', url], { windowsHide: true });
  }
  console.log(`Oscar Financas aberto em ${url}`);
  if (process.env.RENDER !== 'true') {
    console.log('Feche esta janela preta para encerrar a previa.');
  }
});


