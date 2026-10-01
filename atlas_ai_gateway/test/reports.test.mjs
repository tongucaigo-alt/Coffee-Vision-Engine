import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readdir, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { reportStore } from '../reports.mjs';
import { createGateway } from '../server.mjs';
import { createHash } from 'node:crypto';
import { qualityError, physicalCues } from '../contract.mjs';

test('HTTP reporting authenticates, persists before acknowledgement and fails closed on disk errors', async t => {
  const token = 'a'.repeat(40);
  let saved = 0;
  const server = createGateway({config: () => ({models:{}}), tokens: () => [{id:'tester',hash:createHash('sha256').update(token).digest('hex')}],
    saveReport: async () => { if (++saved > 1) throw new Error('disk full'); }});
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}/api/ai/v1/reports`;
  const body = JSON.stringify({version:1,id:'00000000-0000-4000-8000-000000000001',reason:'other',text:'Yorum'});
  assert.equal((await fetch(url,{method:'POST',body})).status,401);
  assert.equal(saved,0);
  const headers = {Authorization:`Bearer ${token}`};
  const response = await fetch(url,{method:'POST',headers,body});
  assert.equal(response.status,201);
  assert.equal((await response.json()).status,'received');
  assert.equal((await fetch(url,{method:'POST',headers,body})).status,503);
});

test('delivery ignores editorial length without bypassing reasoning or certainty', () => {
  assert.equal(qualityError('Belki kendine biraz zaman ayırmak iyi gelebilir.','stop',null,false),null);
  assert.equal(qualityError('<think>Belki kendine zaman ayır.','stop',null,false),'reasoning');
  assert.equal(qualityError('Kesinlikle kazanacaksın.','stop',null,false),'certainty');
  assert.equal(qualityError('','stop',null,false),'incomplete');
  assert.deepEqual(physicalCues({photos:[{surface:'cup',regionalSummary:{bands:[],components:[{x:.5,y:.5}]}}]}),['fincanın orta bölümündeki leke']);
});

test('reports survive restart, retries deduplicate and owners are isolated', async t => {
  const dir = await mkdtemp(join(tmpdir(), 'atlas-reports-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const save = reportStore(dir);
  const report = { version: 1, id: '00000000-0000-4000-8000-000000000001', reason: 'misleading', text: 'Bildirilen yorum.' };
  await Promise.all([save('a', report), save('a', report)]);
  await reportStore(dir)('a', report);
  assert.equal((await readdir(dir)).length, 1);
  await save('b', report);
  assert.equal((await readdir(dir)).length, 2);
  await assert.rejects(save('a', { ...report, text: 'Değişti' }), /conflict/);
  await assert.rejects(save('a', { ...report, photo: 'private' }), /invalid/);
  await assert.rejects(save('a', { ...report, text: '' }), /invalid/);
  for (const file of await readdir(dir)) {
    const record = JSON.parse(await readFile(join(dir, file), 'utf8'));
    assert.deepEqual(record.report, report);
    assert.deepEqual(Object.keys(record).sort(), ['receivedAt', 'report']);
  }
});
