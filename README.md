# citus cluster

## setup
```
k3d cluster create -c k3d.yaml

kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml

kubectl create secret generic citus-secrets --from-literal "password=$(openssl rand -base64 23)"
kubectl apply -f k8s

kubectl exec -it sts/citus-coordinator -- psql -U postgres < sql/schema.sql
kubectl exec -it sts/citus-coordinator -- psql -U postgres < sql/fixtures.sql
```


## row count of all tables
```
select table_schema,
       table_name,
       (xpath('/row/cnt/text()', xml_count))[1]::text::int as row_count
from (
  select table_name, table_schema,
         query_to_xml(format('select count(*) as cnt from %I.%I', table_schema, table_name), false, true, '') as xml_count
  from information_schema.tables
  where table_schema = 'pim'
) t;
```

## 5min statement timeout
```
alter database postgres set statement_timeout to 300000;

select run_command_on_workers($cmd$
    alter database postgres set statement_timeout to 300000;
$cmd$);
```

## cancel all queries on workers
```
select run_command_on_workers($cmd$
    select pg_cancel_backend(pid) from pg_stat_activity where state = 'active' and pid <> pg_backend_pid();
$cmd$);
```

## FTS values
```
set search_path = pim, ext;

create index fts on product using gin (to_tsvector('english', values->'text_attribute'->>'content'));

select * from product where to_tsvector(values->>'Pilot') @@ websearch_to_tsquery('jesse pinkman');
select * from product where to_tsvector(values->'text_attribute'->>'attribute#1') @@ websearch_to_tsquery('Unfortunately');
```
