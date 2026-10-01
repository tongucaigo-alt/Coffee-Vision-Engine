import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {createGateway} from '../server.mjs';
import {validateContext,prompt,promptBytes,promptHash,messages,qualityError} from '../contract.mjs';

export const context = () => ({version:'atlas-fortune-context-v1',language:'tr',status:'ready',photos:[0,1,2].map(i=>({photoNumber:i+1,surface:'cup',declaredRole:['free','handleRight','handleLeft'][i],analysisState:'complete',userObservations:[],physicalMeasurementsStatus:'available',physicalMeasurementScope:'wholeImageContentNotUserRegion',globalPhysicalMeasurements:{residuePixelCount:30,contentResidueRatio:.2,componentCount:3,candidateRelationCount:1,selectedRelationCount:0}}))});
const text=('Belki bu dağılım sana biraz sakinlik ve düşünmek için bir alan çağrıştırıyor. ').repeat(22);
const response=()=>new Response(JSON.stringify({choices:[{message:{content:text},finish_reason:'stop'}]}));
async function fixture(t,fetchImpl=async()=>response(),options={}) {
  const keys=Array.from({length:12},(_,i)=>`tester_${i}_${'x'.repeat(35)}`);
  const testers=keys.map((token,i)=>({id:`t${i}`,hash:createHash('sha256').update(token).digest('hex')}));
  const config={models:{atlas:{baseUrl:'http://127.0.0.1:1234/v1',model:'qwen3-14b',noThink:true}}};
  const server=createGateway({config:()=>config,tokens:()=>testers,fetchImpl,...options});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  t.after(()=>new Promise(r=>{server.closeAllConnections();server.close(r);}));
  const base=`http://127.0.0.1:${server.address().port}/api/ai/v1`;
  const request=(i,path='',method='GET',body,id=`request-${i}-${'a'.repeat(18)}`)=>fetch(base+path,{method,headers:{Authorization:`Bearer ${keys[i]}`,'Content-Type':'application/json','Idempotency-Key':id},...(body?{body:JSON.stringify(body)}:{})});
  const submit=i=>request(i,'/jobs','POST',{context:context(),modelAlias:'atlas',promptVersion:prompt.version});
  return {request,submit,testers,config};
}
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function finished(f,i,id){for(let n=0;n<100;n++){const j=await(await f.request(i,`/jobs/${id}`)).json();if(['completed','failed','cancelled'].includes(j.state))return j;await wait(10);}throw new Error('unfinished');}

