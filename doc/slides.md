# postgres+citus on kubernetes


## what?

Citus is a postgres extension written in C, that adds sharding capabilities to postgres.

Citus has been acquired by microsoft and runs one of the biggest analytics dashboard at microsoft (codename VeniceDB).  
It's a dashboard that allows microsoft teams to follow device usage (10TB new data per **day** :mindblown:).

It used to provide a cloud SaaS offering on AWS, but stopped and now focus entirely on the open-source, EE and *azure hyperscale postgres* offerings.

A citus cluster is comprised of:

 - 1 primary coordinator node
 - 0..N coordinator replica nodes
 - 1..N worker nodes

## what is sharding?

Sharding is a way to split tables in shards (chunks), and dispatch them on multiple servers.  
You need to define a **distribution key** to help citus put rows of the same distribution key on the same place.  
The coordinator uses a hash function on the distribution key to know on which shard should be a row.  
Co-location is the magic sauce that allows efficient relational SQL queries.

## coordinator

The coordinator is a regular postgres server, except it also stores metadata about shards, like:

 - nodes network addresses that form the cluster
 - which node holds which shards
 - ....

A bit like ES has "master" nodes, citus has coordinators.  
However it differs in how you can use coordinator nodes interchangeably.

The coordinator only holds metadata to know to which worker node contains which shards.  
This allows it to split and dispatch the query into multiple small queries and push them to worker nodes,
only aggregating the final result.

This allows for massive parallelisation.


## Coordinator replicas

You can use postgres native replication to synchronize many "standby" servers that mimics the primary coordinator.
Contrary to ES (and some others like crdb), the primary coordinator is still the SPOF to handle placement metadata.  
Coordinator Replicas should only be used to execute `DML` (Data Manipulation Language) and `SELECT` queries of distributed tables, and **not** `DDL` (Data Definition Language) or `citus_*` functions that manipulate placement metadata.

Since the coordinator only dispatches queries to the given worker nodes, any node knowing the placement metadata should be able to execute distributed queries.

If you want to execute `DML` queries on a replica, you have to allow it using this `GUC` (Grand Unified Configuration):

```
citus.writable_standby_coordinator=on
```

## postgres replication

There are different methods of replication:
(streaming or `WAL` (Write Ahead Log) archiving, physical or logical). Yes, it's complicated.

In this example, we used physical streaming replication.

Physical replication is the idea of sending physical `WAL` segments (on-disk representation of postgres data) to another server, so that it can replay them.

Those segments contain **everything** the primary does, so it's an "exact" copy.  
One limitation of that is that the disk binary representation is not stable between postgres versions, so you should always run the same versions.

Logical replication doesn't have this limitation, because it only sends the "logical" commands to arrive to the same data (whatever the on-disk format looks like. The logical replication client could even be a php application, for what it worths :) ).  
However, logical replication doesn't synchronize DDL, so it's harder to keep everything in sync.

### Steps to get physical replication to work on kube:

#### on the primary

We need to correctly setup the `pg_hba.conf` file to allow remote connections to use replication.  
For this we used a ConfigMap holding entries that allows replication.

We reused


#### on the replicas

 1. scale the `coordinator-replica` `sts` (StaTefulSet)
 2. its `initContainer` copies the `WAL` segments of the primary coordinator using `pg_basebackup` on the wire
 3. It also (re-)creates a physical replication slot for this new replica
 4. the postgres container runs configured with `primary_conninfo` and other standby settings to keep up-to-date after the initial backup synchro
 5. The replication slot helps the primary to keep `WAL` segments as needed
 5. This node is ready to accept queries


## pgbouncer


postgres uses UNIX processes to handle user connections, so it doesn't scale as well as mysql for example (which uses threads).

You can however put a proxy in front of postgres named `pgBouncer`, that acts as a connection pool.

PgBouncer keeps its own internal connections to postgres in a "pool", and maps many "public" connections to a few postgres connections.
It also provides queuing if necessary.

In this example, pgbouncer runs as a "sidecar" to the postgres container.  
There are 2 containers in each pod, and we point to either the `5432` or the `6432` port depending on whether we want to talk to postgres directly or via pgbouncer (respectively).

Citus uses TLS to communicate between its nodes, and will generate self-signed certs if necessary.

In this example, we used kubernetes cert-manager to do it.

We installed the cert-manager operator, and defined a `CRD` (Custom Resource Definition) to ask kubernetes to generate a self-signed certificate and put it in a kube `Secret`.

Then, we only had to mount those secrets in files, and point postgres to use them using those `GUC`s, passed as command line arguments:

```
args: ['postgres', '-c', 'ssl=on', '-c', 'ssl_cert_file=/etc/citus-cert/tls.crt', '-c', 'ssl_key_file=/etc/citus-cert/tls.key']
```

We also had to configure pgbouncer to sue the **same** TLS certificates.

### the TLS permissions story

Like openssh and other stuff, postgres requires TLS certificates to be `0644` or `0400`.

This was incompatible with kubernete's secret volume mounts, so we had to play with `SecurityContext` policies to run the container as the `postgres` user `999` in or case.

This works and postgres runs, but it also means we cannot exec inside the container and do root-stuff like ephemeral `apt install` and such.  
Not a big deal but I wanted to install curl for fixtures loading.

PS: there is a `1.20` kube feature that would maybe fix the problem:

https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#configure-volume-permission-and-ownership-change-policy-for-pods

Or maybe we should dig more into the existing `fsGroup` option.


### Adding workers

To add workers, we just have to scale the number of replicas of the `citus-worker` `sts`.


In order for citus to use a new node, you need to register it using the `citus_add_node` `UDF` (User-Defined Function).

We used the `postStart` hook of kubernetes to call this in parallel to the creation of the main container.

One problem is to find the correct DNS names for the workers that matches the TLS domains **and** the resolvable IP for inter-node communication. This is the only hardcoded value in this example for now.


## limitations and known issues

- Using `initContainer`s and `postStart` hooks to handle a citus cluster lifecycle is not good.

Indeed those events are per-pod and/or per-container, but what we need is per-sts-replica events.
We thus have to make our event handlers idempotent and potentially unefficient.

- hardcoding the kube namespace in DNS names

Right now I don't see a way to talk to a specific replica of the `sts` without using the dns entry of the form:

```
${HOSTNAME}.citus-worker.default.svc.cluster.local
```

- sts-generated names contain invalid characters for postgres replication slot names:

I have to sanitize names inferred out of the $HOSTNAME env var because it contains dashes, and postgres doesn't like it:

```
psql 'host=citus-coordinator user=postgres' -c "select pg_create_physical_replication_slot('$(echo $HOSTNAME | tr -dc '[:alnum:]')');"
```
