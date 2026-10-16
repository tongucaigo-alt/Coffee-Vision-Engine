import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validateContext,qualityError,messages,personalizedContextVersion,physicalCues,sourceAwareBrief,exampleRepetitionError,qualityWarnings,prompt} from '../contract.mjs';

const fixture=JSON.parse(readFileSync(new URL('./fixtures/personalized-quality-cases.json',import.meta.url)));
function context(symbol=null,zodiac=null) {
  return {
    version:personalizedContextVersion,language:'tr',status:'ready',
    creativeSymbol:symbol ? null : {catalogVersion:'atlas-creative-symbols-v1',origin:'creativeSelectionNotVisualDetection',symbolId:'key',symbolName:'Anahtar'},
    ...(zodiac ? {personalization:{zodiac}} : {}),
    photos:[{photoNumber:1,surface:'cup',declaredRole:'free',analysisState:'complete',
      userObservations:symbol ? [{origin:'userObservation',symbolName:symbol,box:{x:.2,y:.2,width:.15,height:.15}}] : [],
      physicalMeasurementsStatus:'available',physicalMeasurementScope:'wholeImageContentNotUserRegion',
      globalPhysicalMeasurements:{residuePixelCount:30,contentResidueRatio:.2,componentCount:3,candidateRelationCount:1,selectedRelationCount:0},
      regionalSummary:{version:'atlas-regional-summary-v1',bands:[{position:'top',density:.1},{position:'middle',density:.2},{position:'bottom',density:.6}],components:[],relations:[]},
    }],
  };
}
test('v3 strict fields preserve physical and user-source boundaries',()=>{
  assert.equal(validateContext(context()).version,personalizedContextVersion);
  for(const mutate of [
    c=>c.personalization={zodiac:'libra',addressName:'private'},
    c=>c.personalization={zodiac:'unknown'},
    c=>c.creativeSymbol.origin='userObservation',
    c=>c.creativeSymbol.symbolName='Kuş',
    c=>c.creativeSymbol=null,
    c=>c.photos[0].userObservations=context('Kuş').photos[0].userObservations,
    c=>c.photos[0].globalPhysicalMeasurements={residuePixelCount:0,contentResidueRatio:0,componentCount:0,candidateRelationCount:0,selectedRelationCount:0},
  ]){const c=context(); mutate(c); assert.throws(()=>validateContext(c));}
});
test('shared personalized quality cases agree with Dart, including non-editorial paths',()=>{
  for(const row of fixture.cases) {
    const c=validateContext(context(row.userSymbol,row.zodiac));
    const story=fixture.validStory.replaceAll('Anahtarın',row.userSymbol ? 'Paylaştığın kuşun' : 'Anahtarın');
    assert.equal(qualityError(story+' '+row.suffix,'stop',c),row.error,row.id);
  }
  assert.equal(qualityError('Anahtar bir ihtimal olabilir.','stop',context(),false),'length');
});
test('v3 messages state the source and send only an explicitly supplied zodiac',()=>{
  const base=messages(context());
  assert.match(base[0].content,/yaratıcı sembolü/);
  assert.deepEqual(base.map(m=>m.role),['system','user','assistant','user']);
  assert.match(base.at(-1).content,/Yaratıcı anlatı sembolü: Anahtar/);
  assert.ok(!base.at(-1).content.includes('libra'));
  assert.match(messages(context(null,'libra')).at(-1).content,/izin verdiği burç: Terazi/);
  assert.match(messages(context('Kuş')).at(-1).content,/bildirdiği semboller: Kuş/);
});

test('style sample reuse is a bounded runtime error, independent text remains allowed',()=>{
  assert.equal(exampleRepetitionError(prompt.personalizedStyleExample.assistant,context()),'repetition');
  assert.equal(exampleRepetitionError(fixture.transportStory,context()),null);
  assert.equal(qualityError(fixture.transportStory,'stop',context()),null);
  const copied=prompt.personalizedStyleExample.assistant.split(/[.!?\n]+/u).filter(s=>s.trim()).at(-1).trim();
  const repair=messages(context(),false,true,'repetition',copied).at(-1).content;
  assert.ok(repair.includes('Şu cümleler üslup örneğinden kopyalanmış:'));
  assert.ok(repair.includes(copied));
  assert.ok(!messages(context(),false,true,'repetition','Tamamen başka bir aday.').at(-1).content.includes('Şu cümleler üslup örneğinden kopyalanmış:'));
});

test('shared brief keeps cup and saucer separately with no raw measurement fields',()=>{
  const row=JSON.parse(readFileSync(new URL('./fixtures/source-brief-v12.json',import.meta.url)));
  const c=validateContext(row.context),before=JSON.stringify(c);
  assert.deepEqual(physicalCues(c),row.expectedCues);
  assert.equal(sourceAwareBrief(c),row.expectedBrief);
  const turns=messages(c);
  assert.deepEqual(turns.map(m=>m.role),['system','user','assistant','user']);
  for(const field of ['photoNumber','residuePixelCount','globalPhysicalMeasurements','box','libra']) assert.ok(!turns.at(-1).content.includes(field));
  assert.deepEqual(messages(c,false,true,'missing_physical_surface','Önceki kısa taslak.').map(m=>m.role),['system','user','assistant','user','assistant','user']);
  assert.equal(JSON.stringify(c),before);
  const story=fixture.transportStory.replaceAll('Fincanın üst bölümündeki daha açık dağılım','Fincanın alt bölümündeki daha açık dağılım');
  assert.equal(qualityError(story,'stop',c),'missing_physical_surface');
  const complete=story+' Tabağın üst bölümündeki daha açık dağılım, bu ihtimale başka bir ferahlık katabilir.';
  assert.equal(qualityError(complete,'stop',c),null);
  assert.equal(qualityError(complete+' Fincanın alt bölümündeki daha açık dağılım.','stop',c),'fragmented_physical_phrase');
});

test('v3 formatting warnings never hide a source violation',()=>{
 const c=context();const text=fixture.transportStory.split('\n\n').slice(0,3).join('\n\n');
 assert.ok(text.split(/\s+/u).length>=150);
 assert.equal(qualityError(text,'stop',c),null);
 assert.deepEqual(qualityWarnings(text,c),['length','structure']);
 assert.equal(qualityError(text+' Fincanında belirgin bir kuş görüyorum.','stop',c),'unsupported_visual_claim');
 assert.equal(qualityError(text,'length',c),'incomplete');
});
