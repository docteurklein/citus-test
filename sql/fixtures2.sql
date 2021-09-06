\set ON_ERROR_STOP 1
\timing on

set search_path = pim, ext;

begin;

-- create table public.episode ("episode_id" text primary key,"season_num" text,"episode_name" text,"content_id" text,"release_date" text,"episode_rating" text,"episode_num" text,"description" text,"last_updated" text,"episode_imdb_link" text,"episode_score_votes" text);
--
-- copy public.episode
-- from program 'curl https://raw.githubusercontent.com/raosaif/sample_postgresql_database/master/from_csv/csv_files/episode_list.csv'
-- delimiter ',' csv header;

truncate product cascade;

-- with strings as (
--     select jsonb_object_agg(a.name, description) s
--     from attribute a,
--     (select *, random() from public.episode order by random() limit 10) ep
--     group by season_num, content_id
-- )
insert into product (family_id, tenant_id, values)
select f.family_id, f.tenant_id, jsonb_build_object('text_attribute', jsonb_object_agg(a.name, (select description || i from public.episode order by random() limit 1)))
from family f
join attribute a using (tenant_id),
generate_series(1, 8) i
-- public.episode
group by i, f.family_id, tenant_id;

commit;
