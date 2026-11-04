-- Graut kåringen: database for Supabase (køyrd på prosjektet graut-kaaringen)
create table rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  decade int not null,
  phase text not null default 'lobby' check (phase in ('lobby','pitch','play','vote','reveal','done')),
  idx int not null default 0,
  "order" jsonb not null default '[]',
  created_at timestamptz not null default now()
);
create table players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms on delete cascade,
  name text not null
);
create unique index players_room_name on players (room_id, lower(name));
create table songs (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms on delete cascade,
  player_id uuid not null references players on delete cascade,
  artist text not null, title text not null, year int not null,
  yt text not null check (yt ~ '^[A-Za-z0-9_-]{11}$')
);
create index songs_room on songs(room_id);
create index songs_player on songs(player_id);
create table votes (
  room_id uuid not null references rooms on delete cascade,
  player_id uuid not null references players on delete cascade,
  song_id uuid not null references songs on delete cascade,
  score int not null check (score between 1 and 6),
  primary key (player_id, song_id)
);
create index votes_room on votes(room_id);
create index votes_song on votes(song_id);
create index players_room on players(room_id);

-- Maks to seksere per deltaker (man kan stemme på egen låt)
create function check_vote() returns trigger language plpgsql set search_path = public as $$
begin
  if new.score = 6 and (select count(*) from votes where player_id = new.player_id and score = 6 and song_id <> new.song_id) >= 2 then
    raise exception 'Du har brukt begge seksene';
  end if;
  return new;
end $$;
create trigger votes_check before insert or update on votes for each row execute function check_vote();

-- Ope for alle med lenkja (festspel, ingen kontoar). Ingen kan slette via sida.
alter table rooms enable row level security;
alter table players enable row level security;
alter table songs enable row level security;
alter table votes enable row level security;
create policy open_rooms_read on rooms for select to anon using (true);
create policy open_rooms_add on rooms for insert to anon with check (true);
create policy open_rooms_update on rooms for update to anon using (true) with check (true);
create policy open_players on players for select to anon using (true);
create policy add_players on players for insert to anon with check (true);
create policy open_songs on songs for select to anon using (true);
create policy add_songs on songs for insert to anon with check (true);
create policy open_votes on votes for select to anon using (true);
create policy add_votes on votes for insert to anon with check (true);
create policy change_votes on votes for update to anon using (true) with check (true);

alter publication supabase_realtime add table rooms, players, songs, votes;
