import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

export const promptBytes = readFileSync(new URL('../atlas_contribution_app/assets/fortune-prompt-v1.json', import.meta.url));
export const prompt = JSON.parse(promptBytes);
export const promptHash = createHash('sha256').update(promptBytes).digest('hex');
const labels = new Set(['Kuş','Kalp','Balık','Yılan','Köpek','Kelebek','Ağaç','At','Göz','Taç','Yüzük','Yol','Dağ','Ay','Güneş','Çapa','Ev','İnsan Figürü','Uçak','Çiçek']);
export function exact(o, keys) {
  if (!o || typeof o !== 'object' || Array.isArray(o) || Object.keys(o).sort().join('|') !== [...keys].sort().join('|')) throw new Error('invalid_context');
}
export function validateContext(c) {
  const v2 = c?.version === 'atlas-fortune-context-v2';
  exact(c, ['version','language','status','photos', ...(c.narrative ? ['narrative'] : [])]);
  if (c.narrative) validateNarrative(c.narrative);
  if ((!v2 && c.version !== 'atlas-fortune-context-v1') || c.language !== 'tr' || !['ready','partial'].includes(c.status) || !Array.isArray(c.photos) || c.photos.length < 1 || c.photos.length > 4) throw new Error('invalid_context');
  let cups = 0, saucers = 0, useful = false;
  for (const [i,p] of c.photos.entries()) {
    exact(p, ['photoNumber','surface','declaredRole','analysisState','userObservations','physicalMeasurementsStatus','physicalMeasurementScope','globalPhysicalMeasurements', ...(v2 ? ['regionalSummary'] : [])]);
    if (v2) { validateRegional(p.regionalSummary); if (p.analysisState !== 'complete' && p.regionalSummary !== null) throw new Error('invalid_context'); }
    if (p.photoNumber !== i+1 || !['cup','saucer'].includes(p.surface) || ![null,'free','top','handleRight','handleLeft'].includes(p.declaredRole) || !['complete','technicalError'].includes(p.analysisState) || !['available','invalid','notAvailable'].includes(p.physicalMeasurementsStatus) || p.physicalMeasurementScope !== 'wholeImageContentNotUserRegion') throw new Error('invalid_context');
    if (p.surface === 'cup') cups++; else { saucers++; if (p.declaredRole !== null) throw new Error('invalid_context'); }
    if (!Array.isArray(p.userObservations) || p.userObservations.length > 10) throw new Error('invalid_context');
    for (const o of p.userObservations) {
      exact(o,['origin','symbolName','box']); exact(o.box,['x','y','width','height']);
      if (o.origin !== 'userObservation' || !labels.has(o.symbolName)) throw new Error('invalid_context');
      const {x,y,width,height} = o.box;
      if (![x,y,width,height].every(v => typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 1) || width === 0 || height === 0 || x+width > 1.000001 || y+height > 1.000001) throw new Error('invalid_context');
      useful = true;
    }
    const m = p.globalPhysicalMeasurements;
    if (m !== null) {
      exact(m,['residuePixelCount','contentResidueRatio','componentCount','candidateRelationCount','selectedRelationCount']);
      if (p.analysisState !== 'complete' || p.physicalMeasurementsStatus !== 'available') throw new Error('invalid_context');
      for (const [key,value] of Object.entries(m)) {
        if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || (key === 'contentResidueRatio' ? value > 1 : !Number.isSafeInteger(value))) throw new Error('invalid_context');
      }
      if (m.selectedRelationCount > m.candidateRelationCount) throw new Error('invalid_context');
      useful ||= m.residuePixelCount > 0 || m.contentResidueRatio > 0;
    } else if (p.physicalMeasurementsStatus === 'available') throw new Error('invalid_context');
  }
  if (cups < 1 || cups > 3 || saucers > 1 || !useful) throw new Error('invalid_context');
  return c;
}
function lengthRepairHint(previous,reason) {
  if(reason!=='length' || !previous) return '';
  const count=previous.trim().split(/\s+/u).length;
  if(count>=250) return 'Metni 320–380 kelimeye indir; tekrarları çıkar.';
  const extra=Math.max(80,Math.min(340,340-count));
  return `Önceki metin yalnız ${count} kelime. En az ${extra} yeni kelimelik özgün içerik ekle; toplam 320–380 kelime hedefle. Var olan cümleleri tekrar etme. İlk üç paragrafı farklı gündelik olasılıklar ve düşünme davetleriyle geliştir; yeni kişisel olay veya görsel bulgu uydurma.`;
}
export function messages(context, noThink = false, repair = false, reason = null, previousReply = null) {
  return [
    {role:'system', content:prompt.system},
    ...(repair && previousReply ? [{role:'assistant',content:previousReply}] : []),
    {role:'user', content:prompt.userPrefix + JSON.stringify(context) + '\nİzinli kısa fiziksel ifadeler: '+JSON.stringify(physicalCues(context))+'. Bu ifadeler dışında fiziksel sahne betimleme.' + (repair ? '\nÖnceki adayın kelime sayısı: '+(previousReply?.trim().split(/\s+/u).length??0)+'. '+prompt.repair+' '+(prompt.repairHints?.[reason]??'')+' '+lengthRepairHint(previousReply,reason) : '') + (noThink ? '\n/no_think' : '')},
  ];
}
// Keep these bounded language checks aligned with the shared Dart/Node cases.
// They reject known unsupported claims, not every possible semantic error.
export function physicalCues(context) {
  const cues=[];
  for(const p of context?.photos??[]) {
    if(!p.regionalSummary) continue;
    const bands=Object.fromEntries(p.regionalSummary.bands.map(b=>[b.position,b.density]));
    const surface=p.surface==='saucer'?'tabağın':'fincanın';
    const names={top:'üst',middle:'orta',bottom:'alt',left:'sol',center:'merkez',right:'sağ'};
    for(const axis of [['top','middle','bottom'],['left','center','right']]) {
      if(!axis.every(k=>Object.hasOwn(bands,k))) continue;
      const ordered=[...axis].sort((a,b)=>bands[a]-bands[b]);
      if(bands[ordered[2]]-bands[ordered[0]]<.05) continue;
      cues.push(`${surface} ${names[ordered[0]]} bölümündeki daha açık dağılım`);
      cues.push(`${surface} ${names[ordered[2]]} bölümündeki toplanma`);
    }
    const c=p.regionalSummary.components[0];
    if(c) {
      const horizontal=c.x<1/3?'sol':c.x>2/3?'sağ':'orta';
      const vertical=c.y<1/3?'üst':c.y>2/3?'alt':'orta';
      cues.unshift(`${surface} ${horizontal} ${vertical} bölümündeki leke`);
    }
  }
  return [...new Set(cues)].slice(0,3);
}
function groundingError(lower, context) {
  if (/piksel|%\s*\d|yüzde|bileşen|ilişkisel|üç kupa|üç farklı yüzey|üç fincan|ölçüm|ölçülen|çekim aç|kamera aç|(?:sağ|sol|üst) açı|(?:üç|3) (?:farklı )?açı|residuepixelcount|contentresidueratio|componentcount|candidaterelationcount|selectedrelationcount|globalphysicalmeasurements|physicalmeasurement|photonumber|declaredrole|handleright|handleleft/u.test(lower)) return 'technical';
  // Numbered capture metadata, not ordinary perspectives or "ilk bakışta".
  if (/(^|[^a-zçğıöşü0-9])(?:(?:[1-4]|bir|iki|üç|dört)(?:\s+(?:ayrı|farklı))?\s+(?:çekim|fotoğraf|görüntü|görünüm)[a-zçğıöşü]*|(?:birinci|ikinci|üçüncü|dördüncü|[1-4]\.)\s+(?:çekim|fotoğraf|görüntü|görünüm|açı)[a-zçğıöşü]*|(?:[2-4]|iki|üç|dört)(?:\s+(?:ayrı|farklı))?\s+bakış(?:ta|tan|taki|ında|ından|larında|larından))($|[^a-zçğıöşü])/u.test(lower)) return 'technical';
  if (/(?:sembol|şekil|figür)[a-zçğıöşü]*\s+(?:(?:hiç|hiçbir|bir|de)\s+)*(?:yok|bulunm|görünm|gözükm|seçilm|göremedi|göremem|görmedi|seçemedi|seçemem)|(?:sembolsüz|şekilsiz)\s+(?:fincan|fotoğraf|görüntü)|(?:fincan|fotoğraf|görüntü)[a-zçğıöşü]*\s+(?:tamamen\s+)?boş/u.test(lower)) return 'unsupported_absence_claim';
  const visualText=physicalCues(context).reduce((text,cue)=>text.split(cue).join('fiziksel çağrışım'),lower);
  if (/fincanın dib|kahvenin dib|fincanın kenarında|yüzeyindeki|görüyorum|görebiliyorum|tespit edil|içindeki sıvı|(?:fotoğraf|görüntü|fincan|telve|tabak|kahve)[a-zçğıöşü]*[^.!?\n]{0,120}(?:görünü|gözük|gördü|görül|göster|seçili|seçebili|belirgin|şekil|sembol|figür|izler|dolu|yoğun|koyu|leke|çizgi|dağılım|\svar(?:\s|$)|bulun|baktığ|bakınca|incele)/u.test(visualText)) return 'unsupported_visual_claim';
  if (context) {
    const reported = new Set(context.photos.flatMap(p => p.userObservations.map(o => o.symbolName.toLocaleLowerCase('tr'))));
    for (const label of labels) {
      const name = label.toLocaleLowerCase('tr');
      if (reported.has(name)) continue;
      const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      // Explicit symbol/attribution phrases only; everyday metaphors stay valid.
      const claim = new RegExp(`(^|[^a-zçğıöşü])${escaped}(?:[’'][a-zçğıöşü]+)?\\s+(?:sembol|şekl|şekil|figür|simge|işaret)|(?:paylaştığın|işaretlediğin|belirttiğin|seçtiğin|bildirdiğin|gördüğün)\\s+(?:bir\\s+)?${escaped}(?=$|[^a-zçğıöşü])`, 'u');
      if (claim.test(lower)) return 'unsupported_symbol_claim';
    }
    if (reported.size === 0 && /(?:paylaştığın|işaretlediğin|belirttiğin|seçtiğin|bildirdiğin|gördüğün)\s+(?:bu\s+)?(?:sembol|şekil|figür)/u.test(lower)) return 'unsupported_symbol_claim';
  }
  return null;
}
export function qualityError(text, finishReason, context = null) {
  if (finishReason !== 'stop' || typeof text !== 'string') return 'incomplete';
  if(context?.version==='atlas-fortune-context-v2') {
    const words=text.trim().split(/\s+/u).length;
    if(words<250 || words>400) return 'length';
    if(text.trim().split(/\n\s*\n/u).length!==4) return 'structure';
  }
  const lower = text.toLocaleLowerCase('tr');
  if (/<\/?think|analysis:|reasoning:|```|\b(system|assistant)\s*:/i.test(text)) return 'reasoning';
  if (text.trim().split(/\s+/u).length < 150 || text.length > 12000) return 'length';
  if (/kesinlikle|kesin olarak|yüzde yüz|%\s*100|garanti|mutlaka|olacaksın|kazanacaksın|evleneceksin|gerçekleşecek|olacaktır|öleceksin|olacağını|şekillenecek|getirecek|açılacak|karşılaşacaksın|bulacaksın|seni bekliyor/u.test(lower)) return 'certainty';
  if (/(^|[^a-zçğıöşü])(olacak|yaşanacak|göreceksin|hissedeceksin|başlayacak|bitecek|kalacak|taşıyacak|çıkacak)($|[^a-zçğıöşü])/u.test(lower)) return 'certainty';
  const grounding = groundingError(lower, context);
  if (grounding) return grounding;
  if (!/olabilir|belki|çağrıştır|düşünülebilir|ihtimal/u.test(lower)) return 'certainty';
  return null;
}

export function validateNarrative(n) {
  exact(n, ['version','topic','arc','closing','maxPhysicalDetails']);
  if(n.version !== 'atlas-narrative-v1' || n.maxPhysicalDetails !== 3 ||
    !['relationships','work','social','decisions','rest','beginnings'].includes(n.topic) ||
    !['notice-explore-choice','contrast-perspective-small-step','pause-connection-opening'].includes(n.arc) ||
    !['gentle-question','small-invitation','open-possibility'].includes(n.closing)) throw new Error('invalid_context');
}
export function validateRegional(s) {
  if(s === null) return;
  exact(s,['version','bands','components','relations']);
  if(s.version !== 'atlas-regional-summary-v1' || !Array.isArray(s.bands) || !Array.isArray(s.components) || !Array.isArray(s.relations)) throw new Error('invalid_context');
  const num=(v,max=Infinity)=> typeof v==='number' && Number.isFinite(v) && v>=0 && v<=max;
  const positions=new Set();
  for(const b of s.bands) {
    exact(b,['position','density']);
    if(!['top','middle','bottom','left','center','right'].includes(b.position) || positions.has(b.position) || !num(b.density,1)) throw new Error('invalid_context');
    positions.add(b.position);
  }
  if(s.components.length>3) throw new Error('invalid_context');
  for(const [i,c] of s.components.entries()) {
    exact(c,['number','x','y','residueShare','aspectRatio']);
    if(c.number!==i+1 || !num(c.x,1) || !num(c.y,1) || !num(c.residueShare,1) || c.residueShare<.01 || !num(c.aspectRatio) || !c.aspectRatio) throw new Error('invalid_context');
  }
  const pairs=new Set();
  for(const r of s.relations) {
    exact(r,['from','to','distance']);
    if(!Number.isSafeInteger(r.from) || !Number.isSafeInteger(r.to) || r.from<1 || r.to<1 || r.from>s.components.length || r.to>s.components.length || r.from===r.to || !num(r.distance) || pairs.has(`${r.from}:${r.to}`)) throw new Error('invalid_context');
    pairs.add(`${r.from}:${r.to}`);
  }
}
