// Opt-in real inference check. Synthetic text only, never phone records.
import {readFileSync,writeFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {prompt} from '../contract.mjs';
const [base,credentialsFile,outputFile,countArg='1']=process.argv.slice(2);
if(!base||!credentialsFile||!outputFile)throw new Error('Usage: node tool/smoke.mjs BASE PRIVATE_CREDENTIALS REPORT [COUNT]');
const credentials=JSON.parse(readFileSync(credentialsFile,'utf8')).slice(0,Number(countArg));
const context={version:'atlas-fortune-context-v1',language:'tr',status:'ready',photos:[0,1,2].map(i=>({photoNumber:i+1,surface:'cup',declaredRole:['free','handleRight','handleLeft'][i],analysisState:'complete',userObservations:i===0?[{origin:'userObservation',symbolName:'Kuş',box:{x:.3,y:.2,width:.15,height:.15}}]:[],physicalMeasurementsStatus:'available',physicalMeasurementScope:'wholeImageContentNotUserRegion',globalPhysicalMeasurements:{residuePixelCount:400,contentResidueRatio:.24,componentCount:5,candidateRelationCount:3,selectedRelationCount:1}}))};
const outcomes=await Promise.all(credentials.map(async c=>{
  const headers={Authorization:`Bearer ${c.token}`,'Content-Type':'application/json','Idempotency-Key':randomUUID()};
  const start=Date.now();
  const response=await fetch(base+'/api/ai/v1/jobs',{method:'POST',headers,body:JSON.stringify({context,modelAlias:'atlas',promptVersion:prompt.version})});
  if(response.status!==202)return {tester:c.id,status:response.status};
  const job=await response.json();
  for(let i=0;i<700;i++){
    const state=await(await fetch(base+'/api/ai/v1/jobs/'+job.jobId,{headers})).json();
    if(['completed','failed','cancelled'].includes(state.state))return {tester:c.id,state:state.state,error:state.error,elapsedMs:Date.now()-start,result:state.result};
    await new Promise(r=>setTimeout(r,3000));
  }
  return {tester:c.id,state:'poll_timeout'};
}));
writeFileSync(outputFile,JSON.stringify({at:new Date().toISOString(),synthetic:true,outcomes},null,2));
console.log(JSON.stringify(outcomes.map(({result,...r})=>({...r,words:result?.text?.split(/\s+/u).length,durationMs:result?.durationMs,attempts:result?.attempts}))));
if(outcomes.some(r=>r.state!=='completed'))process.exitCode=1;
