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

create table product (
    product_id uuid not null default uuid_generate_v4(),
    tenant_id uuid not null references tenant (tenant_id) on delete cascade,
    family_id uuid not null,
    values jsonb not null default '{}',
    primary key (product_id, tenant_id),
    foreign key (family_id, tenant_id) references family (family_id, tenant_id) on delete cascade
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
select create_distributed_table('attribute', 'tenant_id', colocate_with => 'family');
select create_distributed_table('family_has_attribute', 'tenant_id', colocate_with => 'family');
select create_distributed_table('product', 'tenant_id', colocate_with => 'family');
select create_distributed_table('category', 'tenant_id', colocate_with => 'product');
select create_distributed_table('product_in_category', 'tenant_id', colocate_with => 'product');

commit;
