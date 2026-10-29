-- ============================================================
-- Bonifikácie rodinného Tetrisu – globálne nastavenia pre celú rodinu
-- Spusti raz v Supabase Dashboard → SQL Editor.
-- Po spustení môže admin meniť bonifikácie v aplikácii ( záložka 🎁 ).
-- ============================================================

create table if not exists game_settings (
  k text primary key,
  v jsonb not null
);
alter table game_settings enable row level security;
-- žiadne RLS politiky: k tabuľke sa pristupuje len cez funkcie nižšie

-- čítanie pre všetkých (aj neprihlásených)
create or replace function family_bonuses() returns jsonb
language sql stable security definer set search_path = public as $$
  select v from game_settings where k = 'bonuses';
$$;

-- zápis len pre admina
create or replace function admin_set_bonuses(p_data jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and is_admin) then
    raise exception 'Len admin môže meniť bonifikácie.';
  end if;
  insert into game_settings (k, v) values ('bonuses', p_data)
  on conflict (k) do update set v = excluded.v;
end;
$$;

grant execute on function family_bonuses() to anon, authenticated;
grant execute on function admin_set_bonuses(jsonb) to authenticated;
