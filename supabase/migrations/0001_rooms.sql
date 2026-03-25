create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'New user',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  invite_code char(4) not null unique check (invite_code ~ '^[0-9]{4}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table if not exists public.room_invites (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  code char(4) not null check (code ~ '^[0-9]{4}$'),
  created_by uuid not null references public.profiles(id) on delete cascade,
  expires_at timestamptz,
  max_uses integer check (max_uses is null or max_uses > 0),
  uses_count integer not null default 0,
  created_at timestamptz not null default now(),
  unique (room_id, code)
);

create index if not exists idx_room_members_user_id on public.room_members(user_id);
create index if not exists idx_room_members_room_id on public.room_members(room_id);
create index if not exists idx_room_invites_code on public.room_invites(code);

create table if not exists public.room_events (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_room_events_room_created on public.room_events(room_id, created_at desc);

create or replace function public.generate_4_digit_code()
returns char(4)
language plpgsql
as $$
declare
  candidate char(4);
begin
  loop
    candidate := lpad((floor(random() * 10000))::int::text, 4, '0');
    exit when not exists (
      select 1 from public.rooms r where r.invite_code = candidate
    );
  end loop;
  return candidate;
end;
$$;

create or replace function public.ensure_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', 'New user'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.ensure_profile();

create or replace function public.create_room(input_name text)
returns public.rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  new_room public.rooms;
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'Unauthenticated';
  end if;

  if input_name is null or char_length(trim(input_name)) = 0 then
    raise exception 'Room name required';
  end if;

  insert into public.rooms (name, owner_id, invite_code)
  values (trim(input_name), caller, public.generate_4_digit_code())
  returning * into new_room;

  insert into public.room_members (room_id, user_id, role)
  values (new_room.id, caller, 'owner');

  insert into public.room_events (room_id, actor_id, event_type, payload)
  values (new_room.id, caller, 'room_created', jsonb_build_object('room_name', new_room.name));

  return new_room;
end;
$$;

create or replace function public.join_room_by_code(input_code text)
returns public.rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  target_room public.rooms;
  caller uuid := auth.uid();
  normalized_code char(4);
begin
  if caller is null then
    raise exception 'Unauthenticated';
  end if;

  normalized_code := lpad(regexp_replace(coalesce(input_code, ''), '[^0-9]', '', 'g'), 4, '0')::char(4);

  select *
  into target_room
  from public.rooms
  where invite_code = normalized_code
    and is_active = true
  limit 1;

  if target_room.id is null then
    raise exception 'Room not found';
  end if;

  insert into public.room_members (room_id, user_id, role)
  values (target_room.id, caller, 'member')
  on conflict (room_id, user_id) do nothing;

  insert into public.room_events (room_id, actor_id, event_type, payload)
  values (target_room.id, caller, 'member_joined', '{}'::jsonb);

  return target_room;
end;
$$;

create or replace function public.remove_room_member(input_room_id uuid, input_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := auth.uid();
  caller_role text;
  target_role text;
begin
  if caller is null then
    raise exception 'Unauthenticated';
  end if;

  select role into caller_role
  from public.room_members
  where room_id = input_room_id and user_id = caller;

  if caller_role not in ('owner', 'admin') then
    raise exception 'Forbidden';
  end if;

  select role into target_role
  from public.room_members
  where room_id = input_room_id and user_id = input_user_id;

  if target_role = 'owner' and caller_role <> 'owner' then
    raise exception 'Only owner can remove owner';
  end if;

  delete from public.room_members
  where room_id = input_room_id and user_id = input_user_id;

  insert into public.room_events (room_id, actor_id, event_type, payload)
  values (
    input_room_id,
    caller,
    'member_removed',
    jsonb_build_object('removed_user_id', input_user_id)
  );
end;
$$;

create or replace function public.delete_room(input_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := auth.uid();
  caller_role text;
begin
  if caller is null then
    raise exception 'Unauthenticated';
  end if;

  select role into caller_role
  from public.room_members
  where room_id = input_room_id and user_id = caller;

  if caller_role <> 'owner' then
    raise exception 'Only owner can delete room';
  end if;

  delete from public.rooms where id = input_room_id;
end;
$$;

alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.room_invites enable row level security;
alter table public.room_events enable row level security;

drop policy if exists "profiles_read_own" on public.profiles;
create policy "profiles_read_own"
on public.profiles
for select
to authenticated
using (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "rooms_select_if_member" on public.rooms;
create policy "rooms_select_if_member"
on public.rooms
for select
to authenticated
using (
  exists (
    select 1
    from public.room_members rm
    where rm.room_id = rooms.id and rm.user_id = auth.uid()
  )
);

drop policy if exists "rooms_insert_owner" on public.rooms;
create policy "rooms_insert_owner"
on public.rooms
for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists "rooms_update_owner_or_admin" on public.rooms;
create policy "rooms_update_owner_or_admin"
on public.rooms
for update
to authenticated
using (
  exists (
    select 1
    from public.room_members rm
    where rm.room_id = rooms.id
      and rm.user_id = auth.uid()
      and rm.role in ('owner', 'admin')
  )
);

drop policy if exists "rooms_delete_owner" on public.rooms;
create policy "rooms_delete_owner"
on public.rooms
for delete
to authenticated
using (
  exists (
    select 1
    from public.room_members rm
    where rm.room_id = rooms.id
      and rm.user_id = auth.uid()
      and rm.role = 'owner'
  )
);

drop policy if exists "room_members_select_if_member" on public.room_members;
create policy "room_members_select_if_member"
on public.room_members
for select
to authenticated
using (
  exists (
    select 1
    from public.room_members rm
    where rm.room_id = room_members.room_id
      and rm.user_id = auth.uid()
  )
);

drop policy if exists "room_members_insert_owner_or_admin" on public.room_members;
create policy "room_members_insert_owner_or_admin"
on public.room_members
for insert
to authenticated
with check (
  exists (
    select 1
    from public.room_members rm
    where rm.room_id = room_members.room_id
      and rm.user_id = auth.uid()
      and rm.role in ('owner', 'admin')
  )
);

drop policy if exists "room_members_delete_owner_or_admin" on public.room_members;
create policy "room_members_delete_owner_or_admin"
on public.room_members
for delete
to authenticated
using (
  exists (
    select 1
    from public.room_members rm
    where rm.room_id = room_members.room_id
      and rm.user_id = auth.uid()
      and rm.role in ('owner', 'admin')
  )
);

drop policy if exists "room_invites_read_if_member" on public.room_invites;
create policy "room_invites_read_if_member"
on public.room_invites
for select
to authenticated
using (
  exists (
    select 1
    from public.room_members rm
    where rm.room_id = room_invites.room_id
      and rm.user_id = auth.uid()
  )
);

drop policy if exists "room_invites_write_admin" on public.room_invites;
create policy "room_invites_write_admin"
on public.room_invites
for all
to authenticated
using (
  exists (
    select 1
    from public.room_members rm
    where rm.room_id = room_invites.room_id
      and rm.user_id = auth.uid()
      and rm.role in ('owner', 'admin')
  )
)
with check (
  exists (
    select 1
    from public.room_members rm
    where rm.room_id = room_invites.room_id
      and rm.user_id = auth.uid()
      and rm.role in ('owner', 'admin')
  )
);

drop policy if exists "room_events_read_if_member" on public.room_events;
create policy "room_events_read_if_member"
on public.room_events
for select
to authenticated
using (
  exists (
    select 1
    from public.room_members rm
    where rm.room_id = room_events.room_id
      and rm.user_id = auth.uid()
  )
);
