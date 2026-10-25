// Test-only real HTTP server: no external model, credentials or personal data.
import { createHash } from 'node:crypto';
import { writeFile, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { createGateway } from '../../../atlas_ai_gateway/server.mjs';
import { reportStore } from '../../../atlas_ai_gateway/reports.mjs';
const mode=process.argv[3]??'success';let calls=0;
const token='s'.repeat(40);
const persist=reportStore(process.argv[2]);
const server=createGateway({config:()=>({models:{atlas:{baseUrl:'http://127.0.0.1:1',model:'synthetic',noThink:true}}}),
  tokens:()=>[{id:'synthetic-owner',hash:createHash('sha256').update(token).digest('hex')}],
  saveReport:mode==='report-failure'?async()=>{throw new Error('synthetic disk failure');}:persist,
  fetchImpl:async()=>{
    calls++;
    await mkdir(process.argv[2], {recursive:true});
    await writeFile(join(process.argv[2],'upstream-count.txt'),String(calls));
    if(mode==='slow')await new Promise(r=>setTimeout(r,800));
    const text=mode==='failure'||(mode==='retry'&&calls===1)?'':'Kartların çağrışımları sana düşünmek için sakin bir alan sunabilir. '.repeat(10);
    return new Response(JSON.stringify({choices:[{message:{content:text},finish_reason:'stop'}]}));
  }});
server.listen(0,'127.0.0.1',()=>console.log(JSON.stringify({port:server.address().port})));
