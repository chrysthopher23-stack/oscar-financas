import {readFileSync, writeFileSync, mkdirSync, renameSync} from 'node:fs';
import {dirname, join} from 'node:path';

const ttl = 6 * 60 * 60 * 1000;
const historyTtl = 24 * 60 * 60 * 1000;
const historyFailureCooldown = 30 * 60 * 1000;
const manualRefreshInterval = 6 * 60 * 60 * 1000;
const cacheDirectory = join(import.meta.dirname, '.cache');
const cacheFile = join(cacheDirectory, 'cmc-quotes.json');
export const keyFile = join(import.meta.dirname, '..', '.secrets', 'coinmarketcap-api-key.txt');
function readKey() {
  try { return (process.env.COINMARKETCAP_API_KEY || readFileSync(keyFile, 'utf8')).trim(); }
  catch { return ''; }
}
export function createCoinMarketCapService({fetcher=fetch, now=Date.now, getKey=readKey, persist=true, cachePath=cacheFile}={}) {
  let cache = {};
  let chain = Promise.resolve();
  let retryAt = 0;
  let catalog = [];
  let catalogAt = 0;
  const upstreamCalls = {quotes:0, history:0, catalog:0};
  if(persist) { try { cache = JSON.parse(readFileSync(cachePath,'utf8')); } catch {} }
  async function request(path, params) {
    const key=getKey();
    if(!key) throw new Error('not_configured');
    if(now()<retryAt) throw new Error('temporarily_unavailable');
    const url=new URL(path,'https://pro-api.coinmarketcap.com');
    for(const [k,v] of Object.entries(params)) url.searchParams.set(k,v);
    try {
      if(path.endsWith('/historical')) upstreamCalls.history++;
      else if(path.endsWith('/quotes/latest')) upstreamCalls.quotes++;
      else upstreamCalls.catalog++;
      const response=await fetcher(url,{headers:{'X-CMC_PRO_API_KEY':key},signal:AbortSignal.timeout(15000)});
      if(!response.ok) throw new Error('provider_unavailable');
      const payload=await response.json();
      if(Number(payload.status?.error_code ?? 0) !== 0) throw new Error('provider_unavailable');
      return payload.data ?? payload;
    } catch(error) { retryAt=now()+60000; throw error; }
  }
  async function refreshHistory(ids) {
    const eligible = ids.filter(id => {
      const saved = cache[id];
      return saved && (!saved.historyRetryAfter || now() >= saved.historyRetryAfter);
    });
    if (!eligible.length) return;
    const end=new Date(now());
    const start=new Date(end.getTime()-7*24*60*60*1000);
    try {
      const payload=await request('/v3/cryptocurrency/quotes/historical',{
        id:eligible.join(','),
        time_start:start.toISOString(),
        time_end:end.toISOString(),
        interval:'1d',
        convert:'USD',
        skip_invalid:'true',
      });
      const rows = Array.isArray(payload) ? payload : Object.values(payload ?? {});
      const byId = new Map(rows
        .filter(row => row && typeof row === 'object' && row.id != null)
        .map(row => [String(row.id), row]));
      for (const id of eligible) {
        const cached = cache[id];
        const row = byId.get(id);
        if (!row || !Array.isArray(row.quotes)) {
          cached.historyRetryAfter = now() + historyFailureCooldown;
          continue;
        }
        const history=row.quotes.map(quote=>{
          const usd=quote?.quote?.USD;
          return {at:quote?.timestamp,price:String(usd?.price)};
        }).filter(point=>point.at && Number.isFinite(Number(point.price)) && Number(point.price)>=0);
        if(history.length>=2) cached.history=history.slice(-20);
        cached.historySavedAt=now();
        delete cached.historyRetryAfter;
      }
    } catch {
      for (const id of eligible) {
        cache[id].historyRetryAfter = now() + historyFailureCooldown;
      }
    }
  }
  function serialized(task) {
    const next=chain.then(task,task);
    chain=next.catch(()=>{});
    return next;
  }
  return {
    metrics() { return {...upstreamCalls}; },
    quotes(ids,{includeHistory=true,forceRefresh=false}={}) { return serialized(async()=> {
      const unique=[...new Set(ids.map(String))];
      if(unique.length>100 || unique.some(id=>!/^\d{1,9}$/.test(id))) throw new Error('invalid_ids');
      if(!unique.length) return {data:[]};
      const missing=unique.filter(id=>!cache[id] || now()-cache[id].savedAt>=ttl || (forceRefresh && now()-cache[id].savedAt>=manualRefreshInterval));
      if(missing.length) {
        try {
          const payload=await request('/v3/cryptocurrency/quotes/latest',{id:missing.join(','),convert:'USD',skip_invalid:'true'});
          const rows=Array.isArray(payload) ? payload : Object.values(payload).flat();
          for(const row of rows) {
            const id=String(row.id);
            if(!missing.includes(id)) continue;
            const q=Array.isArray(row.quote) ? row.quote.find(q=>q.symbol==='USD' || q.id===2781) : row.quote?.USD;
            const observedAt=q?.last_updated || row.last_updated;
            if(!q || !Number.isFinite(Number(q.price)) || Number(q.price)<0 || !observedAt) continue;
            const history=[...(cache[id]?.history ?? [])];
            if(history.at(-1)?.at !== observedAt) history.push({at:observedAt,price:String(q.price)});
            cache[id]={id, priceUsd:String(q.price), change24h:Number(q.percent_change_24h)||0, observedAt,savedAt:now(),history:history.slice(-120),historySavedAt:cache[id]?.historySavedAt};
          }
          if(persist) {
            mkdirSync(dirname(cachePath),{recursive:true});
            writeFileSync(cachePath+'.tmp',JSON.stringify(cache));
            renameSync(cachePath+'.tmp',cachePath);
          }
        } catch { /* Keep genuine saved quotes, marked stale below. */ }
      }
      const historyNeeds=includeHistory ? unique.filter(id=>{
        const saved=cache[id];
        return saved &&
          (!saved.historySavedAt || now()-saved.historySavedAt>=historyTtl) &&
          (!saved.historyRetryAfter || now()>=saved.historyRetryAfter);
      }) : [];
      if(historyNeeds.length) {
        await refreshHistory(historyNeeds);
        if(persist) {
          mkdirSync(dirname(cachePath),{recursive:true});
          writeFileSync(cachePath+'.tmp',JSON.stringify(cache));
          renameSync(cachePath+'.tmp',cachePath);
        }
      }
      return {data:unique.filter(id=>cache[id]).map(id=>{
        const {historyRetryAfter,...saved}=cache[id];
        return {...saved,stale:now()-saved.savedAt>=ttl};
      }), configured:Boolean(getKey())};
    }); },
    search(query) { return serialized(async()=> {
      if(!query.trim()) return {data:[]};
      if(now()-catalogAt>=24*60*60*1000 || !catalog.length) {
        try {
          const rows=await request('/v1/cryptocurrency/map',{limit:'5000',sort:'cmc_rank',listing_status:'active'});
          if(!Array.isArray(rows)) throw new Error('invalid_catalog');
          catalog=rows; catalogAt=now();
        } catch { return {data:[]}; }
      }
      const term=query.trim().toLowerCase();
      return {data:catalog.filter(c=>c.name.toLowerCase().includes(term)||c.symbol.toLowerCase().includes(term)).sort((a,b)=>Number(b.symbol.toLowerCase()===term)-Number(a.symbol.toLowerCase()===term)).slice(0,20).map(c=>({id:c.id,symbol:c.symbol,name:c.name}))};
    }); }
  };
}
const service=createCoinMarketCapService();
export function getCoinMarketCapMetrics() { return service.metrics(); }
export async function serveCoinMarketCap(request,response) {
  const url=new URL(request.url,'http://127.0.0.1');
  try {
    const payload=url.pathname.endsWith('/search') ? await service.search((url.searchParams.get('q')??'').slice(0,80)) : await service.quotes((url.searchParams.get('ids')??'').split(',').filter(Boolean),{includeHistory:url.searchParams.get('history')==='1',forceRefresh:url.searchParams.get('refresh')==='1'});
    response.writeHead(200,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});
    response.end(JSON.stringify(payload));
  } catch {
    response.writeHead(400,{'Content-Type':'application/json'});
    response.end('{"error":"invalid_request"}');
  }
}
