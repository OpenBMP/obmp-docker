# OpenBMP Postgres Application Container
This container is the main application container for OpenBMP and PostgreSQL. 

It provides:

* PostgreSQL consumer 
* RPKI validator improt/sync 
* IRR and peering DB import/sync
* Schedules and runs the metric DB functions
* Schedules and runs the DB timescale DB chunk drops

## Building
See the [Dockerfile](Dockerfile) notes for build instructions.

## Running

### Kafka Validation Testing
The Kafka setup can be tricky due to docker networking between containers and remote systems. Kafka clustering
makes use of a bootstrap server which will advertise each broker ```hostname:port``` that the consumer/producer
will use.  Each consumer/producer will connect to the brokers using these **advertised** hostnames and ports.  The
setting in Kafka to configure the broker hostname is ```advertised.listeners```. 

The postgres container (**this container**) uses the **KAFKA_FQDN** as the bootstrap server,
syntax is ```<HOSTNAME or IP:PORT>```.  This will work with an
IP or hostname. When using a hostname, the hostname *MUST* resolve within the container.  While this may work for
bootstrap server conection, the advertised hostnames need to also resolve in the container.  

**Kafka Validation is a 3 step process** 

1. Successfully connect to the bootstrap server and retrieve metadata (e.g.  broker hostname:port)
2. Successfully produce a test message to ```openbmp.parsed.test``` topic
3. Successfully consume a test message from ```openbmp.parsed.test``` topic

> **IMPORTANT**
> If using your own Kafka install, make sure you allow producing/consuming to/from **openbmp.parsed.test** 
> for the consumer validation. 

### Hostnames in Container
You can map the Kafka hostname and each broker if they are different using two methods:

1. add ```--add-host HOSTNAME:IP``` to **docker run** command.  Make sure to add one for the bootstrap and each broker.  
2. Create a **/var/openbmp/config/hosts** file and add the Kafka bootstrap and broker hostname to IP mappings. 

### VM Specifications

#### Storage

You will need to dedicate space for the postgres instance.  Normally two partitions are used.  A good
starting size for postgres main is 500GB and postgres ts (timescaleDB) is 1TB.  Both disks
should be fast SSD. ZFS can be used on either of them to add compression. The size you need will depend
on the number of NLRI's and updates per second.

#### Memory & CPU

The size of memory will depend on the type of queries and number of NLRI's.   A good starting point for
memory is a server with more than 48GB RAM. You can run on as little as 4GB RAM but that will only
scale to about 10,000,000 NLRI's.  64BG of RAM should scale to 150,000,000 NLRI's. 

The number of vCPU's also varies by the number of concurrent connections and how many threads you use for
the postgres consumer.  A good starting point is at least 8 vCPU's.   


### 1) Install docker
Follow the [Docker Instructions](https://docs.docker.com/install) to install docker CE.  

### 2) Add persistent volumes

Persistent volumes make it possible for upgrades without loosing any data. 

#### (a) Create persistent config location

    mkdir -p /var/openbmp/config
    chmod 777 /var/openbmp/config

##### config/hosts
You can add custom host entries so that the collector will reverse lookup IP addresses
using a persistent hosts file.

Run docker with ```-v /var/openbmp/config:/config``` to make use of the persistent config files.

##### config/obmp-psql.yml
If the [obmp-psql.yml](https://github.com/OpenBMP/obmp-postgres/blob/master/src/main/resources/obmp-psql.yml) file
does not exist, a default one will be created. You should update this based on your settings. This file
is inline documented.  


### 3) Run docker container

> Running the docker container for the first time will download the container image. 

#### Environment Variables
Below table lists the environment variables that can be used with ``docker run -e <name=value>``

NAME | Value | Details
:---- | ----- |:-------
KAFKA\_FQDN | hostanme or IP | Kafka broker hostname.  Hostname can be an IP address.
ENABLE_RPKI | 1 | Set to 1 to eanble RPKI. RPKI is disabled by default
ENABLE_IRR | 1 | Set to 1 to enable IRR. IRR is disabled by default
MEM | number | Number value in GB to allocate to Postgres.  This will be the shared_buffers value.
PGUSER | username | Postgres username, default is **openbmp**
PGPASSWORD | password | Postgres password, default is **openbmp**
PGDATABASE | database | Name of postgres database, default is **openbmp**

#### Docker Run obmp-psql-app
> **NOTE:**
> If the container fails to start, it's likely due to the configuration. Check using
> ```docker logs obmp-psql-app```

```
docker run --rm -d --name obmp-psql-app \
	-h obmp-psql-app \
	-e ENABLE_RPKI=1 \
	-e ENABLE_IRR=1 \
	-e KAFKA_FQDN=kafka \
	-e MEM=16 \
	-v /var/openbmp/config:/config \
	-p 9005:9005 -p 8080:8080 \
	openbmp/psql-app:build-50
```

### Monitoring/Troubleshooting

Useful commands:

- docker logs obmp-psql-app
- docker exec obmp-psql-app tail -f /var/log/obmp-psql.log
- docker exec obmp-psql-app tail -f /var/log/postgresql/postgresql-10-main.log 
- docker exec -it obmp-psql-app bash

