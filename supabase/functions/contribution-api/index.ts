import { createClient } from "@supabase/supabase-js";
import jpeg from "jpeg-js";
import { validateDocument, validateCorrections, digest, jpegInfo, roles, id, readLimitedJson, type Json } from "./validation.ts";

const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } });
const bucket = client.storage.from("contributions");
const origin = Deno.env.get("ADMIN_ORIGIN") ?? "";
const cors = { "Access-Control-Allow-Origin": origin, "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS", "Vary": "Origin" };
function check<T>(r: { data: T; error: unknown }): T { if (r.error) throw r.error; return r.data; }
function path(row: Json, role: string) { return `${row.owner_id}/${row.id}/${role}.jpg`; }
async function rpc(name: string, args: Json = {}) { return check(await client.rpc(name, args)); }
async function member(uid: string, admin = false) {
  const r = check(await client.from(admin ? "intake_admins" : "intake_members").select("*").eq("user_id", uid).maybeSingle());
  if (!r || (!admin && !r.active)) throw Error("forbidden");
}
async function rowFor(uid: string, key: string, admin = false) {
  id(key); const r = check(await client.from("intake_revisions").select("*").eq("id", key).maybeSingle());
  if (!r || (!admin && r.owner_id !== uid)) throw Error("forbidden");
  if (!["reserved", "submitted"].includes(r.status) || Date.parse(r.expires_at) <= Date.now()) throw Error("revoked");
  const tomb = check(await client.from("intake_tombstones").select("root_id").eq("root_id", r.root_id).maybeSingle());
  if (tomb) throw Error("revoked");
  return r;
}
async function validPhoto(row: Json, p: Json): Promise<boolean> {
  const result = await bucket.download(path(row, p.role as string));
  if (result.error || !result.data) return false;
  const b = new Uint8Array(await result.data.arrayBuffer());
  if (b.length !== p.byteLength || await digest(b) !== p.checksum) return false;
  try {
    const info = jpegInfo(b);
    if (info.width !== p.width || info.height !== p.height || info.width > 2048 || info.height > 2048) return false;
    const decoded = jpeg.decode(b, { useTArray: true, maxResolutionInMP: 5, maxMemoryUsageInMB: 64, tolerantDecoding: false });
    return decoded.width === p.width && decoded.height === p.height;
  } catch { return false; }
}
async function removeFiles(row: Json) {
  check(await bucket.remove(roles.map(role => path(row, role))));
}
async function cleanup() {
  await rpc("intake_expire");
  // Re-scan purged paths too: an earlier signed upload token can remain valid for two hours.
  const rows = check(await client.from("intake_revisions").select("*").in("status", ["withdrawn", "cancelled", "purged"]));
  let purged = 0;
  for (const r of rows ?? []) {
    await removeFiles(r);
    check(await client.from("intake_reviews").delete().eq("revision_id", r.id));
    // Keep the reservation charged until every previously issued token has expired.
    if (Date.now() - Date.parse(r.created_at) > 7 * 86400000 + 3 * 3600000 || r.status === "purged") {
      check(await client.from("intake_revisions").update({ status: "purged", document: null, reserved_bytes: 0 }).eq("id", r.id));
    } else {
      check(await client.from("intake_revisions").update({ document: null }).eq("id", r.id));
    }
    purged++;
  }
  return { purged };
}
async function dispatch(uid: string, body: Json): Promise<Json> {
  const action = body.action;
  if (!await rpc("intake_rate", { p_user: uid })) throw Error("rate_limit");
  if (action === "enroll") {
    if (typeof body.code !== "string" || !/^[A-Z0-9-]{8,16}$/.test(body.code)) throw Error("invite_invalid");
    const hash = (await digest(new TextEncoder().encode(body.code))).slice(7);
    await rpc("intake_enroll", { p_user: uid, p_hash: hash }); return { enrolled: true };
  }
  const admin = ["adminList", "review", "adminPhotoUrls", "export"].includes(action as string);
  // Withdrawal is still allowed after an invitation has been disabled.
  if (action !== "withdraw" && action !== "cancel") await member(uid, admin);
  if (action === "reserve") {
    validateDocument(body.document);
    const r = await rpc("intake_reserve", { p_user: uid, p_doc: body.document });
    if (r.status === "submitted") return { submitted: true, row: r };
    if (Date.now() - Date.parse(r.created_at) > 7 * 86400000) throw Error("revoked");
    const uploads = [];
    for (const p of r.document.photos) {
      if (await validPhoto(r, p)) continue;
      const present = await bucket.info(path(r, p.role));
      if (!present.error) throw Error("invalid_payload");
      const signed = check(await bucket.createSignedUploadUrl(path(r, p.role), { upsert: false }));
      uploads.push({ role: p.role, path: signed!.path, token: signed!.token });
    }
    return { uploads, submitted: false };
  }
  if (action === "finalize") {
    const r = await rowFor(uid, body.id as string);
    if (r.status !== "submitted") {
      for (const p of r.document.photos) if (!await validPhoto(r, p)) throw Error("incomplete");
    }
    return { row: await rpc("intake_finalize", { p_user: uid, p_id: r.id }) };
  }
  if (action === "list" || action === "adminList" || action === "export") {
    let q = client.from("intake_revisions").select("*").eq("status", "submitted").gt("expires_at", new Date().toISOString()).order("submitted_at", { ascending: false });
    if (!admin) q = q.eq("owner_id", uid);
    const tombs = new Set((check(await client.from("intake_tombstones").select("root_id")) ?? []).map(t => t.root_id));
    const rows = (check(await q) ?? []).filter(r => !tombs.has(r.root_id));
    const reviews = admin && rows.length ? check(await client.from("intake_reviews").select("*").in("revision_id", rows.map(r => r.id)).order("id")) : [];
    return { rows, reviews, researchOnly: true, exportedAt: new Date().toISOString() };
  }
  if (action === "photoUrls" || action === "adminPhotoUrls") {
    const r = await rowFor(uid, body.id as string, admin);
    if (r.status !== "submitted") throw Error("incomplete");
    const urls: Record<string, string> = {};
    for (const role of roles) urls[role] = check(await bucket.createSignedUrl(path(r, role), 60))!.signedUrl;
    return { urls };
  }
  if (action === "withdraw") {
    id(body.rootId); await rpc("intake_withdraw", { p_user: uid, p_root: body.rootId });
    const rows = check(await client.from("intake_revisions").select("*").eq("root_id", body.rootId));
    for (const r of rows ?? []) { try { await removeFiles(r); } catch { /* Hourly cleanup retries. */ } }
    return { withdrawn: true };
  }
  if (action === "cancel") {
    id(body.id); await rpc("intake_cancel", { p_user: uid, p_id: body.id }); return { cancelled: true };
  }
  if (action === "review") {
    const r = await rowFor(uid, body.id as string, true);
    if (!["suitable", "uncertain", "unsuitable"].includes(body.outcome as string)) throw Error("invalid_payload");
    validateCorrections(body.corrections, r.document);
    await rpc("intake_review", { p_user: uid, p_id: r.id, p_outcome: body.outcome, p_corrections: body.corrections });
    return { saved: true };
  }
  throw Error("invalid_payload");
}