test('strict context rejects private fields, pending, empty, invalid geometry and metrics',()=>{
  assert.equal(validateContext(context()).photos.length,3);
  for(const mutate of [c=>c.sessionId='private',c=>c.photos[0].path='private.jpg',c=>c.status='empty',c=>c.photos[0].analysisState='pending',c=>c.photos[0].globalPhysicalMeasurements.selectedRelationCount=99,c=>c.photos[0].userObservations.push({origin:'userObservation',symbolName:'Kuş',box:{x:1,y:0,width:.2,height:.1}})]){const c=context();mutate(c);assert.throws(()=>validateContext(c));}
});
test('quality rejects reasoning, certainty and truncated responses',()=>{
  assert.equal(qualityError(text,'stop'),null);
  assert.ok(qualityError(text,'length'));assert.ok(qualityError('<think>'+text,'stop'));assert.ok(qualityError(text+' Kesinlikle kazanacaksın.','stop'));
});
test('shared language cases distinguish reporting from visual evidence',()=>{
  const fixtures=JSON.parse(readFileSync(new URL('./fixtures/fortune-quality-cases.json',import.meta.url)));
  const padding=fixtures.paddingSentence.repeat(fixtures.paddingRepeat);
  for(const c of fixtures.cases){
    const input=context();
    input.photos[0].userObservations=c.symbols.map(symbolName=>({origin:'userObservation',symbolName,box:{x:.1,y:.1,width:.2,height:.2}}));
    assert.equal(qualityError(padding+c.text,'stop',validateContext(input)),c.error,c.id);
  }
});
test('shared prompt version and byte hash include the language repair instructions',()=>{
  assert.equal(prompt.version,'atlas-fortune-prompt-v6');
  assert.equal(promptHash,createHash('sha256').update(promptBytes).digest('hex'));
  assert.match(messages(context())[0].content,/You have not seen any photo\./);
  assert.ok(!messages(context())[1].content.includes('bunu açıkça söyle'));
  for(const reason of ['unsupported_absence_claim','unsupported_symbol_claim']) assert.ok(messages(context(),false,true,reason)[1].content.includes(prompt.repairHints[reason]));
});
test('ten isolated testers queue on one worker, retries are idempotent',async t=>{
  let unblock;const gate=new Promise(r=>unblock=r);let calls=0,active=0,max=0;
  const f=await fixture(t,async(url,opts)=>{calls++;active++;max=Math.max(max,active);await gate;await wait(4);assert.equal(JSON.parse(opts.body).stream,false);active--;return response();});
  const jobs=[];
  for(let i=0;i<10;i++){const r=await f.submit(i);assert.equal(r.status,202);jobs.push((await r.json()).jobId);}
  assert.equal((await f.submit(10)).status,429);
  const duplicate=await(await f.submit(0)).json();assert.equal(duplicate.jobId,jobs[0]);
  assert.equal((await f.request(1,`/jobs/${jobs[0]}`)).status,404);
  assert.equal((await f.request(1,`/jobs/${jobs[0]}`,'DELETE')).status,404);
  const changed=context();changed.photos[0].globalPhysicalMeasurements.residuePixelCount++;
  assert.equal((await f.request(0,'/jobs','POST',{context:changed,modelAlias:'atlas',promptVersion:prompt.version})).status,409);
  unblock();
  for(let i=0;i<10;i++)assert.equal((await finished(f,i,jobs[i])).state,'completed');
  assert.equal(calls,10);assert.equal(max,1);
  f.testers[0].revoked=true;assert.equal((await f.request(0,'/capabilities')).status,401);
});
test('active cancellation retains GPU slot until upstream completes',async t=>{
  let unblock;const gate=new Promise(r=>unblock=r);let calls=0;
  const f=await fixture(t,async()=>{calls++;if(calls===1)await gate;return response();});
  const one=await(await f.submit(0)).json(),two=await(await f.submit(1)).json();
  await f.request(0,`/jobs/${one.jobId}`,'DELETE');await wait(20);assert.equal(calls,1);
  assert.equal((await(await f.request(1,`/jobs/${two.jobId}`)).json()).state,'queued');
  unblock();assert.equal((await finished(f,1,two.jobId)).state,'completed');assert.equal((await finished(f,0,one.jobId)).state,'cancelled');
});
test('unknown upstream state pauses new generation rather than overlapping GPU work',async t=>{
  const f=await fixture(t,async()=>{throw new Error('socket reset');});
  const job=await(await f.submit(0)).json();assert.equal((await finished(f,0,job.jobId)).error,'upstream_state_unknown');
  assert.equal((await f.submit(1)).status,503);
});
test('at most one quality repair, failed story never returned as a result',async t=>{
  let calls=0;
  const f=await fixture(t,async()=>{calls++;return new Response(JSON.stringify({choices:[{message:{content:'kesinlikle'},finish_reason:'stop'}]}));});
  const job=await(await f.submit(0)).json();const result=await finished(f,0,job.jobId);
  assert.equal(result.state,'failed');assert.equal(result.result,null);assert.equal(calls,2);
});
for(const id of ['unreported-bird-symbol','no-symbols-in-cup','measurements-and-spelled-percentage']) {
  test(`gateway repairs ${id} using the same context`,async t=>{
    const fixtures=JSON.parse(readFileSync(new URL('./fixtures/fortune-quality-cases.json',import.meta.url)));
    const c=fixtures.cases.find(c=>c.id===id), bad=fixtures.paddingSentence.repeat(fixtures.paddingRepeat)+c.text;
    let calls=0;
    const f=await fixture(t,async(url,opts)=>{
      calls++;
      const wire=JSON.parse(opts.body);
      assert.ok(wire.messages.at(-1).content.includes(JSON.stringify(context())));
      if(calls===2) assert.ok(wire.messages.at(-1).content.includes(prompt.repairHints[c.error]));
      return new Response(JSON.stringify({choices:[{message:{content:calls===1?bad:text},finish_reason:'stop'}]}));
    });
    const job=await(await f.submit(0)).json(), result=await finished(f,0,job.jobId);
    assert.equal(result.state,'completed');assert.equal(result.result.attempts,2);assert.equal(calls,2);
    assert.equal(result.result.text,text.trim());assert.equal(result.result.promptVersion,prompt.version);assert.equal(result.result.promptHash,promptHash);
  });
}
test('gateway rejects unreported symbols twice but accepts the same reported symbol',async t=>{
  let calls=0;
  const story=text+' Paylaştığın Kuş sembolü haberleşmeyi çağrıştırabilir.';
  const f=await fixture(t,async()=>{calls++;return new Response(JSON.stringify({choices:[{message:{content:story},finish_reason:'stop'}]}));});
  const rejected=await(await f.submit(0)).json(), failure=await finished(f,0,rejected.jobId);
  assert.equal(failure.state,'failed');assert.equal(failure.error,'quality_rejected');assert.equal(failure.result,null);assert.equal(calls,2);
  const input=context();input.photos[0].userObservations=[{origin:'userObservation',symbolName:'Kuş',box:{x:.1,y:.1,width:.2,height:.2}}];
  const accepted=await(await f.request(1,'/jobs','POST',{context:input,modelAlias:'atlas',promptVersion:prompt.version})).json();
  const result=await finished(f,1,accepted.jobId);assert.equal(result.state,'completed');assert.equal(result.result.attempts,1);assert.equal(calls,3);
});
test('gateway advertises current prompt identity and rejects stale versions before generation',async t=>{
  let calls=0;const f=await fixture(t,async()=>{calls++;return response();});
  const capabilities=await(await f.request(0,'/capabilities')).json();
  assert.equal(capabilities.promptVersion,prompt.version);assert.equal(capabilities.promptHash,promptHash);
  const rejected=await f.request(0,'/jobs','POST',{context:context(),modelAlias:'atlas',promptVersion:'atlas-fortune-prompt-v1'});
  assert.equal(rejected.status,400);assert.equal(calls,0);
});
test('timeout marks failure but keeps slot until response drains',async t=>{
  let unblock;const gate=new Promise(r=>unblock=r);let calls=0;
  const f=await fixture(t,async()=>{calls++;if(calls===1)await gate;return response();},{runtimeMs:20});
  const one=await(await f.submit(0)).json();const two=await(await f.submit(1)).json();
  await wait(35);assert.equal((await finished(f,0,one.jobId)).state,'failed');assert.equal(calls,1);
  unblock();assert.equal((await finished(f,1,two.jobId)).state,'completed');
});


