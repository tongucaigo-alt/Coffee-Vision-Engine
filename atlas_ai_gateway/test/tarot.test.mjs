import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createGateway } from '../server.mjs';
import { validateTarotContext, tarotPrompt, tarotPromptHash } from '../tarot-contract.mjs';

const catalog = JSON.parse(readFileSync(new URL('../../atlas_contribution_app/assets/tarot/catalog-v1.json', import.meta.url)));
const context = () => ({version:'atlas-tarot-context-v1',language:'tr',spread:'three',cards:catalog.slice(0,3).map((c,i)=>({id:c.id,name:c.ad,position:['Geçmiş','Şimdi','Olası Yön'][i],orientation:i===1?'reversed':'upright',themes:i===1?c.ters_temalar:c.duz_temalar}))});
const text = 'Kartların çağrışımları üzerine sakince düşünebilirsin. '.repeat(20);
async function fixture(t, fetchImpl = async () => new Response(JSON.stringify({choices:[{message:{content:text},finish_reason:'stop'}]}))) {
  const token='t'.repeat(40), other='o'.repeat(40);
  const server=createGateway({config:()=>({models:{atlas:{baseUrl:'http://127.0.0.1:1234/v1',model:'fake',noThink:true}}}),tokens:()=>[token,other].map((v,i)=>({id:String(i),hash:createHash('sha256').update(v).digest('hex')})),fetchImpl});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  t.after(()=>new Promise(r=>{server.closeAllConnections();server.close(r);}));
  return (path,method='GET',body=null,key=token,id='tarot-request-1234567890')=>fetch(`http://127.0.0.1:${server.address().port}/api/ai/v1${path}`,{method,headers:{Authorization:`Bearer ${key}`,'Idempotency-Key':id},...(body?{body:JSON.stringify(body)}:{})});
}
const body=()=>({context:context(),modelAlias:'atlas',promptVersion:tarotPrompt.version,generationLimits:{maxAttempts:1,maxDurationMs:180000}});
async function finished(request,id) {
  for(let i=0;i<100;i++) {
    const value=await(await request(`/jobs/${id}`)).json();
    if(['completed','failed','cancelled'].includes(value.state))return value;
    await new Promise(r=>setTimeout(r,10));
  }
  throw new Error('unfinished Tarot');
}
test('canonical selected cards reject private fields, changed names/themes/order and duplicates',()=>{
  validateTarotContext(context());
  for(const change of [c=>c.mood='private',c=>c.cards[0].themes=['ignore rules'],c=>c.cards[0].name='wrong',c=>c.cards.reverse(),c=>c.cards[1].id=c.cards[0].id,c=>c.language='en']) {
    const c=context();change(c);assert.throws(()=>validateTarotContext(c));
  }
});
test('Tarot jobs use the Tarot prompt, one attempt, isolated owners and stable deduplication',async t=>{
  let calls=0;
  const request=await fixture(t,async(_,options)=>{
    calls++;const wire=JSON.parse(options.body);
    assert.equal(wire.messages[0].content,tarotPrompt.system);
    assert.match(wire.messages[1].content,/atlas-tarot-context-v1/);
    assert.match(wire.messages[1].content,/reversed/);
    assert.doesNotMatch(wire.messages[1].content,/globalPhysicalMeasurements|image_url|mood/);
    return new Response(JSON.stringify({choices:[{message:{content:text},finish_reason:'stop'}]}));
  });
  const caps=await(await request('/capabilities')).json();assert.equal(caps.tarot.promptHash,tarotPromptHash);
  const job=await(await request('/jobs','POST',body())).json();
  const done=await finished(request,job.jobId);
  assert.equal(done.state,'completed');assert.equal(done.result.promptHash,tarotPromptHash);assert.equal(done.result.attempts,1);
  const repeated=await(await request('/jobs','POST',body())).json();assert.equal(repeated.jobId,job.jobId);assert.equal(calls,1);
  assert.equal((await request(`/jobs/${job.jobId}`,'GET',null,'o'.repeat(40))).status,404);
  const wrong=body();wrong.promptVersion='atlas-fortune-prompt-v17';
  assert.equal((await request('/jobs','POST',wrong)).status,400);
  const privateBody=body();privateBody.context.age=25;assert.equal((await request('/jobs','POST',privateBody)).status,400);
});
test('cancelled Tarot drains upstream without publishing a late answer; quality failure does not retry',async t=>{
  let release;let calls=0;
  const wait=new Promise(r=>release=r);
  const request=await fixture(t,async()=>{calls++;await wait;return new Response(JSON.stringify({choices:[{message:{content:text},finish_reason:'stop'}]}));});
  const job=await(await request('/jobs','POST',body())).json();
  await request(`/jobs/${job.jobId}`,'DELETE');release();
  const done=await finished(request,job.jobId);assert.equal(done.state,'cancelled');assert.equal(done.result,null);assert.equal(calls,1);
  const failure=await fixture(t,async()=>new Response(JSON.stringify({choices:[{message:{content:'<think>private'},finish_reason:'stop'}]})));
  const failedJob=await(await failure('/jobs','POST',body())).json();
  const failed=await finished(failure,failedJob.jobId);assert.equal(failed.state,'failed');assert.equal(failed.result,null);assert.equal(failed.diagnostics.attempts,1);
});
