export const roles = ['top', 'handleRight', 'handleLeft'] as const;
export const labels = ['bird','heart','fish','snake','dog','butterfly','tree','horse','eye','crown','ring','road','mountain','moon','sun','anchor','house','humanFigure','airplane','flower'];
export type Json = Record<string, unknown>;
export async function readLimitedJson(request: Request): Promise<Json> {
  if(Number(request.headers.get('content-length'))>128000 || !request.body) throw Error('invalid_payload');
  const reader=request.body.getReader();const chunks:Uint8Array[]=[];let length=0;
  try {
    while(true) {
      const {done,value}=await reader.read();if(done)break;
      length+=value.length;if(length>128000){await reader.cancel();throw Error('invalid_payload');}
      chunks.push(value);
    }
    const bytes=new Uint8Array(length);let offset=0;
    for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
    const value=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));object(value);return value;
  } catch { throw Error('invalid_payload'); } finally { reader.releaseLock(); }
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const hash = /^sha256:[0-9a-f]{64}$/;
export function id(v: unknown): asserts v is string { if (typeof v !== 'string' || !uuid.test(v)) throw Error('invalid_payload'); }
function object(v: unknown): asserts v is Json { if (!v || typeof v !== 'object' || Array.isArray(v)) throw Error('invalid_payload'); }
function keys(v: Json, allowed: string[]) {
  if (Object.keys(v).length !== allowed.length || allowed.some(k => !(k in v))) throw Error('invalid_payload');
}
function timestamp(v: unknown) {
  if (typeof v !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z$/.test(v) ||
    !Number.isFinite(Date.parse(v)) || Date.parse(v)>Date.now()+300000 || Date.parse(v)<Date.now()-180*86400000) throw Error('invalid_payload');
  if (new Date(v).toISOString().slice(0,19)!==v.slice(0,19)) throw Error('invalid_payload');
}
export function validateDocument(value: unknown): Json {
  object(value);
  keys(value, ['id','rootId','groupId','revision','supersedesId','createdAt','consentedAt','consentVersion','labelVersion','photos','queued']);
  for (const k of ['id','rootId','groupId']) id(value[k]);
  if (!Number.isInteger(value.revision) || (value.revision as number)<1 || value.queued!==false ||
    value.consentVersion!=='contribution-consent-v1' || value.labelVersion!=='contribution-labels-v1') throw Error('invalid_payload');
  if (value.supersedesId!==null) id(value.supersedesId);
  timestamp(value.createdAt); timestamp(value.consentedAt);
  if (!Array.isArray(value.photos) || value.photos.length!==3) throw Error('invalid_payload');
  const regionIds = new Set();
  value.photos.forEach((p, i) => {
    object(p); keys(p,['role','localName','checksum','originalChecksum','width','height','byteLength','capturedAt','derivative','decision','regions']);
    if (p.role!==roles[i] || typeof p.localName!=='string' || !/^[a-zA-Z0-9_-]+\.jpg$/.test(p.localName) ||
      !hash.test(String(p.checksum)) || !hash.test(String(p.originalChecksum)) ||
      !Number.isInteger(p.width) || !Number.isInteger(p.height) ||
      (p.width as number)<1 || (p.height as number)<1 || (p.width as number)>2048 || (p.height as number)>2048 ||
      !Number.isInteger(p.byteLength) || (p.byteLength as number)<1 || (p.byteLength as number)>5242880 ||
      p.derivative!=='orientation-baked-jpeg-2048-q90-v1' ||
      !['marked','uncertain','notSeen','skipped'].includes(String(p.decision)) ||
      !Array.isArray(p.regions) || p.regions.length>10 || (p.decision==='marked')!==(p.regions.length>0)) throw Error('invalid_payload');
    timestamp(p.capturedAt);
    p.regions.forEach(r => {
      object(r); keys(r,['id','box','label']); id(r.id);
      if (regionIds.has(r.id)) throw Error('invalid_payload'); regionIds.add(r.id);
      if (r.label!==null && !labels.includes(String(r.label))) throw Error('invalid_payload');
      object(r.box); keys(r.box,['x','y','width','height']);
      const {x,y,width,height}=r.box as Record<string,number>;
      if (![x,y,width,height].every(v => typeof v==='number' && Number.isFinite(v)) ||
        x<0 || y<0 || width<=0 || height<=0 || x+width>1.000001 || y+height>1.000001) throw Error('invalid_payload');
    });
  });
  return value;
}
export function validateCorrections(value: unknown, doc: Json) {
  if (!Array.isArray(value) || value.length>30) throw Error('invalid_payload');
  const regions = (doc.photos as Json[]).flatMap(p => p.regions as Json[]).map(r => r.id);
  const seen = new Set();
  for (const c of value) {
    object(c); keys(c,['regionId','label']);
    if (!regions.includes(c.regionId) || seen.has(c.regionId) || (c.label!==null && !labels.includes(String(c.label)))) throw Error('invalid_payload');
    seen.add(c.regionId);
  }
}
export async function digest(bytes: Uint8Array) {
  return 'sha256:' + Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes as Uint8Array<ArrayBuffer>)))
    .map(n=>n.toString(16).padStart(2,'0')).join('');
}
// Parse JPEG dimensions while rejecting retained EXIF and comments.
export function jpegInfo(bytes: Uint8Array) {
  if (bytes[0]!==255 || bytes[1]!==216 || bytes.at(-2)!==255 || bytes.at(-1)!==217) throw Error('incomplete');
  let offset=2; let size: {width:number,height:number}|undefined;
  while (offset+4<bytes.length) {
    if (bytes[offset++]!==255) throw Error('incomplete');
    let marker=bytes[offset++]; while(marker===255) marker=bytes[offset++];
    if(marker===0xda) break;
    const length=(bytes[offset]<<8)|bytes[offset+1];
    if(length<2 || offset+length>bytes.length) throw Error('incomplete');
    if((marker>=0xe1 && marker<=0xef) || marker===0xfe) throw Error('incomplete');
    if([0xc0,0xc1,0xc2].includes(marker)) {
      if(length<8) throw Error('incomplete');
      size={height:(bytes[offset+3]<<8)|bytes[offset+4],width:(bytes[offset+5]<<8)|bytes[offset+6]};
    }
    offset+=length;
  }
  if(!size) throw Error('incomplete'); return size;
}
