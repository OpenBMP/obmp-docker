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
* [PSQL Consumer](psql-consumer/README.md)


## Using Docker Compose to run everything

### Install Docker Compose
You will need docker-compose.  You can install that via [Docker Compose](https://docs.docker.com/compose/install/)
instructions.  Docker compose will run everything, including handling restarts of containers. 


```
docker-compose -p obmp up
```

