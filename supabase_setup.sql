-- Meu Roteiro: backend simples de sincronização para Supabase
-- Execute este script uma única vez no SQL Editor do seu projeto Supabase.

create table if not exists public.shared_trips (
  id uuid primary key default gen_random_uuid(),
  share_code text unique not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.shared_trips enable row level security;

-- Não crie políticas diretas para anon/authenticated.
-- O acesso acontece somente pelas funções abaixo, usando o código compartilhado como segredo.

create or replace function public.load_trip(p_code text)
returns table(data jsonb, updated_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select s.data, s.updated_at
  from public.shared_trips s
  where s.share_code = p_code
  limit 1;
$$;

create or replace function public.save_trip(p_code text, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.shared_trips(share_code, data, updated_at)
  values (p_code, p_data, now())
  on conflict (share_code)
  do update set data = excluded.data, updated_at = now();
end;
$$;

revoke all on table public.shared_trips from anon, authenticated;
grant execute on function public.load_trip(text) to anon, authenticated;
grant execute on function public.save_trip(text, jsonb) to anon, authenticated;
