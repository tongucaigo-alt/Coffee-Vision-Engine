import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

const db = new PGlite();
await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
 create schema auth; create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 grant usage on schema auth to authenticated;
 create schema storage; create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id bigint generated always as identity,name text,bucket_id text);
 alter table storage.objects enable row level security;
 grant usage on schema storage to authenticated; grant select on storage.objects to authenticated;`);
await db.exec(await readFile(new URL('../migrations/202609090001_contributions.sql', import.meta.url), 'utf8'));
let passed = 0;
async function test(name, fn) { await fn(); passed++; console.log(`PASS ${name}`); }
async function rpc(name, args, casts) {
 return (await db.query(`select public.${name}(${args.map((_,i)=>`$${i+1}::${casts[i]}`).join(',')}) as value`, args)).rows[0].value;
}
const owner = randomUUID(), other = randomUUID(), admin = randomUUID();
await db.query('insert into auth.users values ($1),($2),($3)', [owner,other,admin]);
await db.query('insert into intake_admins values($1)',[admin]);
const invite='a'.repeat(64);
await db.query('insert into intake_invites(code_hash) values($1)',[invite]);
await test('invite required and single-account redemption', async()=>{
 await assert.rejects(()=>rpc('intake_enroll',[owner,'b'.repeat(64)],['uuid','text']),/invite_invalid/);
 await rpc('intake_enroll',[owner,invite],['uuid','text']);
 await rpc('intake_enroll',[owner,invite],['uuid','text']);
 await assert.rejects(()=>rpc('intake_enroll',[other,invite],['uuid','text']),/invite_invalid/);
});
const makeDoc = () => {const id=randomUUID();return {id,rootId:id,groupId:randomUUID(),revision:1,supersedesId:null,photos:[],consentVersion:'contribution-consent-v1'};};
const doc=makeDoc();
await test('non-member reservation rejected',()=>assert.rejects(()=>rpc('intake_reserve',[other,doc],['uuid','jsonb']),/not_enrolled/));
await test('idempotent reservation and content conflict',async()=>{
 const first=await rpc('intake_reserve',[owner,doc],['uuid','jsonb']);
 const second=await rpc('intake_reserve',[owner,doc],['uuid','jsonb']);
 assert.equal(first.id,second.id);assert.equal(first.status,'reserved');
 await assert.rejects(()=>rpc('intake_reserve',[owner,{...doc,extra:true}],['uuid','jsonb']),/conflict/);
});
await test('reserved contribution never readable',async()=>{
 await db.query('insert into storage.objects(name,bucket_id) values($1,\'contributions\')',[`${owner}/${doc.id}/top.jpg`]);
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[owner]);
 await db.exec('set role authenticated');
 assert.equal((await db.query('select * from storage.objects')).rows.length,0);
 await assert.rejects(()=>db.query('select * from intake_revisions'),/permission denied/);
 await assert.rejects(()=>rpc('intake_finalize',[owner,doc.id],['uuid','uuid']),/permission denied/);
 await db.exec('reset role');
});
await test('server-only finalize is idempotent',async()=>{
 const first=await rpc('intake_finalize',[owner,doc.id],['uuid','uuid']);
 const second=await rpc('intake_finalize',[owner,doc.id],['uuid','uuid']);
 assert.equal(first.submitted_at,second.submitted_at);
});
await test('owner and admin read; other account cannot',async()=>{
 for(const [uid,count] of [[owner,1],[other,0],[admin,1]]) {
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[uid]);await db.exec('set role authenticated');
  assert.equal((await db.query('select * from storage.objects')).rows.length,count);
  await db.exec('reset role');
 }
});
await test('participant cannot forge admin review',()=>assert.rejects(()=>rpc('intake_review',[owner,doc.id,'suitable',[]],['uuid','uuid','text','jsonb']),/forbidden/));
await test('reviews append without replacing user document',async()=>{
 await rpc('intake_review',[admin,doc.id,'uncertain',[]],['uuid','uuid','text','jsonb']);
 await rpc('intake_review',[admin,doc.id,'suitable',[]],['uuid','uuid','text','jsonb']);
 assert.equal((await db.query('select * from intake_reviews')).rows.length,2);
 assert.deepEqual((await db.query('select document from intake_revisions where id=$1',[doc.id])).rows[0].document,doc);
});
await test('revision preserves physical group and previous document',async()=>{
 const revision={...doc,id:randomUUID(),revision:2,supersedesId:doc.id};
 await assert.rejects(()=>rpc('intake_reserve',[owner,{...revision,groupId:randomUUID()}],['uuid','jsonb']),/revoked/);
 await rpc('intake_reserve',[owner,revision],['uuid','jsonb']);
 await rpc('intake_finalize',[owner,revision.id],['uuid','uuid']);
 assert.equal((await db.query('select status from intake_revisions where id=$1',[doc.id])).rows[0].status,'superseded');
});
await test('three-session participant cap',async()=>{
 await rpc('intake_reserve',[owner,makeDoc()],['uuid','jsonb']);await rpc('intake_reserve',[owner,makeDoc()],['uuid','jsonb']);
 await assert.rejects(()=>rpc('intake_reserve',[owner,makeDoc()],['uuid','jsonb']),/quota/);
});
await test('600MiB includes pending reservations',async()=>{
 const uid=randomUUID();await db.query('insert into auth.users values($1)',[uid]);await db.query('insert into intake_members(user_id) values($1)',[uid]);
 await db.query('update intake_revisions set reserved_bytes=629145600 where id=$1',[doc.id]);
 await assert.rejects(()=>rpc('intake_reserve',[uid,makeDoc()],['uuid','jsonb']),/quota/);
 await db.query('update intake_revisions set reserved_bytes=15728640 where id=$1',[doc.id]);
});
await test('withdrawal blocks reading, export status and later review immediately',async()=>{
 await assert.rejects(()=>rpc('intake_withdraw',[other,doc.rootId],['uuid','uuid']),/forbidden/);
 await rpc('intake_withdraw',[owner,doc.rootId],['uuid','uuid']);
 assert.equal((await db.query('select * from intake_revisions where root_id=$1 and status=\'submitted\'',[doc.rootId])).rows.length,0);
 await assert.rejects(()=>rpc('intake_review',[admin,doc.id,'suitable',[]],['uuid','uuid','text','jsonb']),/revoked/);
 await assert.rejects(()=>rpc('intake_finalize',[owner,doc.id],['uuid','uuid']),/revoked/);
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[owner]);await db.exec('set role authenticated');
 assert.equal((await db.query('select * from storage.objects')).rows.length,0);await db.exec('reset role');
});
await test('expiry creates permanent withdrawal tombstone',async()=>{
 await db.query('update intake_roots set expires_at=now()-interval \'1 day\'');await rpc('intake_expire',[],[]);
 assert.equal((await db.query('select * from intake_revisions where status=\'submitted\'')).rows.length,0);
 assert.ok((await db.query('select * from intake_tombstones')).rows.length>=3);
});
await test('rate limit enforced',async()=>{
 for(let i=0;i<100;i++) assert.equal(await rpc('intake_rate',[other],['uuid']),true);
 assert.equal(await rpc('intake_rate',[other],['uuid']),false);
});
console.log(`${passed}/${passed} SQL tests passed (PostgreSQL/PGlite; hosted Storage/Auth integration still required).`);
await db.close();
