# OpenBMP docker files
Docker files for OpenBMP.

## (Prerequisite) Platform Docker Install

> Ignore this step if you already have a current docker install

> **NOTE**
> You should use the latest docker version, documented in this section.

Follow the instructions on https://docs.docker.com/get-docker/

### Optionally add a non-root user to run docker as
    usermod -aG docker ubuntu
    
    # Logout and log back so the group takes affect. 


### Optionally configure **/etc/default/docker** (e.g. for proxy config)

    export http_proxy="http://proxy:80/"
    export https_proxy="http://proxy:80/"
    export no_proxy="127.0.0.1,openbmp.org,/var/run/docker.sock"

Make sure you can run '**docker run hello-world**' successfully.


## OpenBMP Docker Files
Each docker file contains a readme file, see below:

* [Collector](collector/README.md)
* [PostgreSQL](postgres/README.md)
* [PSQL Consumer](psql-app/README.md)


## Using Docker Compose to run everything

### Install Docker Compose
You will need docker-compose.  You can install that via [Docker Compose](https://docs.docker.com/compose/install/)
instructions.  Docker compose will run everything, including handling restarts of containers. 

#### (1) Mount/Make persistent directories
Create expected directories. You can choose to mount these as well or update the compose file to change them. 

> **NOTE**
> If you are using OSX/Mac, then you will need to update your docker preferences to allow ```/var/openbmp```

Make sure to create the **OBMP_DATA_ROOT** directory first.  
```
export OBMP_DATA_ROOT=/var/openbmp
sudo mkdir -p $OBMP_DATA_ROOT
```

Create sub directories
```
mkdir -p ${OBMP_DATA_ROOT}/config
mkdir -p ${OBMP_DATA_ROOT}/kafka-data
mkdir -p ${OBMP_DATA_ROOT}/zk-data
mkdir -p ${OBMP_DATA_ROOT}/zk-log
mkdir -p ${OBMP_DATA_ROOT}/postgres/data
mkdir -p ${OBMP_DATA_ROOT}/postgres/ts
mkdir -p ${OBMP_DATA_ROOT}/grafana
mkdir -p ${OBMP_DATA_ROOT}/grafana/dashboards

sudo chmod -R 7777 $OBMP_DATA_ROOT
```

> In order to init the DB tables, you must create the file ```${OBMP_DATA_ROOT}/config/init_db```.  This should
> only be done once or whenever you want to completely wipe out the DB and start over. 

Change ```OBMP_DATA_ROOT=<path>``` to where you created the directories above.  The default is ```/var/openbmp```

```
OBMP_DATA_ROOT=/var/openbmp docker-compose -p obmp up -d
```

