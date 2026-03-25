create or replace function public.is_room_member(input_room_id uuid, input_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.room_members rm
    where rm.room_id = input_room_id
      and rm.user_id = input_user_id
  );
$$;

create or replace function public.is_room_admin_or_owner(input_room_id uuid, input_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.room_members rm
    where rm.room_id = input_room_id
      and rm.user_id = input_user_id
      and rm.role in ('owner', 'admin')
  );
$$;

drop policy if exists "room_members_select_if_member" on public.room_members;
create policy "room_members_select_if_member"
on public.room_members
for select
to authenticated
using (
  public.is_room_member(room_members.room_id, auth.uid())
);

drop policy if exists "room_members_insert_owner_or_admin" on public.room_members;
create policy "room_members_insert_owner_or_admin"
on public.room_members
for insert
to authenticated
with check (
  public.is_room_admin_or_owner(room_members.room_id, auth.uid())
);

drop policy if exists "room_members_delete_owner_or_admin" on public.room_members;
create policy "room_members_delete_owner_or_admin"
on public.room_members
for delete
to authenticated
using (
  public.is_room_admin_or_owner(room_members.room_id, auth.uid())
);
