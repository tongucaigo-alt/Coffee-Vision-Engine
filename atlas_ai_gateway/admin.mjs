import {readFileSync,writeFileSync,existsSync,mkdirSync} from 'node:fs';
import {dirname} from 'node:path';
import {randomBytes,createHash} from 'node:crypto';
const [command,file,arg]=process.argv.slice(2);
if(!file || !['init','add','revoke'].includes(command)) throw new Error('Usage: node admin.mjs init|add|revoke PRIVATE_CONFIG [tester-id]');
if(command==='init') {
  if(existsSync(file)) throw new Error('Config already exists');
  mkdirSync(dirname(file),{recursive:true});
  writeFileSync(file,JSON.stringify({port:8787,models:{atlas:{baseUrl:'http://127.0.0.1:1234/v1',model:'qwen3-14b',noThink:true}},testers:[]},null,2),{mode:0o600,flag:'wx'});
} else {
  if(!/^[a-zA-Z0-9_-]{1,60}$/.test(arg??'')) throw new Error('Invalid tester id');
  const config=JSON.parse(readFileSync(file,'utf8'));
  if(command==='add') {
    if(config.testers.some(t=>t.id===arg)) throw new Error('Tester already exists');
    const token=randomBytes(32).toString('base64url');
    config.testers.push({id:arg,hash:createHash('sha256').update(token).digest('hex'),revoked:false});
    writeFileSync(file,JSON.stringify(config,null,2),{mode:0o600});
    console.log(token); // Deliberate one-time delivery to the operator, never server logs.
  } else {
    const tester=config.testers.find(t=>t.id===arg); if(!tester) throw new Error('Unknown tester');
    tester.revoked=true; writeFileSync(file,JSON.stringify(config,null,2),{mode:0o600});
  }
}
