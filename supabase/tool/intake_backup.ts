// Operator-only. No application key can run this backup or restore gate.
import { createClient } from "@supabase/supabase-js";
import { digest, roles, type Json } from "../functions/contribution-api/validation.ts";

const [command, location] = Deno.args;
if (!["backup", "verify-restore"].includes(command) || !location) throw Error("Usage: backup|verify-restore EXTERNAL_DIRECTORY");
const repository = await Deno.realPath(new URL("../../", import.meta.url));
const directory = await Deno.realPath(location);
if (directory.toLowerCase().startsWith(repository.toLowerCase())) throw Error("Backup must be outside the repository");
const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!url?.startsWith("https://") || !key) throw Error("Operator service credentials required");
const client = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
function check<T>(v: {data:T;error:unknown}) { if(v.error) throw v.error;return v.data; }
const tombstones = check(await client.from("intake_tombstones").select("*")) ?? [];
const denied = new Set(tombstones.map(t=>t.root_id));
const current = (check(await client.from("intake_revisions").select("*").eq("status","submitted").gt("expires_at",new Date().toISOString())) ?? []).filter(r=>!denied.has(r.root_id));
if(command==="backup") {
  const out=`${directory}/${new Date().toISOString().replaceAll(/[:.]/g,"-")}`;
  await Deno.mkdir(out);await Deno.mkdir(`${out}/media`);
  const files: Record<string,string> = {};
  for(const r of current) {
    for(const role of roles) {
      const photo=r.document.photos.find((p:Json)=>p.role===role);
      const data=check(await client.storage.from("contributions").download(`${r.owner_id}/${r.id}/${role}.jpg`));
      const bytes=new Uint8Array(await data!.arrayBuffer());
      const hash=await digest(bytes);if(hash!==photo.checksum) throw Error("Source photo hash mismatch; incomplete backup must not be restored");
      const name=`media/${r.id}-${role}.jpg`;await Deno.writeFile(`${out}/${name}`,bytes);files[name]=hash;
    }
  }
  const reviews=current.length?check(await client.from("intake_reviews").select("*").in("revision_id",current.map(r=>r.id))):[];
  const bytes=new TextEncoder().encode(JSON.stringify({version:1,project:url,createdAt:new Date().toISOString(),rows:current,reviews,tombstones}));
  await Deno.writeFile(`${out}/records.json`,bytes);files["records.json"]=await digest(bytes);
  await Deno.writeTextFile(`${out}/manifest.json`,JSON.stringify({version:1,files},null,2));
  console.log(JSON.stringify({directory:out,records:current.length,files:Object.keys(files).length,manifestChecksum:await digest(await Deno.readFile(`${out}/manifest.json`))}));
} else {
  const manifest=JSON.parse(await Deno.readTextFile(`${directory}/manifest.json`));
  if(manifest.version!==1 || typeof manifest.files!=="object") throw Error("Unknown backup format");
  for(const [name,hash] of Object.entries(manifest.files)) {
    if(name!=="records.json" && !/^media\/[0-9a-f-]{36}-(top|handleRight|handleLeft)\.jpg$/.test(name)) throw Error("Unsafe backup path");
    const file=await Deno.realPath(`${directory}/${name}`);
    if(!file.startsWith(directory+"/") && !file.startsWith(directory+"\\")) throw Error("Backup path escaped its directory");
    if(await digest(await Deno.readFile(file))!==hash) throw Error("Backup hash mismatch");
  }
  if(!manifest.files['records.json']) throw Error("Records checksum missing");
  const data=JSON.parse(await Deno.readTextFile(`${directory}/records.json`));
  if(data.project!==url || data.version!==1) throw Error("Different project or backup version");
  const active=new Set(current.map(r=>r.id));
  // Missing current state is a denial, never permission to resurrect an old backup.
  const allowed=data.rows.filter((r:Json)=>active.has(r.id) && !denied.has(r.root_id) && Date.parse(r.expires_at as string)>Date.now());
  console.log(JSON.stringify({verified:true,allowedRevisionIds:allowed.map((r:Json)=>r.id),excludedCount:data.rows.length-allowed.length,
    applied:false,note:"Read-only restore gate. Recheck current tombstones immediately before an explicitly approved restore; never import this backup wholesale."}));
}
