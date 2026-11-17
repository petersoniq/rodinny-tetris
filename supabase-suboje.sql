-- ============================================================
-- SÚBOJE 1:1 a TÝŽDENNÁ LIGA – rodinný Tetris
-- Spusti RAZ v Supabase Dashboard → SQL Editor (celý súbor).
-- Po spustení sa v sekcii 🏆 Výsledky objavia karty „Týždenná liga" a „Súboje".
-- ============================================================

-- 1) Tabuľka súbojov (prístup len cez funkcie nižšie)
create table if not exists duels (
  id uuid primary key default gen_random_uuid(),
  challenger uuid not null references profiles(id),
  opponent uuid not null references profiles(id),
  seed bigint not null,
  status text not null default 'pending',   -- pending | active | done | declined
  c_score int, c_lines int, c_level int,    -- výsledok vyzývateľa
  o_score int, o_lines int, o_level int,    -- výsledok vyzvaného
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
alter table duels enable row level security;

-- 2) Vytvorenie súboja podľa mena súpera (vráti id + seed kociek)
create or replace function create_duel(p_opponent text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  opp uuid; s bigint; d uuid;
begin
  if p_opponent = (select username from profiles where id = auth.uid()) then
    raise exception 'Sám seba nemôžeš vyzvať.';
  end if;
  select id into opp from profiles where username = p_opponent limit 1;
  if opp is null then raise exception 'Hráč % neexistuje.', p_opponent; end if;
  s := (floor(random() * 2000000000) + 1)::bigint;
  insert into duels (challenger, opponent, seed) values (auth.uid(), opp, s) returning id into d;
  return jsonb_build_object('id', d, 'seed', s);
end; $$;

-- 3) Moje súboje (posledných 20) aj s menami
create or replace function my_duels()
returns table(duel_id uuid, role text, challenger text, opponent text, seed bigint,
              status text, c_score int, c_lines int, c_level int,
              o_score int, o_lines int, o_level int, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select d.id,
         case when d.challenger = auth.uid() then 'c' else 'o' end,
         c.username, o.username, d.seed, d.status,
         d.c_score, d.c_lines, d.c_level, d.o_score, d.o_lines, d.o_level, d.created_at
  from duels d
  join profiles c on c.id = d.challenger
  join profiles o on o.id = d.opponent
  where d.challenger = auth.uid() or d.opponent = auth.uid()
  order by d.created_at desc
  limit 20;
$$;

-- 4) Prijatie výzvy (len vyzvaný, len kým čaká)
create or replace function duel_accept(p_duel uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update duels set status = 'active'
  where id = p_duel and opponent = auth.uid() and status = 'pending';
  if not found then raise exception 'Súboj sa nedá prijať (už nie je aktívny).'; end if;
end; $$;

-- 5) Odmietnutie výzvy
create or replace function duel_decline(p_duel uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update duels set status = 'declined'
  where id = p_duel and opponent = auth.uid() and status = 'pending';
end; $$;

-- 6) Odoslanie výsledku – keď odohrajú obaja, súboj sa uzavrie
create or replace function duel_submit(p_duel uuid, p_score int, p_lines int, p_level int) returns void
language plpgsql security definer set search_path = public as $$
begin
  update duels set c_score = p_score, c_lines = p_lines, c_level = p_level
  where id = p_duel and challenger = auth.uid();
  if not found then
    update duels set o_score = p_score, o_lines = p_lines, o_level = p_level
    where id = p_duel and opponent = auth.uid();
  end if;
  if not found then raise exception 'Súboj neexistuje.'; end if;
  update duels set status = 'done', finished_at = now()
  where id = p_duel and c_score is not null and o_score is not null;
end; $$;

-- 7) TÝŽDENNÁ LIGA – súčet 3 najlepších hier od pondelka tohto týždňa
create or replace function weekly_league()
returns table(username text, color text, total bigint)
language sql stable security definer set search_path = public as $$
  select p.username, p.color, sum(x.score)::bigint as total
  from (
    select s.user_id, s.score,
           row_number() over (partition by s.user_id order by s.score desc) rn
    from scores s
    where s.created_at >= date_trunc('week', now())
  ) x
  join profiles p on p.id = x.user_id
  where x.rn <= 3
  group by p.username, p.color
  order by total desc;
$$;

grant execute on function create_duel(text) to authenticated;
grant execute on function my_duels() to authenticated;
grant execute on function duel_accept(uuid) to authenticated;
grant execute on function duel_decline(uuid) to authenticated;
grant execute on function duel_submit(uuid, int, int, int) to authenticated;
grant execute on function weekly_league() to authenticated;

-- 8) POSLEDNÁ VERZIA APPKY HRÁČA (pre prehľad admina)
alter table profiles add column if not exists app_version text;

create or replace function set_app_version(p_ver text) returns void
language sql security definer set search_path = public as $$
  update profiles set app_version = p_ver where id = auth.uid();
$$;

create or replace function admin_versions()
returns table(id uuid, app_version text)
language sql stable security definer set search_path = public as $$
  select id, app_version from profiles order by username;
$$;

grant execute on function set_app_version(text) to authenticated;
grant execute on function admin_versions() to authenticated;
