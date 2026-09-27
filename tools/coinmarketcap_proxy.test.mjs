import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createCoinMarketCapService} from './coinmarketcap_proxy.mjs';

test('only held IDs are requested once; grouped history parses the documented response', async()=> {
 let calls=0, historyCalls=0, time=Date.parse('2026-09-19T12:00:00Z'), fail=false;
 const service=createCoinMarketCapService({persist:false,now:()=>time,getKey:()=> 'private-test-key',fetcher:async(url,options)=> {
  calls++;
  assert.equal(url.searchParams.get('convert'),'USD');
  assert.equal(options.headers['X-CMC_PRO_API_KEY'],'private-test-key');
  if(fail) throw new Error('offline');
  if(url.pathname.endsWith('/historical')) {
   historyCalls++;
   assert.equal(url.pathname,'/v3/cryptocurrency/quotes/historical');
   assert.equal(url.searchParams.get('id'),'1,1027');
   return {ok:true,json:async()=>({data:Object.fromEntries([1,1027].map(id=>[String(id),{
    id,
    quotes:[
     {timestamp:'2026-09-18T00:00:00Z',quote:{USD:{price:id===1?59000:1900}}},
     {timestamp:'2026-09-19T00:00:00Z',quote:{USD:{price:id===1?60000:2000}}},
    ],
   }])),status:{error_code:0}})};
  }
  assert.equal(url.searchParams.get('id'),'1,1027');
  return {ok:true,json:async()=>({data:Object.fromEntries([1,1027].map(id=>[String(id),{id,quote:[{symbol:'USD',price:id===1?60000:2000,percent_change_24h:2,last_updated:new Date(time).toISOString()}]}])),status:{error_code:0}})};
 }});
 assert.deepEqual(await service.quotes([]),{data:[]});
 assert.equal(calls,0);
 const first=await Promise.all([service.quotes(['1','1','1027']),service.quotes(['1','1027'])]);
 assert.equal(calls,2);
 assert.equal(historyCalls,1);
 assert.equal(first[0].data[0].history.length,2);
 await service.quotes(['1']);
 assert.equal(calls,2);
 time+=6*3600000; fail=true;
 const stale=await service.quotes(['1','1027']);
 assert.equal(stale.data[0].stale,true);
 assert.equal(stale.data[0].history.length,2);
 assert.equal(JSON.stringify(stale).includes('private-test-key'),false);
});
test('missing key returns empty quotes without calling upstream',async()=> {
 const service=createCoinMarketCapService({persist:false,getKey:()=>'',fetcher:()=>{throw new Error('unexpected fetch');}});
 assert.deepEqual(await service.quotes(['1']),{data:[],configured:false});
});

test('twenty held crypto assets use one batched historical request',async()=> {
 const ids=Array.from({length:20},(_,index)=>String(index+1));
 let historyCalls=0;
 const service=createCoinMarketCapService({persist:false,now:()=>Date.parse('2026-09-27T12:00:00Z'),getKey:()=> 'test-key',fetcher:async(url)=> {
  if(url.pathname.endsWith('/historical')) {
   historyCalls++;
   assert.equal(url.searchParams.get('id'),ids.join(','));
   return {ok:true,json:async()=>({data:Object.fromEntries(ids.map(id=>[id,{id:Number(id),quotes:[
    {timestamp:'2026-09-26T00:00:00Z',quote:{USD:{price:100}}},
    {timestamp:'2026-09-27T00:00:00Z',quote:{USD:{price:101}}},
   ]}])),status:{error_code:0}})};
  }
  return {ok:true,json:async()=>({data:Object.fromEntries(ids.map(id=>[id,{id:Number(id),quote:[{symbol:'USD',price:101,percent_change_24h:1,last_updated:'2026-09-27T12:00:00Z'}]}])),status:{error_code:0}})};
 }});
 const result=await service.quotes(ids,{includeHistory:true});
 assert.equal(result.data.length,20);
 assert.equal(result.data.every(item=>item.history.length===2),true);
 assert.equal(historyCalls,1);
});

