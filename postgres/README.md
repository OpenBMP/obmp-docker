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

