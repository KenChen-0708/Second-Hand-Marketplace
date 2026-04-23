alter table public.users
  add column if not exists push_enabled boolean not null default false,
  add column if not exists fcm_token text;

create index if not exists idx_users_push_enabled on public.users(push_enabled);