test('home skips historical provider calls until the investments chart needs them',async()=> {
 let quoteCalls=0, historyCalls=0;
 let time=Date.parse('2026-09-25T12:00:00Z');
 const service=createCoinMarketCapService({persist:false,now:()=>time,getKey:()=> 'test-key',fetcher:async(url)=> {
   if(url.pathname.endsWith('/historical')) {
    historyCalls++;
    assert.equal(url.searchParams.get('id'),'1');
    return {ok:true,json:async()=>({data:{'1':{id:1,quotes:[
     {timestamp:'2026-09-18T00:00:00Z',quote:{USD:{price:59000}}},
     {timestamp:'2026-09-19T00:00:00Z',quote:{USD:{price:60000}}},
    ]}},status:{error_code:0}})};
   }
   quoteCalls++;
   return {ok:true,json:async()=>({data:{'1':{id:1,quote:[{symbol:'USD',price:60000,percent_change_24h:1,last_updated:'2026-09-19T12:00:00Z'}]}},status:{error_code:0}})};
 }});
 await service.quotes(['1'],{includeHistory:false});
 assert.equal(quoteCalls,1);
 assert.equal(historyCalls,0);
 await service.quotes(['1'],{includeHistory:true});
 assert.equal(quoteCalls,1);
 assert.equal(historyCalls,1);
 await service.quotes(['1'],{includeHistory:true});
 assert.equal(historyCalls,1);
 time+=7*60*60*1000;
 await service.quotes(['1'],{includeHistory:true});
 assert.equal(quoteCalls,2);
 assert.equal(historyCalls,1);
 time+=18*60*60*1000;
 await service.quotes(['1'],{includeHistory:true});
 assert.equal(historyCalls,2);
 assert.deepEqual(service.metrics(),{quotes:3,history:2,catalog:0});
});

test('historical failure cooldown survives restart for 30 minutes',async()=> {
 const directory=mkdtempSync(join(tmpdir(),'cmc-proxy-cache-'));
 const cachePath=join(directory,'cache.json');
 try {
  let time=Date.parse('2026-09-27T12:00:00Z'), quoteCalls=0, historyCalls=0;
  const create=()=>createCoinMarketCapService({cachePath,now:()=>time,getKey:()=> 'test-key',fetcher:async(url)=> {
   if(url.pathname.endsWith('/historical')) {
    historyCalls++;
    return {ok:false,json:async()=>({})};
   }
   quoteCalls++;
   return {ok:true,json:async()=>({data:{'1':{id:1,quote:[{symbol:'USD',price:60000,percent_change_24h:1,last_updated:new Date(time).toISOString()}]}},status:{error_code:0}})};
  }});
  await create().quotes(['1'],{includeHistory:true});
  assert.deepEqual({quoteCalls,historyCalls},{quoteCalls:1,historyCalls:1});
  await create().quotes(['1'],{includeHistory:true});
  assert.deepEqual({quoteCalls,historyCalls},{quoteCalls:1,historyCalls:1});
  time+=30*60*1000+1;
  await create().quotes(['1'],{includeHistory:true});
  assert.deepEqual({quoteCalls,historyCalls},{quoteCalls:1,historyCalls:2});
 } finally {
  rmSync(directory,{recursive:true,force:true});
 }
});

test('manual crypto refresh is limited to once every six hours',async()=> {
 let time=Date.parse('2026-09-25T12:00:00Z'), calls=0;
 const service=createCoinMarketCapService({persist:false,now:()=>time,getKey:()=> 'test-key',fetcher:async()=> {
  calls++;
  return {ok:true,json:async()=>[{id:1,quote:[{symbol:'USD',price:60000,percent_change_24h:1,last_updated:new Date(time).toISOString()}]}]};
 }});
 await service.quotes(['1'],{includeHistory:false});
 for(let tap=0;tap<20;tap++) await service.quotes(['1'],{includeHistory:false,forceRefresh:true});
 assert.equal(calls,1);
 time+=6*60*60*1000+1000;
 await service.quotes(['1'],{includeHistory:false,forceRefresh:true});
 assert.equal(calls,2);
});
