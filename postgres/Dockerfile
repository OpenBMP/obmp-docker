# Postgres Container
#
#  Copyright (c) 2021-2022 Cisco Systems, Inc. and others.  All rights reserved.
#
#  Build:
#        DOCKER_BUILDKIT=1 docker build --platform linux/amd64 \
#            --build-arg VERSION=2.2.0 \
#            --squash \
#            -t openbmp/postgres:2.2.0 .
#
#  Run:
#       docker run --rm -it -p 5432:5432 \
#              -e POSTGRES_PASSWORD=openbmp \
#              -e POSTGRES_USER=openbmp \
#              -e POSTGRES_DB=openbmp \
#              openbmp/postgres:2.2.0

# -----------------------------------------------
# stage: Build
# -----------------------------------------------


# -----------------------------------------------
# stage: Final container
# -----------------------------------------------
#FROM timescale/timescaledb-ha:pg14.3-ts2.7-latest
FROM timescale/timescaledb-ha:pg14-ts2.7-oss-latest
ARG VERSION=0.0.0

ENV PGDATA=/var/lib/postgresql/data
ENV PGDATA_TS=/var/lib/postgresql/ts/data

# Expected data locations for base tables and timeseries
#
VOLUME ["/var/lib/postgresql/data"]
VOLUME ["/var/lib/postgresql/ts"]

ADD --chmod=755 scripts/004_obmp_psql_cfg.sh /docker-entrypoint-initdb.d/004_obmp_psql_cfg.sh
ADD --chmod=755 scripts/005_obmp_init.sh /docker-entrypoint-initdb.d/005_obmp_init.sh

USER root

RUN  rm -rf /usr/lib/postgresql/12 /usr/lib/postgresql/13  \
     && mkdir -p /var/lib/postgresql/data /var/lib/postgresql/ts/data \
     && chown -R postgres /var/lib/postgresql/data /var/lib/postgresql/ts/data

USER postgres

RUN touch /var/lib/postgresql/data/version-${VERSION}
