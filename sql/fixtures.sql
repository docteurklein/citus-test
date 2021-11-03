\set ON_ERROR_STOP 1
\timing on

create extension if not exists tsm_system_rows with schema ext;
set search_path = pim, ext;

begin;
truncate tenant cascade;

insert into tenant (name)
select 'tenant#' || i
from generate_series(1, 10) i;

insert into family (name, tenant_id)
select 'family#' || i, tenant_id
from tenant, generate_series(1, 5) i;

with some_type (type) as (
    values ('text'), ('number'), ('select')
)
insert into attribute (name, type, tenant_id)
select 'attribute#' || i, type, tenant_id
from tenant, generate_series(1, 10) i, some_type;

insert into channel (name, tenant_id)
select 'channel#' || i, tenant_id
from tenant, generate_series(1, 10) i;

with some_lang (lang) as (
    values ('english'), ('french')
)
insert into locale (locale_id, name, tenant_id)
select lang, lang, tenant_id
from tenant, some_lang;

insert into family_has_attribute (family_id, attribute_id, tenant_id)
select f.family_id, a.attribute_id, f.tenant_id
from family f join attribute a using (tenant_id);

insert into product (family_id, tenant_id)
select f.family_id, f.tenant_id
from family f, generate_series(1, 1000) i;

drop table if exists sample_episode;
create table sample_episode (
    episode_id text primary key,
    season_num text,
    episode_name text,
    content_id text,
    release_date text,
    episode_rating text,
    episode_num text,
    description text,
    last_updated text,
    episode_imdb_link text,
    episode_score_votes text
);
copy sample_episode
from program 'curl https://raw.githubusercontent.com/raosaif/sample_postgresql_database/master/from_csv/csv_files/episode_list.csv'
delimiter ',' csv header;

select create_reference_table('sample_episode');

insert into product_value (product_id, attribute_id, channel_id, locale_id, tenant_id, value)
select p.product_id, a.attribute_id, c.channel_id, l.locale_id, t.tenant_id,
(select jsonb_build_object('content', description)->'content' from sample_episode tablesample system_rows(1))
from tenant t
join product p using (tenant_id)
join attribute a using (tenant_id)
join channel c using (tenant_id)
join locale l using (tenant_id)
where a.type = 'text'
limit 100000;

with c1 as (
    insert into category (name, tenant_id)
    select 'category#' || i, tenant_id
    from tenant, generate_series(1, 5) i
    returning category_id, tenant_id
), c2 as (
    insert into category (name, parent_id, tenant_id)
    select 'sub category#' || i, c1.category_id, c1.tenant_id
    from c1, generate_series(6, 8) i
    returning category_id, tenant_id
), c3 as (
    insert into category (name, parent_id, tenant_id)
    select 'sub sub category#' || i, c2.category_id, c2.tenant_id
    from c2, generate_series(13, 15) i
    returning category_id
), c as (
    select category_id, tenant_id from category order by random() limit 10
), p as (
    select product_id, category_id, tenant_id from product join c using (tenant_id) order by random()
)
insert into product_in_category (product_id, category_id, tenant_id)
select product_id, category_id, tenant_id
from p;

commit;
