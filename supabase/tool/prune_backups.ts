// Removes only expired/withdrawn records from this application's own verified backups.
import { createClient } from "@supabase/supabase-js";
import { digest } from "../functions/contribution-api/validation.ts";
const root=await Deno.realPath(Deno.args[0] ?? "");
const repo=await Deno.realPath(new URL("../../",import.meta.url));
if(root.toLowerCase().startsWith(repo.toLowerCase())) throw Error("External backup root required");
const denied=new Set<string>();
const url=Deno.env.get("SUPABASE_URL"),key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if(url && key) {
  const client=createClient(url,key,{auth:{persistSession:false}});
  const {data,error}=await client.from("intake_tombstones").select("root_id");
  if(error) throw error;for(const r of data ?? [])denied.add(r.root_id);
}
let removed=0;
for await(const entry of Deno.readDir(root)) {
  if(!entry.isDirectory || !/^\d{4}-\d\d-\d\dT[\d-]+Z$/.test(entry.name))continue;
  const folder=await Deno.realPath(`${root}/${entry.name}`);
  if(!folder.startsWith(root+"/") && !folder.startsWith(root+"\\"))throw Error("Unsafe backup directory");
  let manifest;
  try{manifest=JSON.parse(await Deno.readTextFile(`${folder}/manifest.json`));}catch{throw Error("Incomplete backup requires operator review; do not retain it indefinitely");}
  for(const [name,hash] of Object.entries(manifest.files)) {
    if(name!=="records.json" && !/^media\/[0-9a-f-]{36}-(top|handleRight|handleLeft)\.jpg$/.test(name))throw Error("Unsafe backup path");
    const exact=await Deno.realPath(`${folder}/${name}`);
    if(!exact.startsWith(folder+"/") && !exact.startsWith(folder+"\\"))throw Error("Symlink escaped backup directory");
    if(await digest(await Deno.readFile(exact))!==hash)throw Error("Backup hash mismatch");
  }
  const records=JSON.parse(await Deno.readTextFile(`${folder}/records.json`));
  const expired=new Set<string>();
  for(const row of records.rows) {
    if(!Number.isFinite(Date.parse(row.expires_at)))throw Error("Invalid expiry");
    if(Date.parse(row.expires_at)<=Date.now() || denied.has(row.root_id))expired.add(row.id);
  }
  if(!expired.size)continue;
  for(const name of Object.keys(manifest.files)) {
    if(name.startsWith("media/") && expired.has(name.slice(6,42))) {
      await Deno.remove(`${folder}/${name}`);delete manifest.files[name];removed++;
    }
  }
  records.rows=records.rows.filter((r:{id:string})=>!expired.has(r.id));
  records.reviews=records.reviews.filter((r:{revision_id:string})=>!expired.has(r.revision_id));
  const bytes=new TextEncoder().encode(JSON.stringify(records));
  await Deno.writeFile(`${folder}/records.json`,bytes);manifest.files["records.json"]=await digest(bytes);
  await Deno.writeTextFile(`${folder}/manifest.json`,JSON.stringify(manifest,null,2));
}
console.log(JSON.stringify({removedMediaFiles:removed,withdrawalLedgerChecked:!!(url&&key),expiryChecked:true}));
