# citus cluster

## setup
```
k3d cluster create -v $HOME:$HOME --registry-create
kubectl apply -f k8s
kubectl exec sts/citus-coordinator -- psql -U postgres < sql/schema.sql
kubectl exec sts/citus-coordinator -- psql -U postgres < sql/fixtures.sql
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
  where table_schema = 'public' --<< change here for the schema you want
) t
```

## 5min statement timeout
```
alter database postgres set statement_timeout to 300000;

select run_command_on_workers($cmd$
    alter database postgres set statement_timeout to 300000;
$cmd$);
```
