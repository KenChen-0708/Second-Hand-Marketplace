alter table public.users
  add column if not exists is_online boolean not null default false,
  add column if not exists last_seen_at timestamptz;

create index if not exists idx_users_is_online on public.users(is_online);
