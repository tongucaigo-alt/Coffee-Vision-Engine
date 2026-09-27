import http from 'node:http';
import { readFileSync } from 'node:fs';
import { createHash, randomUUID } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { exact, validateContext, messages, qualityError, prompt, promptHash } from './contract.mjs';

const hash = value => createHash('sha256').update(value).digest('hex');
export function createGateway({config, tokens, fetchImpl = fetch, runtimeMs = 180000, queueMs = 1800000, retentionMs = 1800000}) {
  const jobs = new Map(), dedupe = new Map();
  const instance = randomUUID();
  let active = null, stopping = false, stalled = false;
  const models = () => config().models;
  function end(job, state, error) {
    if (['completed','failed','cancelled'].includes(job.state)) return;
    job.state = state; job.error = error; job.endedAt = Date.now();
  }
  async function pump() {
    if (active || stopping || stalled) return;
    const job = [...jobs.values()].find(j => j.state === 'queued');
    if (!job) return;
    if (Date.now()-job.createdAt > queueMs) { end(job,'failed','queue_timeout'); queueMicrotask(pump); return; }
    active = job; job.state = 'running'; job.startedAt = Date.now();
    const remainingMs=runtimeMs-(job.productionMs??0);
    if(remainingMs<=0) { end(job,'failed','generation_timeout'); active=null; queueMicrotask(pump); return; }
    // Do not abort fetch and assume that the GPU has stopped. Retain this slot
    // until the upstream response drains; a network error pauses the worker.
    const deadline = setTimeout(() => end(job,'failed','generation_timeout'), remainingMs);
    try {
      let lastError = job.repairReason??null;
      for (let attempt=job.attempts??0; attempt<2 && job.state === 'running'; attempt++) {
        job.attempts=attempt+1; job.phase=attempt===0?'generating':'repairing';
        const upstream = new URL(job.model.baseUrl.replace(/\/$/,'')+'/chat/completions');
        const response = await fetchImpl(upstream, {
          method:'POST', redirect:'error',
          headers:{'Content-Type':'application/json', ...(job.model.apiKey ? {Authorization:`Bearer ${job.model.apiKey}`} : {})},
          body:JSON.stringify({model:job.model.model, messages:messages(job.context,job.model.noThink,attempt===1,lastError,job.previousReply), stream:false, temperature:prompt.temperature,max_tokens:prompt.maxTokens}),
        });
        const raw = await response.text();
        if (job.state !== 'running') break;
        if (!response.ok) { end(job,'failed','upstream_unavailable'); break; }
        if (raw.length > 256000) { end(job,'failed','invalid_response'); break; }
        let data;
        try { data = JSON.parse(raw); } catch { end(job,'failed','invalid_response'); break; }
        const choice = data.choices?.[0];
        const text = choice?.message?.content;
        job.previousReply=typeof text==='string'?text.slice(0,12000):null;
        const error = qualityError(text,choice?.finish_reason,job.context);
        lastError = error;
        if (!error) {
          job.result = {text:text.trim(),model:job.model.model,modelAlias:job.alias,promptVersion:prompt.version,promptHash,temperature:prompt.temperature,maxTokens:prompt.maxTokens,noThink:!!job.model.noThink,durationMs:(job.productionMs??0)+Date.now()-job.startedAt,attempts:attempt+1,reasoningTokens:data.usage?.completion_tokens_details?.reasoning_tokens??null,reasoningReturned:!!choice?.message?.reasoning_content};
          end(job,'completed');
        } else if (attempt === 1) end(job,'failed','quality_rejected');
      }
    } catch {
      // An interrupted socket is not proof that a remote generation stopped.
      stalled = true; end(job,'failed','upstream_state_unknown');
      for (const pending of jobs.values()) if (pending.state === 'queued') end(pending,'failed','upstream_state_unknown');
    } finally {
      job.productionMs=(job.productionMs??0)+Date.now()-job.startedAt;
      clearTimeout(deadline); active = null; queueMicrotask(pump);
    }
  }
  const maintenance = setInterval(() => {
    for (const [id,j] of jobs) {
      if (j.state === 'queued' && Date.now()-j.createdAt > queueMs) end(j,'failed','queue_timeout');
      if (j !== active && j.endedAt && Date.now()-j.endedAt > retentionMs) { jobs.delete(id); dedupe.delete(j.key); }
    }
    void pump();
  },1000).unref();
  const reply = (res, status, data, extra={}) => { res.writeHead(status, {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store',...extra}); res.end(JSON.stringify(data)); };
  const server = http.createServer(async (req,res) => {
    try {
      const token = req.headers.authorization?.match(/^Bearer ([A-Za-z0-9_-]{32,128})$/)?.[1];
      const owner = token ? tokens().find(t => !t.revoked && t.hash === hash(token))?.id : null;
      if (!owner) return reply(res,401,{error:'unauthorized'});
      const url = new URL(req.url,'http://localhost');
      const route = url.pathname;
      if (req.method === 'GET' && route === '/api/ai/v1/capabilities') return reply(res,200,{apiVersion:1,contextVersions:['atlas-fortune-context-v1','atlas-fortune-context-v2'],clientRepetitionRepair:true,serverInstanceId:instance,promptVersion:prompt.version,promptHash,models:Object.keys(models()),available:!stalled,capacity:10});
      if (req.method === 'POST' && route === '/api/ai/v1/jobs') {
        if (stalled) return reply(res,503,{error:'upstream_state_unknown'});
        const chunks=[]; let size=0;
        for await (const chunk of req) { size+=chunk.length; if(size>32768) return reply(res,413,{error:'too_large'}); chunks.push(chunk); }
        let body;
        try {
          body=JSON.parse(Buffer.concat(chunks).toString('utf8'));
          exact(body,['context','modelAlias','promptVersion']); validateContext(body.context);
          if(body.promptVersion!==prompt.version) throw new Error();
        } catch { return reply(res,400,{error:'invalid_context_or_version'}); }
        const idempotency = req.headers['idempotency-key'];
        if(typeof idempotency!=='string' || !/^[a-zA-Z0-9-]{16,80}$/.test(idempotency)) return reply(res,400,{error:'idempotency_required'});
        const key = owner+':'+idempotency, digest=hash(JSON.stringify(body));
        const existing=dedupe.get(key);
        if(existing) return existing.digest === digest ? reply(res,202,{jobId:existing.id,serverInstanceId:instance,pollAfterMs:3000}) : reply(res,409,{error:'idempotency_conflict'});
        const availableModels=models();
        const model=typeof body.modelAlias==='string' && Object.hasOwn(availableModels,body.modelAlias) ? availableModels[body.modelAlias] : null;
        if(!model) return reply(res,400,{error:'unknown_model'});
        const open=[...jobs.values()].filter(j=>j.state==='queued'||j.state==='running'||j===active);
        if(open.length>=10 || open.some(j=>j.owner===owner)) return reply(res,429,{error:'busy'},{'Retry-After':'5'});
        const id=randomUUID();
        const job={id,key,owner,digest,context:body.context,alias:body.modelAlias,model:{...model},state:'queued',createdAt:Date.now()};
        jobs.set(id,job); dedupe.set(key,job);
        reply(res,202,{jobId:id,serverInstanceId:instance,pollAfterMs:3000}); void pump(); return;
      }
      const id=route.match(/^\/api\/ai\/v1\/jobs\/([a-f0-9-]{36})$/)?.[1];
      const job=id?jobs.get(id):null;
      if(!job || job.owner!==owner) return reply(res,404,{error:'not_found'});
      if(req.method==='POST') {
        const chunks=[]; let size=0;
        for await(const chunk of req) { size+=chunk.length; if(size>128) return reply(res,413,{error:'too_large'}); chunks.push(chunk); }
        try { const body=JSON.parse(Buffer.concat(chunks).toString('utf8')); exact(body,['reason']); if(body.reason!=='repetition') throw new Error(); }
        catch { return reply(res,400,{error:'invalid_repair'}); }
        if(job.repairRequested) return reply(res,202,{jobId:job.id,serverInstanceId:instance});
        if(job.state!=='completed' || job.attempts!==1 || job===active) return reply(res,409,{error:'repair_unavailable'});
        const open=[...jobs.values()].filter(j=>j.state==='queued'||j.state==='running'||j===active);
        if(stalled || open.length>=10 || open.some(j=>j.owner===owner)) return reply(res,429,{error:'busy'});
        job.repairRequested=true; job.repairReason='repetition'; job.result=null; job.endedAt=null; job.state='queued';
        reply(res,202,{jobId:job.id,serverInstanceId:instance}); void pump(); return;
      }
      if(req.method==='DELETE') { end(job,'cancelled'); return reply(res,200,{state:job.state}); }
      if(req.method==='GET') {
        const queue=[...jobs.values()].filter(j=>j.state==='queued');
        return reply(res,200,{jobId:job.id,serverInstanceId:instance,state:job.state,phase:job.phase??null,queuePosition:job.state==='queued'?queue.indexOf(job)+1:0,result:job.result??null,error:job.error??null});
      }
      reply(res,405,{error:'method_not_allowed'});
    } catch { if(!res.headersSent) reply(res,500,{error:'service_error'}); else res.end(); }
  });
  server.requestTimeout=15000; server.headersTimeout=10000;
  server.on('close',()=>{stopping=true;clearInterval(maintenance);});
  return server;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const filename=process.env.ATLAS_AI_CONFIG;
  if(!filename) throw new Error('Set ATLAS_AI_CONFIG to the private configuration file.');
  const load=()=>JSON.parse(readFileSync(filename,'utf8'));
  const initial=load();
  for(const model of Object.values(initial.models)) {
    const u=new URL(model.baseUrl);
    if(u.protocol!=='https:' && !(u.protocol==='http:' && ['localhost','127.0.0.1','[::1]'].includes(u.hostname))) throw new Error('Upstream must be loopback HTTP or HTTPS.');
  }
  const server=createGateway({config:load,tokens:()=>load().testers});
  server.listen(initial.port??8787,'127.0.0.1',()=>console.log('Atlas AI gateway listening on loopback. No request contents are logged.'));
}