Deno.serve(async req => {
  if (req.headers.get("origin") && req.headers.get("origin") !== origin) return new Response(null, { status: 403 });
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  const respond = (v: Json, status = 200) => Response.json(v, { status, headers: { ...cors, "Cache-Control": "no-store" } });
  if (req.method !== "POST") return respond({ error: "invalid_payload" }, 405);
  try {
    const token = req.headers.get("authorization")?.replace(/^Bearer /i, "");
    if (!token) throw Error("forbidden");
    const body = await readLimitedJson(req);
    if (body.action === "maintenance") {
      const secret = Deno.env.get("MAINTENANCE_SECRET");
      if (!secret || secret.length < 32 || token !== secret) throw Error("forbidden");
      return respond(await cleanup());
    }
    const { data, error } = await client.auth.getUser(token);
    if (error || !data.user) throw Error("forbidden");
    return respond(await dispatch(data.user.id, body));
  } catch (e) {
    const message = e instanceof Error ? e.message : String((e as Json)?.message ?? "");
    const code = ["forbidden", "invite_invalid", "not_enrolled", "quota", "conflict", "revoked", "invalid_payload", "incomplete", "rate_limit"].find(c => message === c) ?? "unavailable";
    return respond({ error: code }, code === "forbidden" ? 403 : 400);
  }
});
