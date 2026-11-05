
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createGateway} from '../server.mjs';
import {validateContext, messages, prompt, shortFortunePrompt, shortFortuneContextVersion} from '../contract.mjs';

const fixture=JSON.parse(readFileSync(new URL('./fixtures/fortune-v4-cases.json', import.meta.url)));
test('gateway advertises both versions and repairs a short visual claim without raising its length floor',async t=>{
  const context={...structuredClone(fixture.context),version:shortFortuneContextVersion,readingFocus:'love',
    creativeSymbol:{catalogVersion:'atlas-creative-symbols-v1',origin:'creativeSelectionNotVisualDetection',symbolId:'bird',symbolName:'Kuş'},
    personalization:{addressName:'Deniz',age:37,maritalStatus:'married'}};
  validateContext(context);
  const body=JSON.parse(messages(context).at(-1).content.split('\n').at(-1));
  assert.equal(body.medeni_durum,'evli');
  assert.equal(body.rastgele_sembol,'Kuş');
  assert.ok(!Object.hasOwn(body,'physical_background'));

  const token='short_test_'+ 'a'.repeat(40);
  const text=Array.from({length:74},()=>'gündelik').join(' ')+' Eşinle.';
  let calls=0;
  const server=createGateway({config:()=>({models:{atlas:{baseUrl:'https://api.moonshot.ai/v1',model:'kimi-k3.1-pro',noThink:true}}}),
    tokens:()=>[{id:'synthetic',hash:createHash('sha256').update(token).digest('hex')}],fetchImpl:async(_url,options)=>{
      calls++;
      const upstream=JSON.parse(options.body);
      assert.deepEqual(upstream.thinking,{type:'disabled'});
      assert.equal(upstream.messages.length,2);
      if(calls===2) assert.match(upstream.messages.at(-1).content,/Fincanda sembol gördüğünü söyleme/);
      const content=calls===1 ? text+' Fincanında beliren kuş.' : text;
      return new Response(JSON.stringify({choices:[{message:{content},finish_reason:'stop'}]}));
    }});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  t.after(()=>new Promise(resolve=>{server.closeAllConnections();server.close(resolve);}));
  const base=`http://127.0.0.1:${server.address().port}/api/ai/v1`;
  const request=(path,body)=>fetch(base+path,{method:body?'POST':'GET',headers:{Authorization:`Bearer ${token}`,
    'Content-Type':'application/json','Idempotency-Key':'short-job-'+ 'b'.repeat(30)},...(body?{body:JSON.stringify(body)}:{})});
  const capabilities=await(await request('/capabilities')).json();
  assert.equal(capabilities.promptVersion,prompt.version);
  assert.equal(capabilities.shortFortune.promptVersion,shortFortunePrompt.version);
  const submission=await request('/jobs',{context,modelAlias:'atlas',promptVersion:shortFortunePrompt.version});
  assert.equal(submission.status,202);
  const {jobId}=await submission.json();
  let job;
  for(let i=0;i<100;i++) {
    job=await(await request(`/jobs/${jobId}`)).json();
    if(['completed','failed'].includes(job.state))break;
    await new Promise(resolve=>setTimeout(resolve,5));
  }
  assert.equal(job.state,'completed');
  assert.equal(calls,2);
  assert.equal(job.result.promptHash,capabilities.shortFortune.promptHash);
  assert.deepEqual(job.result.qualityWarnings,['length']);
});
