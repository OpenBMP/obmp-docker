# Postgres Container
#
#  Copyright (c) 2021-2022 Cisco Systems, Inc. and others.  All rights reserved.
#
#  Build:
#       docker build --platform linux/amd64 -t openbmp/postgres:2.1.0 .
#
#  Run:
#       docker run --rm -it -p 5432:5432 \
#              -e POSTGRES_PASSWORD=openbmp \
#              -e POSTGRES_USER=openbmp \
#              -e POSTGRES_DB=openbmp \
#              openbmp/postgres:2.1.0

FROM timescale/timescaledb:2.5.1-pg14

ENV PG_CRON_VERSION 1.3.0

# Current/working dir
VOLUME ["/ws"]
WORKDIR /ws

# Expected data locations for base tables and timeseries
#
VOLUME ["/var/lib/postgresql/data"]
VOLUME ["/var/lib/postgresql/ts"]


RUN apk update \
    && apk add --no-cache --virtual .build-deps build-base ca-certificates clang-dev llvm12 openssl\
    && openssl req -x509 -newkey rsa:4096 -nodes -subj "/C=US/ST=CA/L=Seattle/O=OpenBMP/CN=localhost"  \
        -keyout /psql_server.key -out /psql_server.crt -days 2048 \
    && chown postgres /psql_server.* \
    && mkdir -p /var/lib/postgresql/ts \
    && chown postgres /var/lib/postgresql/ts \
    && egrep -q -e '^hostssl( |\t)+all' /usr/local/share/postgresql/pg_hba.conf.sample || \
            echo 'hostssl    all        all        0.0.0.0/0        md5' >> /usr/local/share/postgresql/pg_hba.conf.sample \
    && sed -i -e "s/^\#*listen_addresses.*=.*/listen_addresses = '*'/" /usr/local/share/postgresql/postgresql.conf.sample \
    && sed -i -e "s/^\#*max_wal_size.*=.*/max_wal_size = 10GB/" /usr/local/share/postgresql/postgresql.conf.sample \
    && sed -i -e "s/^\#*ssl[ ]*=.*/ssl = on/" /usr/local/share/postgresql/postgresql.conf.sample \
    && sed -i -e "s/^\#*ssl_cert_file.*=.*/ssl_cert_file = \'\/psql_server.crt\'/" /usr/local/share/postgresql/postgresql.conf.sample \
    && sed -i -e "s/^\#*ssl_key_file.*=.*/ssl_key_file = \'\/psql_server.key\'/" /usr/local/share/postgresql/postgresql.conf.sample \
    && sed -i -e "s/^shared_preload_libraries.*/shared_preload_libraries = 'timescaledb,pg_cron'/g" /usr/local/share/postgresql/postgresql.conf.sample

## Install pg_cron
RUN wget -O /ws/pg_cron.tgz https://github.com/citusdata/pg_cron/archive/v$PG_CRON_VERSION.tar.gz
RUN tar xvzf /ws/pg_cron.tgz && cd /ws/pg_cron-1.3.0/ \ 
    && sed -i.bak -e 's/-Werror//g' Makefile \
    && sed -i.bak -e 's/-Wno-implicit-fallthrough//g' Makefile \
    && make && make install \
    && cd .. && rm -rf pg_cron.tgz && rm -rf pg_cron-* \
    && apk del .build-deps

ADD --chmod=755 scripts/0_obmp_init.sh /docker-entrypoint-initdb.d/0_obmp_init.sh
## providing db name for cron metadata tables
RUN echo "cron.database_name = 'openbmp'" >> /usr/local/share/postgresql/postgresql.conf.sample