test('photo-set cardinality accepts 1-3 cups and optional saucer only',()=>{
  for(let cups=0;cups<=4;cups++) for(let saucers=0;saucers<=2;saucers++){
    const c=context(), template=c.photos[0];
    c.photos=Array.from({length:cups+saucers},(_,i)=>({...template,photoNumber:i+1,surface:i<cups?'cup':'saucer',declaredRole:null}));
    if(cups>=1&&cups<=3&&saucers<=1) assert.doesNotThrow(()=>validateContext(c));
    else assert.throws(()=>validateContext(c));
  }
  const c=context();c.photos[0].surface='saucer';assert.throws(()=>validateContext(c));
});

function richContext() {
  const c=context();c.version='atlas-fortune-context-v2';
  for(const p of c.photos) p.regionalSummary={version:'atlas-regional-summary-v1',bands:[{position:'top',density:.1},{position:'middle',density:.2},{position:'bottom',density:.6}],components:[],relations:[]};
  c.narrative={version:'atlas-narrative-v1',topic:'rest',arc:'notice-explore-choice',closing:'gentle-question',maxPhysicalDetails:3};
  return c;
}
test('shared regional grounding cases and v2 privacy boundary',()=>{
  const cases=JSON.parse(readFileSync(new URL('./fixtures/regional-quality-cases.json',import.meta.url)));
  for(const row of cases) {
    const text=Array.from({length:4},(_,i)=>(i===0?row.text:'Belki düşünmek sana iyi gelebilir.')+' '+Array(66).fill('düşünce').join(' ')).join('\n\n');
    assert.equal(qualityError(text,'stop',validateContext(richContext())),row.error,row.id);
  }
  const bad=richContext();bad.photos[0].regionalSummary.path='private';assert.throws(()=>validateContext(bad));
  const dangling=richContext();dangling.photos[0].regionalSummary.relations=[{from:1,to:2,distance:.1}];assert.throws(()=>validateContext(dangling));
});
test('client repetition repair is owner-only, idempotent and bounded to one repair',async t=>{
  let calls=0;const f=await fixture(t,async()=>{calls++;return response();});
  const {jobId}=await(await f.submit(0)).json();await finished(f,0,jobId);
  assert.equal((await f.request(1,`/jobs/${jobId}`,'POST',{reason:'repetition'})).status,404);
  assert.equal((await f.request(0,`/jobs/${jobId}`,'POST',{reason:'repetition'})).status,202);
  const result=await finished(f,0,jobId);assert.equal(result.result.attempts,2);
  await f.request(0,`/jobs/${jobId}`,'POST',{reason:'repetition'});await wait(20);assert.equal(calls,2);
});
