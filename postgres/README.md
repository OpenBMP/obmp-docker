# OpenBMP Postgres
The postgres container is a plain postgres/timescaleDB container with
some modifications to support OpenBMP.  Any postgres install will work as long as
they have similar changes as shown in [Dockerfile](Dockerfile).  

## Building
See the [Dockerfile](Dockerfile) notes for build instructions. 

## Running
```
docker run --rm -it -p 5432:5432 \
    -e POSTGRES_PASSWORD=openbmp \
    -e POSTGRES_USER=openbmp \
    -e POSTGRES_DB=openbmp \
    openbmp/postgres:build-NNN
```

### Configuration/Environment Variables
See both [Postgres](https://hub.docker.com/_/postgres) and
[TimescaleDB](https://hub.docker.com/r/timescale/timescaledb) documentation for more
information on how to configure/run the docker container. 

### PostgreSQL Related

#### Postgres can be killed by the Linux OOM-Killer
This is very bad as it causes Postgres to restart. This will happen because postgres uses a large shared buffer,
which causes the OOM to believe it's using a lot of VM.

It is suggested to run the postgres server with the following Linux settings:

    # Update runtime
    sysctl -w vm.vfs_cache_pressure=500
    sysctl -w vm.swappiness=10
    sysctl -w vm.min_free_kbytes=1000000
    sysctl -w vm.overcommit_memory=2
    sysctl -w vm.overcommit_ratio=95   
    
    # Update startup    
    echo "vm.vfs_cache_pressure=500" >> /etc/sysctl.conf
    echo "vm.min_free_kbytes=1000000" >> /etc/sysctl.conf
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.overcommit_memory=2" >> /etc/sysctl.conf
    echo "vm.overcommit_ratio=95" >> /etc/sysctl.conf


See Postgres [hugepages](https://www.postgresql.org/docs/current/static/kernel-resources.html#LINUX-HUGE-PAGES) for
details on how to enable and use hugepages.   Some Linux distributions enable **transparent hugepages** which
will prevent the ability to configure ```vm.nr_hugepages```. If you find that you cannot set ```vm.nr_hugepages```,
then try the below:

    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo never > /sys/kernel/mm/transparent_hugepage/defrag
    sync && echo 3 > /proc/sys/vm/drop_caches


#### Postgres Vacuum (reclaim disk space)
Postgres reclaims deleted/updated records using the vacuum process.  You can run this manually/cron via the
```VACUUM``` command.  **autovacuum** is used to do this periodically.   Careful tuning of this
is required.  Checkout [autovacuum-tuning-basics](https://blog.2ndquadrant.com/autovacuum-tuning-basics/),
[Routine Vacuuming](https://www.postgresql.org/docs/current/static/routine-vacuuming.html), and
[VACUUM](https://www.postgresql.org/docs/current/static/sql-vacuum.html) for more details. 

#### Create persistent postgres locations

*You should use fast SSD and/or ZFS.*  Size of these locations/mount points are directly related to the
number of NLRI's maintained and number of changes/updates per second.

> TODO: Will post numbers of how to determine the disk size needed.  For now, if you have less
> than 50,000,00 prefixes, then you can use 1TB.  If you have more than that, you should consider
> multiple disks.  ZFS can make your life easier as you can easily add disks and it supports compression.

- **postgres/main** - This location will be used for the main postgres data
  files and tables.

> This really should be a mount point to a dedicated filesystem

```
    mkdir -p /var/openbmp/postgres/main
    chmod 7777 /var/openbmp/postgres/main
```

- **postgres/ts** - This location will be used for the time series postgres tables

> This really should be a mount point to a dedicated filesystem

```
    mkdir -p /var/openbmp/postgres/ts
    chmod 7777 /var/openbmp/postgres/ts
```
