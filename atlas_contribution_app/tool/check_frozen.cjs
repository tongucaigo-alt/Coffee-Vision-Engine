const {execFileSync}=require('node:child_process');
const {readFileSync}=require('node:fs');
const {createHash}=require('node:crypto');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const baseline='86011b4b33df787d08a9202565649bf880361fbc';
const git=(args)=>execFileSync('git',args,{cwd:root,maxBuffer:64*1024*1024});
const files=git(['ls-files','-z']).toString().split('\0').filter(f=>/^(coffee_[^/]+\/lib\/|atlas_canonical_json\/lib\/|docs\/)/.test(f));
const hash=b=>createHash('sha256').update(b).digest('hex');
const mismatches=[],inventory=[];
for(const file of files) {
  const actual=hash(readFileSync(path.join(root,file)));
  const expected=hash(git(['cat-file','--filters',`${baseline}:${file}`]));
  if(actual!==expected)mismatches.push(file);
  inventory.push(`${file}\0${actual}`);
}
console.log(JSON.stringify({baseline,checked:files.length,mismatches,inventorySha256:hash(Buffer.from(inventory.join('\n')))}));
if(mismatches.length)process.exitCode=1;
