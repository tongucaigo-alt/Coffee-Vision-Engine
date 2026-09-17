-- App-specific research intake. No Atlas Source/Symbol admission is represented.
create table public.intake_admins (user_id uuid primary key references auth.users(id));
create table public.intake_invites (
  code_hash text primary key check (code_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null default now() + interval '30 days',
  redeemed_by uuid unique references auth.users(id), revoked boolean not null default false
);
create table public.intake_members (
  user_id uuid primary key references auth.users(id), active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.intake_roots (
  id uuid primary key, owner_id uuid not null references auth.users(id), group_id uuid not null,
  created_at timestamptz not null default now(), expires_at timestamptz not null default now() + interval '180 days',
  withdrawn_at timestamptz
);
create table public.intake_revisions (
  id uuid primary key, root_id uuid not null references public.intake_roots(id),
  owner_id uuid not null references auth.users(id), group_id uuid not null,
  revision int not null check (revision > 0), supersedes_id uuid references public.intake_revisions(id),
  document jsonb, status text not null default 'reserved'
    check (status in ('reserved','submitted','superseded','withdrawn','cancelled','purged')),
  reserved_bytes bigint not null default 15728640,
  created_at timestamptz not null default now(), submitted_at timestamptz,
  expires_at timestamptz not null,
  check (reserved_bytes >= 0)
);
create unique index intake_live_revision on public.intake_revisions(root_id, revision)
 where status in ('reserved','submitted','superseded');
create table public.intake_reviews (
  id bigint generated always as identity primary key,
  revision_id uuid not null references public.intake_revisions(id), reviewer_id uuid not null references auth.users(id),
  outcome text not null check (outcome in ('suitable','uncertain','unsuitable')),
  corrections jsonb not null default '[]', created_at timestamptz not null default now()
);
create table public.intake_tombstones (
  root_id uuid primary key references public.intake_roots(id), owner_id uuid not null,
  deleted_at timestamptz not null default now()
);
create table public.intake_rate_limits (
  user_id uuid not null, window_at timestamptz not null, requests int not null,
  primary key(user_id,window_at)
);
create index intake_owner_idx on public.intake_revisions(owner_id, status);

alter table public.intake_admins enable row level security;
alter table public.intake_invites enable row level security;
alter table public.intake_members enable row level security;
alter table public.intake_roots enable row level security;
alter table public.intake_revisions enable row level security;
alter table public.intake_reviews enable row level security;
alter table public.intake_tombstones enable row level security;
alter table public.intake_rate_limits enable row level security;
revoke all on public.intake_admins, public.intake_invites, public.intake_members,
 public.intake_roots, public.intake_revisions, public.intake_reviews,
 public.intake_tombstones, public.intake_rate_limits from anon, authenticated;
grant all on public.intake_admins, public.intake_invites, public.intake_members,
 public.intake_roots, public.intake_revisions, public.intake_reviews,
 public.intake_tombstones, public.intake_rate_limits to service_role;
grant usage, select on sequence public.intake_reviews_id_seq to service_role;

create function public.intake_rate(p_user uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare n int; w timestamptz := to_timestamp(floor(extract(epoch from now())/300)*300);
begin
  insert into intake_rate_limits values(p_user,w,1) on conflict(user_id,window_at)
    do update set requests=intake_rate_limits.requests+1 returning requests into n;
  return n <= 100;
end $$;

create function public.intake_enroll(p_user uuid,p_hash text) returns void
language plpgsql security definer set search_path = public as $$
declare invite intake_invites;
begin
  perform pg_advisory_xact_lock(7345001);
  if exists(select 1 from intake_members where user_id=p_user and active) then return; end if;
  select * into invite from intake_invites where code_hash=p_hash for update;
  if not found or invite.revoked or invite.expires_at <= now() or
    (invite.redeemed_by is not null and invite.redeemed_by <> p_user) then raise exception 'invite_invalid'; end if;
  if (select count(*) from intake_members) >= 10 then raise exception 'quota'; end if;
  update intake_invites set redeemed_by=p_user where code_hash=p_hash;
  insert into intake_members(user_id) values(p_user);
end $$;

create function public.intake_reserve(p_user uuid,p_doc jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare existing intake_revisions; parent intake_revisions; r intake_roots;
  key_id uuid := (p_doc->>'id')::uuid; root uuid := (p_doc->>'rootId')::uuid;
  grp uuid := (p_doc->>'groupId')::uuid; rev int := (p_doc->>'revision')::int;
begin
  perform pg_advisory_xact_lock(7345001);
  if not exists(select 1 from intake_members where user_id=p_user and active) then raise exception 'not_enrolled'; end if;
  if exists(select 1 from intake_tombstones where root_id=root) then raise exception 'revoked'; end if;
  select * into existing from intake_revisions where id=key_id;
  if found then
    if existing.owner_id <> p_user then raise exception 'forbidden'; end if;
    if existing.status not in ('reserved','submitted') or existing.expires_at<=now() then raise exception 'revoked'; end if;
    if existing.document <> p_doc then raise exception 'conflict'; end if;
    return to_jsonb(existing);
  end if;
  if exists(select 1 from intake_roots where group_id=grp and owner_id<>p_user) then raise exception 'forbidden'; end if;
  select * into r from intake_roots where id=root;
  if rev=1 then
    if found or key_id <> root or p_doc->>'supersedesId' is not null then raise exception 'conflict'; end if;
    if (select count(distinct root_id) from intake_revisions where submitted_at is not null or status='reserved') >= 30 or
      (select count(distinct root_id) from intake_revisions where owner_id=p_user and (submitted_at is not null or status='reserved')) >= 3 then
      raise exception 'quota'; end if;
    insert into intake_roots(id,owner_id,group_id) values(root,p_user,grp) returning * into r;
  else
    if not found or r.owner_id<>p_user or r.group_id<>grp or r.expires_at<=now() or r.withdrawn_at is not null then raise exception 'revoked'; end if;
    select * into parent from intake_revisions where id=(p_doc->>'supersedesId')::uuid;
    if not found or parent.root_id<>root or parent.status<>'submitted' or rev<>parent.revision+1 or
      exists(select 1 from intake_revisions where root_id=root and status='reserved') then raise exception 'conflict'; end if;
  end if;
  if (select coalesce(sum(reserved_bytes),0) from intake_revisions where status<>'purged') + 15728640 > 629145600 then raise exception 'quota'; end if;
  insert into intake_revisions(id,root_id,owner_id,group_id,revision,supersedes_id,document,expires_at)
    values(key_id,root,p_user,grp,rev,(p_doc->>'supersedesId')::uuid,p_doc,r.expires_at) returning * into existing;
  return to_jsonb(existing);
end $$;

create function public.intake_finalize(p_user uuid,p_id uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare r intake_revisions;
begin
  perform pg_advisory_xact_lock(7345001);
  select * into r from intake_revisions where id=p_id for update;
  if not found or r.owner_id<>p_user then raise exception 'forbidden'; end if;
  if r.expires_at<=now() or exists(select 1 from intake_tombstones where root_id=r.root_id) or r.status not in ('reserved','submitted') then raise exception 'revoked'; end if;
  if not exists(select 1 from intake_members where user_id=p_user and active) then raise exception 'not_enrolled'; end if;
  if r.status='submitted' then return to_jsonb(r); end if;
  if r.supersedes_id is not null then
    update intake_revisions set status='superseded' where id=r.supersedes_id and status='submitted';
    if not found then raise exception 'conflict'; end if;
  end if;
  update intake_revisions set status='submitted',submitted_at=now() where id=p_id returning * into r;
  return to_jsonb(r);
end $$;

create function public.intake_withdraw(p_user uuid,p_root uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform pg_advisory_xact_lock(7345001);
  if not exists(select 1 from intake_roots where id=p_root and owner_id=p_user) then raise exception 'forbidden'; end if;
  insert into intake_tombstones(root_id,owner_id) values(p_root,p_user) on conflict do nothing;
  update intake_roots set withdrawn_at=coalesce(withdrawn_at,now()) where id=p_root;
  update intake_revisions set status='withdrawn' where root_id=p_root and status<>'purged';
end $$;

create function public.intake_can_read(p_name text) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from intake_revisions r
   where (p_name=r.owner_id::text||'/'||r.id::text||'/top.jpg'
      or p_name=r.owner_id::text||'/'||r.id::text||'/handleRight.jpg'
      or p_name=r.owner_id::text||'/'||r.id::text||'/handleLeft.jpg')
     and r.status='submitted' and r.expires_at>now()
     and not exists(select 1 from intake_tombstones t where t.root_id=r.root_id)
     and (r.owner_id=auth.uid() or exists(select 1 from intake_admins a where a.user_id=auth.uid())))
$$;

revoke all on function public.intake_rate(uuid), public.intake_enroll(uuid,text),
 public.intake_reserve(uuid,jsonb),public.intake_finalize(uuid,uuid),public.intake_withdraw(uuid,uuid)
 from public, anon, authenticated;
grant execute on function public.intake_rate(uuid), public.intake_enroll(uuid,text),
 public.intake_reserve(uuid,jsonb),public.intake_finalize(uuid,uuid),public.intake_withdraw(uuid,uuid) to service_role;
revoke all on function public.intake_can_read(text) from public,anon;
grant execute on function public.intake_can_read(text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('contributions','contributions',false,5242880,array['image/jpeg']);
create policy contribution_private_read on storage.objects for select to authenticated
 using(bucket_id='contributions' and public.intake_can_read(name));
-- Uploads use short-lived, exact-path signed tokens issued only after reservation.

create function public.intake_cancel(p_user uuid,p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform pg_advisory_xact_lock(7345001);
  if exists(select 1 from intake_revisions where id=p_id and owner_id=p_user and status='submitted') then raise exception 'conflict'; end if;
  if exists(select 1 from intake_revisions where id=p_id and owner_id<>p_user) then raise exception 'forbidden'; end if;
  update intake_revisions set status='cancelled' where id=p_id and owner_id=p_user and status='reserved';
end $$;

create function public.intake_review(p_user uuid,p_id uuid,p_outcome text,p_corrections jsonb) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform pg_advisory_xact_lock(7345001);
  if not exists(select 1 from intake_admins where user_id=p_user) then raise exception 'forbidden'; end if;
  if not exists(select 1 from intake_revisions r where r.id=p_id and r.status='submitted'
    and r.expires_at>now() and not exists(select 1 from intake_tombstones t where t.root_id=r.root_id)) then raise exception 'revoked'; end if;
  insert into intake_reviews(revision_id,reviewer_id,outcome,corrections) values(p_id,p_user,p_outcome,p_corrections);
end $$;

create function public.intake_expire() returns void
language plpgsql security definer set search_path=public as $$
begin
  perform pg_advisory_xact_lock(7345001);
  insert into intake_tombstones(root_id,owner_id)
    select id,owner_id from intake_roots where expires_at<=now() on conflict do nothing;
  update intake_roots set withdrawn_at=coalesce(withdrawn_at,now()) where expires_at<=now();
  update intake_revisions set status='withdrawn' where status<>'purged'
    and root_id in (select root_id from intake_tombstones);
  update intake_revisions set status='cancelled' where status='reserved' and created_at<now()-interval '7 days';
  delete from intake_rate_limits where window_at<now()-interval '1 day';
end $$;
revoke all on function public.intake_cancel(uuid,uuid), public.intake_review(uuid,uuid,text,jsonb),public.intake_expire() from public,anon,authenticated;
grant execute on function public.intake_cancel(uuid,uuid), public.intake_review(uuid,uuid,text,jsonb),public.intake_expire() to service_role;
