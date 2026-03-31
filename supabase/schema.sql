-- Supabase schema for Steel Group Laser desktop explorer
-- Run in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.folders (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  parent_id uuid references public.folders (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 255),
  path text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  folder_id uuid not null references public.folders (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 255),
  extension text not null default '',
  mime_type text,
  size_bytes bigint not null default 0 check (size_bytes >= 0),
  storage_path text not null unique,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_folders_owner_parent on public.folders (owner_id, parent_id);
create index if not exists idx_folders_owner_path on public.folders (owner_id, path);
create unique index if not exists uq_root_folder_name
  on public.folders (owner_id, lower(name))
  where parent_id is null;
create unique index if not exists uq_child_folder_name
  on public.folders (owner_id, parent_id, lower(name))
  where parent_id is not null;

create index if not exists idx_files_owner_folder on public.files (owner_id, folder_id);
create unique index if not exists uq_files_name_per_folder
  on public.files (owner_id, folder_id, lower(name));

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

create or replace function public.set_folder_path()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  parent_owner uuid;
  parent_path text;
begin
  if new.parent_id is not null then
    select owner_id, path
    into parent_owner, parent_path
    from public.folders
    where id = new.parent_id;

    if parent_owner is null then
      raise exception 'Parent folder not found';
    end if;

    if parent_owner <> new.owner_id then
      raise exception 'Parent folder must belong to the same owner';
    end if;

    if tg_op = 'UPDATE' then
      if new.parent_id = old.id then
        raise exception 'Folder cannot be parent of itself';
      end if;

      if exists (
        with recursive descendants as (
          select id
          from public.folders
          where parent_id = old.id
          union all
          select f.id
          from public.folders f
          join descendants d on d.id = f.parent_id
        )
        select 1
        from descendants
        where id = new.parent_id
      ) then
        raise exception 'Cannot move folder into its own descendant';
      end if;
    end if;

    new.path := parent_path || '/' || new.name;
  else
    new.path := '/' || new.name;
  end if;

  return new;
end;
$$;

create or replace function public.propagate_folder_path_change()
returns trigger
language plpgsql
as $$
begin
  if new.path is distinct from old.path then
    update public.folders
    set
      path = new.path || substr(path, char_length(old.path) + 1),
      updated_at = timezone('utc', now())
    where owner_id = new.owner_id
      and path like old.path || '/%';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_folders_set_path on public.folders;
create trigger trg_folders_set_path
before insert or update of name, parent_id
on public.folders
for each row
execute function public.set_folder_path();

drop trigger if exists trg_folders_touch_updated_at on public.folders;
create trigger trg_folders_touch_updated_at
before update
on public.folders
for each row
execute function public.touch_updated_at();

drop trigger if exists trg_files_touch_updated_at on public.files;
create trigger trg_files_touch_updated_at
before update
on public.files
for each row
execute function public.touch_updated_at();

drop trigger if exists trg_folders_propagate_path on public.folders;
create trigger trg_folders_propagate_path
after update of path
on public.folders
for each row
execute function public.propagate_folder_path_change();

create or replace function public.ensure_user_root_folder(root_name text default 'Home')
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  existing_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select id
  into existing_id
  from public.folders
  where owner_id = auth.uid()
    and parent_id is null
  limit 1;

  if existing_id is not null then
    return existing_id;
  end if;

  insert into public.folders (owner_id, parent_id, name, path)
  values (auth.uid(), null, coalesce(nullif(trim(root_name), ''), 'Home'), '')
  returning id into existing_id;

  return existing_id;
end;
$$;

create or replace function public.list_folder_storage_paths(target_folder uuid)
returns table (storage_path text)
language sql
security invoker
set search_path = public
as $$
  with recursive folders_tree as (
    select f.id
    from public.folders f
    where f.id = target_folder
      and f.owner_id = auth.uid()
    union all
    select c.id
    from public.folders c
    join folders_tree ft on ft.id = c.parent_id
    where c.owner_id = auth.uid()
  )
  select file.storage_path
  from public.files file
  join folders_tree ft on ft.id = file.folder_id
  where file.owner_id = auth.uid();
$$;

create or replace function public.create_user_folder(
  folder_name text,
  folder_parent_id uuid default null
)
returns public.folders
language plpgsql
security definer
set search_path = public
as $$
declare
  created_row public.folders;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if folder_parent_id is not null then
    if not exists (
      select 1
      from public.folders parent
      where parent.id = folder_parent_id
        and parent.owner_id = auth.uid()
    ) then
      raise exception 'Parent folder not found or access denied';
    end if;
  end if;

  insert into public.folders (owner_id, parent_id, name, path)
  values (
    auth.uid(),
    folder_parent_id,
    coalesce(nullif(trim(folder_name), ''), 'Новая папка'),
    ''
  )
  returning * into created_row;

  return created_row;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.folders (owner_id, parent_id, name, path)
  values (new.id, null, 'Home', '')
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

alter table public.folders enable row level security;
alter table public.files enable row level security;

revoke all on public.folders from anon;
revoke all on public.files from anon;

drop policy if exists folders_select_own on public.folders;
create policy folders_select_own
on public.folders
for select
to authenticated
using (owner_id = auth.uid());

drop policy if exists folders_insert_own on public.folders;
create policy folders_insert_own
on public.folders
for insert
to authenticated
with check (
  owner_id = auth.uid()
  and (
    parent_id is null
    or exists (
      select 1
      from public.folders parent
      where parent.id = parent_id
        and parent.owner_id = auth.uid()
    )
  )
);

drop policy if exists folders_update_own on public.folders;
create policy folders_update_own
on public.folders
for update
to authenticated
using (owner_id = auth.uid())
with check (
  owner_id = auth.uid()
  and (
    parent_id is null
    or exists (
      select 1
      from public.folders parent
      where parent.id = parent_id
        and parent.owner_id = auth.uid()
    )
  )
);

drop policy if exists folders_delete_own on public.folders;
create policy folders_delete_own
on public.folders
for delete
to authenticated
using (owner_id = auth.uid());

drop policy if exists files_select_own on public.files;
create policy files_select_own
on public.files
for select
to authenticated
using (owner_id = auth.uid());

drop policy if exists files_insert_own on public.files;
create policy files_insert_own
on public.files
for insert
to authenticated
with check (
  owner_id = auth.uid()
  and exists (
    select 1
    from public.folders folder_ref
    where folder_ref.id = folder_id
      and folder_ref.owner_id = auth.uid()
  )
);

drop policy if exists files_update_own on public.files;
create policy files_update_own
on public.files
for update
to authenticated
using (owner_id = auth.uid())
with check (
  owner_id = auth.uid()
  and exists (
    select 1
    from public.folders folder_ref
    where folder_ref.id = folder_id
      and folder_ref.owner_id = auth.uid()
  )
);

drop policy if exists files_delete_own on public.files;
create policy files_delete_own
on public.files
for delete
to authenticated
using (owner_id = auth.uid());

grant select, insert, update, delete on public.folders to authenticated;
grant select, insert, update, delete on public.files to authenticated;
grant execute on function public.ensure_user_root_folder(text) to authenticated;
grant execute on function public.list_folder_storage_paths(uuid) to authenticated;
grant execute on function public.create_user_folder(text, uuid) to authenticated;

insert into storage.buckets (id, name, public)
values ('explorer-files', 'explorer-files', false)
on conflict (id) do update set public = excluded.public;

drop policy if exists storage_select_own on storage.objects;
create policy storage_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'explorer-files'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists storage_insert_own on storage.objects;
create policy storage_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'explorer-files'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists storage_update_own on storage.objects;
create policy storage_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'explorer-files'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'explorer-files'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists storage_delete_own on storage.objects;
create policy storage_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'explorer-files'
  and (storage.foldername(name))[1] = auth.uid()::text
);
