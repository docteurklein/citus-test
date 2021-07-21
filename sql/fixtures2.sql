\set ON_ERROR_STOP 1
\timing on

set search_path = pim, ext;

begin;

-- create table public.episode ("episode_id" text primary key,"season_num" text,"episode_name" text,"content_id" text,"release_date" text,"episode_rating" text,"episode_num" text,"description" text,"last_updated" text,"episode_imdb_link" text,"episode_score_votes" text);
--
-- copy public.episode
-- from program 'curl https://raw.githubusercontent.com/raosaif/sample_postgresql_database/master/from_csv/csv_files/episode_list.csv'
-- delimiter ',' csv header;

with ep as (
select * from public.episode limit 100
)
insert into product (family_id, values, tenant_id)
select f.family_id, jsonb_object_agg(episode_name, description), f.tenant_id
from family f
join attribute a using (tenant_id),
ep,
-- select array_length(array_agg(description),1) from episode group by season_num, content_id limit 20;
generate_series(1, 10) i
group by f.family_id, f.tenant_id, season_num, content_id;

commit;
