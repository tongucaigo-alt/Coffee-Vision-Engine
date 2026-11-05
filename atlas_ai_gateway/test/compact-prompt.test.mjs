import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validateContext,sourceAwareBrief,messages,prompt} from '../contract.mjs';

test('compact v4 brief matches shared facts without changing the source',()=>{
  const rows=JSON.parse(readFileSync(new URL('./fixtures/compact-brief-v18.json',import.meta.url)));
  assert.ok(prompt.currentSystem.split(/\s+/u).length<200);
  assert.ok(prompt.currentStyleExample.assistant.split(/\s+/u).length<110);
  for(const row of rows) {
    const c=validateContext(row.context), before=JSON.stringify(c);
    const brief=sourceAwareBrief(c);
    assert.deepEqual(JSON.parse(brief),row.brief,row.id);
    assert.ok(!brief.includes('leke'));
    assert.ok(!brief.includes('aynen kullan'));
    assert.equal(JSON.stringify(c),before);
    assert.equal(messages(c).length,4);
    assert.ok(messages(c).at(-1).content.endsWith(brief));
    const repair=messages(c,false,true,'mechanical_language','Eski ve mekanik aday.');
    assert.equal(repair.length,6);
    assert.ok(repair.at(-1).content.includes(prompt.currentRepairHints.mechanical_language));
    assert.ok(!repair.at(-1).content.includes('Her mevcut yüzeyden'));
  }
});


test('memory copy repair drops only optional archive data and retains the initial request',()=>{
  const rows=JSON.parse(readFileSync(new URL('./fixtures/compact-brief-v18.json',import.meta.url)));
  const c=rows[1].context,before=JSON.stringify(c);
  for(const reason of ['repetition','unsupported_memory']) {
    const turns=messages(c,false,true,reason,'Eski aday.');
    const body=i=>JSON.parse(turns[i].content.slice(prompt.currentUserPrefix.length).split('\n')[0]);
    assert.equal(body(3).memory_reference_allowed,true);
    assert.equal(body(5).memory_reference_allowed,false);
    assert.equal(body(5).past_excerpt,null);
    assert.equal(JSON.stringify(c),before);
  }
});
