import { validateDocument, validateCorrections, digest, jpegInfo, roles, labels, readLimitedJson } from "./validation.ts";
import jpeg from "jpeg-js";
import vocabulary from "../../../atlas_contribution_app/assets/contribution-labels-v1.json" with { type: "json" };
function assert(v: unknown) { if (!v) throw Error("assertion failed"); }
function reject(fn: () => unknown) { let threw = false; try { fn(); } catch { threw = true; } assert(threw); }
Deno.test("request body is bounded even without Content-Length",async()=>{
  const body=await readLimitedJson(new Request('https://test.invalid',{method:'POST',body:'{"action":"list"}'}));assert(body.action==='list');
  let denied=false;try{await readLimitedJson(new Request('https://test.invalid',{method:'POST',body:'x'.repeat(128001)}));}catch{denied=true;}assert(denied);
});
function doc() {
  const id=crypto.randomUUID(), now=new Date().toISOString();
  return { id,rootId:id,groupId:crypto.randomUUID(),revision:1,supersedesId:null,createdAt:now,consentedAt:now,
    consentVersion:"contribution-consent-v1",labelVersion:"contribution-labels-v1",queued:false,
    photos:roles.map(role=>({role,localName:`${crypto.randomUUID()}.jpg`,checksum:`sha256:${"a".repeat(64)}`,originalChecksum:`sha256:${"b".repeat(64)}`,
      width:200,height:300,byteLength:3000,capturedAt:now,derivative:"orientation-baked-jpeg-2048-q90-v1",decision:"skipped",regions:[] as unknown[]})) };
}
Deno.test("exact roles and 20 non-canonical labels",()=>{assert(roles.join(",")==="top,handleRight,handleLeft");assert(labels.length===20);validateDocument(doc());});
Deno.test("server vocabulary matches versioned mobile dictionary",()=>{assert(vocabulary.version==="contribution-labels-v1");assert(JSON.stringify(vocabulary.labels.map(l=>l.id))===JSON.stringify(labels));});
Deno.test("unknown fields, role permutation, incomplete and unreviewed rejected",()=>{
 const d=doc();reject(()=>validateDocument({...d,extra:true}));d.photos.reverse();reject(()=>validateDocument(d));
 const e=doc();e.photos[0].decision="unreviewed";reject(()=>validateDocument(e));e.photos.pop();reject(()=>validateDocument(e));
});
Deno.test("three abstention decisions are separate and accepted",()=>{for(const state of ["skipped","notSeen","uncertain"]){const d=doc();d.photos[0].decision=state;validateDocument(d);}});
Deno.test("normalized bounds and explicit uncertain region",()=>{
 const d=doc(), r={id:crypto.randomUUID(),box:{x:.2,y:.2,width:.3,height:.4},label:null};d.photos[0].regions=[r];d.photos[0].decision="marked";validateDocument(d);
 r.box.width=1;reject(()=>validateDocument(d));r.box.width=NaN;reject(()=>validateDocument(d));
});
Deno.test("duplicate regions, unknown label, max ten",()=>{
 const d=doc(),r={id:crypto.randomUUID(),box:{x:0,y:0,width:.5,height:.5},label:"tree"};d.photos[0].decision="marked";d.photos[0].regions=[r,r];reject(()=>validateDocument(d));
 d.photos[0].regions=[{...r,label:"symbol-tree"}];reject(()=>validateDocument(d));
 d.photos[0].regions=Array.from({length:11},()=>({...r,id:crypto.randomUUID()}));reject(()=>validateDocument(d));
});
Deno.test("consent, checksum, path traversal and size rejected",()=>{
 const d=doc();reject(()=>validateDocument({...d,consentVersion:""}));
 d.photos[0].localName="../x.jpg";reject(()=>validateDocument(d));d.photos[0].localName="x.jpg";
 d.photos[0].byteLength=5242881;reject(()=>validateDocument(d));d.photos[0].byteLength=100;
 d.photos[0].checksum="sha256:ABC";reject(()=>validateDocument(d));
});
Deno.test("corrections reference existing regions only and never mutate original",()=>{
 const d=doc(),r={id:crypto.randomUUID(),box:{x:0,y:0,width:.5,height:.5},label:"tree"};d.photos[0].decision="marked";d.photos[0].regions=[r];
 validateCorrections([{regionId:r.id,label:"bird"}],d);assert(r.label==="tree");reject(()=>validateCorrections([{regionId:crypto.randomUUID(),label:"tree"}],d));
});
Deno.test("JPEG dimension and metadata gate, exact hash",async()=>{
 const b=jpeg.encode({width:2,height:3,data:new Uint8Array(24)},90).data;
 assert(jpegInfo(b).width===2 && jpegInfo(b).height===3);assert((await digest(new TextEncoder().encode("abc")))==="sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
 const metadata=new Uint8Array([...b.slice(0,2),255,225,0,2,...b.slice(2)]);reject(()=>jpegInfo(metadata));reject(()=>jpegInfo(b.slice(0,20)));
});
