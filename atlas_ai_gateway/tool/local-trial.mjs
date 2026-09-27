// Temporary loopback-only trial. No accounts/configuration/keys persist.
import {createHash,randomBytes,randomUUID} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';
import {createGateway} from '../server.mjs';
import {prompt,promptHash,qualityError} from '../contract.mjs';
const count=Number(process.argv[2]??1);
if(!Number.isInteger(count)||count<1||count>10)throw new Error('Choose 1..10 synthetic testers');
const tokens=Array.from({length:count},(_,i)=>({id:`synthetic-${i}`,token:randomBytes(32).toString('base64url')}));
const testers=tokens.map(t=>({id:t.id,hash:createHash('sha256').update(t.token).digest('hex')}));
const diagnostics=[];
const server=createGateway({config:()=>({models:{atlas:{baseUrl:'http://127.0.0.1:1234/v1',model:'qwen3-14b',noThink:true}}}),tokens:()=>testers,fetchImpl:async (...args)=>{
  const response=await fetch(...args);
  const data=await response.clone().json();
  const choice=data.choices?.[0];
  diagnostics.push({text:choice?.message?.content,quality:qualityError(choice?.message?.content,choice?.finish_reason),finishReason:choice?.finish_reason,usage:data.usage});
  return response;
}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const base=`http://127.0.0.1:${server.address().port}`;
const context={version:'atlas-fortune-context-v1',language:'tr',status:'ready',photos:[0,1,2].map(i=>({photoNumber:i+1,surface:'cup',declaredRole:['free','handleRight','handleLeft'][i],analysisState:'complete',userObservations:[],physicalMeasurementsStatus:'available',physicalMeasurementScope:'wholeImageContentNotUserRegion',globalPhysicalMeasurements:{residuePixelCount:400,contentResidueRatio:.24,componentCount:5,candidateRelationCount:3,selectedRelationCount:1}}))};
try {
  const outcomes=await Promise.all(tokens.map(async t=>{
    const headers={Authorization:`Bearer ${t.token}`,'Content-Type':'application/json','Idempotency-Key':randomUUID()};
    const start=Date.now();
    const created=await fetch(base+'/api/ai/v1/jobs',{method:'POST',headers,body:JSON.stringify({context,modelAlias:'atlas',promptVersion:prompt.version})});
    const job=await created.json();
    if(created.status!==202)return {id:t.id,status:created.status};
    for(let i=0;i<700;i++) {
      const state=await(await fetch(base+'/api/ai/v1/jobs/'+job.jobId,{headers})).json();
      if(['completed','failed','cancelled'].includes(state.state)) {
        const outcome={id:t.id,state:state.state,error:state.error,elapsedMs:Date.now()-start,result:state.result};
        console.log(JSON.stringify({id:t.id,state:state.state,elapsedMs:outcome.elapsedMs,durationMs:state.result?.durationMs,words:state.result?.text?.split(/\s+/u).length,attempts:state.result?.attempts}));
        return outcome;
      }
      await new Promise(r=>setTimeout(r,1500));
    }
    return {id:t.id,state:'timeout'};
  }));
  mkdirSync('build',{recursive:true});
  writeFileSync(`build/local-trial-${count}.json`,JSON.stringify({at:new Date().toISOString(),synthetic:true,promptHash,count,outcomes,diagnostics},null,2));
  console.log(JSON.stringify({qualityChecks:diagnostics.map(d=>d.quality)}));
  if(outcomes.some(r=>r.state!=='completed'))process.exitCode=1;
} finally {server.closeAllConnections();await new Promise(r=>server.close(r));}
