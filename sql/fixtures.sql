\set ON_ERROR_STOP 1
\timing on

set search_path = pim, ext;

begin;
truncate tenant cascade;

insert into tenant (name)
select 'tenant#' || i
from generate_series(1, 100) i;

insert into family (name, tenant_id)
select 'family#' || i, tenant_id
from tenant, generate_series(1, 5) i;

insert into attribute (name, type, tenant_id)
select 'attribute#' || i, 'text', tenant_id
from tenant, generate_series(1, 10) i;

insert into family_has_attribute (family_id, attribute_id, tenant_id)
select f.family_id, a.attribute_id, f.tenant_id
from family f join attribute a using (tenant_id);

insert into product (family_id, values, tenant_id)
select f.family_id, jsonb_build_object(a.name, 'test' || i), f.tenant_id
from family f
join attribute a using (tenant_id),
generate_series(1, 100) i;

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
    select category_id, tenant_id from category order by random() limit 100
), p as (
    select product_id, category_id, tenant_id from product join c using (tenant_id) order by random()
)
insert into product_in_category (product_id, category_id, tenant_id)
select product_id, category_id, tenant_id
from p;

commit;
