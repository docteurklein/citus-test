\set ON_ERROR_STOP 1

begin;

set search_path = pim, ext;

set citus.enable_ddl_propagation to off;
grant all on schema pim to rls_user;
grant all on all tables in schema pim to rls_user;
set citus.enable_ddl_propagation to on;

select run_command_on_workers('create user rls_user');
select run_command_on_workers('grant all on schema pim to rls_user');
select run_command_on_workers('grant all on all tables in schema pim to rls_user');

set citus.enable_ddl_propagation to off;
alter table product enable row level security;
drop policy by_tenant on product;
create policy by_tenant on product to public using (current_setting('app.tenant_id') = tenant_id::text);
set citus.enable_ddl_propagation to on;
select run_command_on_shards('product', 'alter table %s enable row level security;');

select run_command_on_shards('product', $cmd$
    drop policy by_tenant on %s;
$cmd$);
select run_command_on_shards('product', $cmd$
    create policy by_tenant on %s to public using (current_setting('app.tenant_id') = tenant_id::text);
$cmd$);

SELECT run_command_on_workers($cmd$
  create or replace function set_tenant_id() returns trigger as $$
    begin
      new.tenant_id := current_setting('app.tenant_id')::uuid;
      return new;
    end;
  $$ language plpgsql;
$cmd$
);

SELECT run_command_on_placements('product', $cmd$
    drop trigger if exists set_product_tenant_id on %s;
$cmd$
);

SELECT run_command_on_placements('product', $cmd$
    create trigger set_product_tenant_id before insert or update on %s
      for each row execute function set_tenant_id()
$cmd$);

commit;


-- set local citus.propagate_set_commands to 'local';

