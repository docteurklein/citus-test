\set ON_ERROR_STOP 1

create schema if not exists ext;
create extension if not exists "uuid-ossp" with schema ext;

begin;

drop schema if exists pim cascade;
create schema pim;

set search_path = pim, ext;

create table tenant (
    tenant_id uuid not null default uuid_generate_v4(),
    name text not null,
    primary key (tenant_id)
);

create table family (
    family_id uuid not null default uuid_generate_v4(),
    tenant_id uuid not null references tenant (tenant_id) on delete cascade,
    name text not null,
    primary key (family_id, tenant_id)
);

create table attribute (
    attribute_id uuid not null default uuid_generate_v4(),
    tenant_id uuid not null references tenant (tenant_id) on delete cascade,
    name text not null,
    type text not null,
    primary key (attribute_id, tenant_id)
);

create table family_has_attribute (
    family_id uuid not null,
    attribute_id uuid not null,
    tenant_id uuid not null references tenant (tenant_id) on delete cascade,
    primary key (family_id, attribute_id, tenant_id),
    foreign key (family_id, tenant_id) references family (family_id, tenant_id) on delete cascade,
    foreign key (attribute_id, tenant_id) references attribute (attribute_id, tenant_id) on delete cascade
);

create table channel (
    channel_id uuid not null default uuid_generate_v4(),
    tenant_id uuid not null references tenant (tenant_id) on delete cascade,
    name text not null,
    primary key (channel_id, tenant_id)
);

create table locale (
    locale_id text not null default uuid_generate_v4(),
    tenant_id uuid not null references tenant (tenant_id) on delete cascade,
    name text not null,
    primary key (locale_id, tenant_id)
);

create table product (
    product_id uuid not null default uuid_generate_v4(),
    tenant_id uuid not null references tenant (tenant_id) on delete cascade,
    family_id uuid not null,
    primary key (product_id, tenant_id),
    foreign key (family_id, tenant_id) references family (family_id, tenant_id) on delete cascade
);

create table product_value (
    product_id uuid not null,
    attribute_id uuid not null,
    locale_id text null,
    channel_id uuid null,
    tenant_id uuid not null references tenant (tenant_id) on delete cascade,
    value jsonb not null,
    primary key (product_id, attribute_id, locale_id, channel_id, tenant_id),
    foreign key (product_id, tenant_id) references product (product_id, tenant_id) on delete cascade,
    foreign key (attribute_id, tenant_id) references attribute (attribute_id, tenant_id) on delete cascade,
    foreign key (locale_id, tenant_id) references locale (locale_id, tenant_id) on delete cascade,
    foreign key (channel_id, tenant_id) references channel (channel_id, tenant_id) on delete cascade
);

create table category (
    category_id uuid not null default uuid_generate_v4(),
    name text not null,
    parent_id uuid default null,
    tenant_id uuid not null references tenant (tenant_id) on delete cascade,
    primary key (category_id, tenant_id),
    foreign key (parent_id, tenant_id) references category (category_id, tenant_id)  on delete cascade deferrable initially immediate
);

create table product_in_category (
    product_id uuid not null,
    category_id uuid not null,
    tenant_id uuid not null references tenant (tenant_id),
    primary key (tenant_id, product_id, category_id),
    foreign key (product_id, tenant_id) references product (product_id, tenant_id) on delete cascade,
    foreign key (category_id, tenant_id) references category (category_id, tenant_id) on delete cascade
);

select create_reference_table('tenant');
select create_distributed_table('family', 'tenant_id');
select create_distributed_table('channel', 'tenant_id');
select create_distributed_table('locale', 'tenant_id');
select create_distributed_table('attribute', 'tenant_id', colocate_with => 'family');
select create_distributed_table('family_has_attribute', 'tenant_id', colocate_with => 'family');
select create_distributed_table('product', 'tenant_id', colocate_with => 'family');
select create_distributed_table('product_value', 'tenant_id', colocate_with => 'product');
select create_distributed_table('category', 'tenant_id', colocate_with => 'product');
select create_distributed_table('product_in_category', 'tenant_id', colocate_with => 'product');

create or replace function pim.localized_tsvector(language text, content text) returns tsvector as $$
  select to_tsvector(language::regconfig, content);
$$ language sql immutable;
select create_distributed_function('localized_tsvector(text,text)');

create index fts on product_value using gin (pim.localized_tsvector(locale_id, value::text));

commit;
