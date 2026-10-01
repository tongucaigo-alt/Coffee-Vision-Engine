// Local-only, sequential paired benchmark. Never reads images or credentials.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { execFileSync } from 'node:child_process';
import { createHash, randomInt } from 'node:crypto';
import { validateContext, physicalCues, qualityError, prompt } from '../contract.mjs';

const [inputs, output, model = 'atlas-local-test', count = '12'] = process.argv.slice(2);
if (!inputs || !output || !/^([1-9]|1[0-2])$/.test(count)) throw new Error('Usage: compare-local.mjs inputs.json output.json [model] [1-12]');
const baseline = JSON.parse(execFileSync('git', ['show', '8caa6ba:atlas_contribution_app/assets/fortune-prompt-v1.json'], {encoding:'utf8'}));
const source = JSON.parse(await readFile(inputs,'utf8')).rows.slice(0,Number(count));
for (const sample of source) validateContext(sample.context);
const report = {model, temperature:0.6, endpoint:'loopback LM Studio', status:'running', humanPreference:'pending', rows:[]};
const filename = resolve(output);
await mkdir(dirname(filename),{recursive:true});
const persist = () => writeFile(filename,JSON.stringify(report,null,2));
let stop = false;
for (const [index,sample] of source.entries()) {
  const row = {case:sample.case, context:sample.context, controlledTestLabels:sample.controlledTestLabels, order:randomInt(2)?[1,0]:[0,1], responses:[]};
  report.rows.push(row);
  for (const variant of index%2?[1,0]:[0,1]) {
    const selected = [baseline,prompt][variant];
    const started = Date.now();
    const result = {variant,promptVersion:selected.version,promptHash:createHash('sha256').update(JSON.stringify(selected)).digest('hex')};
    try {
      const response = await fetch('http://127.0.0.1:1234/v1/chat/completions',{
        method:'POST',redirect:'error',signal:AbortSignal.timeout(180000),
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({model,stream:false,temperature:0.6,max_tokens:selected.maxTokens,
          messages:[{role:'system',content:selected.system},{role:'user',content:selected.userPrefix+JSON.stringify(sample.context)+'\nİzinli kısa fiziksel ifadeler: '+JSON.stringify(physicalCues(sample.context))+'. Bu ifadeler dışında fiziksel sahne betimleme.\n/no_think'}]})});
      if (!response.ok) { result.error='http_'+response.status; stop=true; }
      else {
        const data = await response.json(), choice=data.choices?.[0];
        result.text=choice?.message?.content??'';
        result.finishReason=choice?.finish_reason??null;
        result.words=result.text.trim().split(/\s+/u).filter(Boolean).length;
        result.qualityError=qualityError(result.text,result.finishReason,sample.context);
        result.deliveryError=qualityError(result.text,result.finishReason,sample.context,false);
        result.reasoningReturned=!!choice?.message?.reasoning_content;
      }
    } catch (error) {
      result.error=error.name==='TimeoutError'?'timeout':'transport_error'; stop=true;
    }
    result.elapsedMs=Date.now()-started; row.responses.push(result); await persist();
    console.log(JSON.stringify({case:sample.case,variant,words:result.words,error:result.error??result.deliveryError,elapsedMs:result.elapsedMs}));
    // A failed socket does not prove inference has stopped. Never overlap jobs.
    if (stop) break;
  }
  if (stop) break;
}
report.status=stop?'interrupted':'generated'; await persist();
const blind = ['# Kör fal karşılaştırması','Her sette A/B/eşit/ikisi de uygun değil seçin. Sembollerle bağ, farklılık, somutluk ve anlatı bütünlüğünü 1–5 puanlayın. Fal bilmek gerekmez. Eksik yanıtları başarısız olarak kaydedin.'];
for (const row of report.rows) {
  blind.push(`\n## Set ${row.case}`);
  for (const [index,variant] of row.order.entries()) {
    const answer=row.responses.find(r=>r.variant===variant);
    blind.push(`\n### ${index===0?'A':'B'}\n${answer?.text || '[Yanıt oluşmadı]'}\n`);
  }
}
await writeFile(filename.replace(/\.json$/,'')+'-blind.md',blind.join('\n'));
