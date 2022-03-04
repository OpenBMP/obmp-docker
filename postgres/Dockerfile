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

# Current/working dir
VOLUME ["/ws"]
WORKDIR /ws

# Expected data locations for base tables and timeseries
#
VOLUME ["/var/lib/postgresql/data"]
VOLUME ["/var/lib/postgresql/ts"]


RUN apk update \
    && apk add openssl \
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
    && sed -i -e "s/^\#*ssl_key_file.*=.*/ssl_key_file = \'\/psql_server.key\'/" /usr/local/share/postgresql/postgresql.conf.sample

# Init timesries location
RUN echo 'mkdir -p /var/lib/postgresql/ts/data' > /docker-entrypoint-initdb.d/0_obmp_init.sh \
    && echo 'chmod 0700 /var/lib/postgresql/ts/data' >> /docker-entrypoint-initdb.d/0_obmp_init.sh \
    && echo 'psql -U $POSTGRES_USER -c "CREATE TABLESPACE timeseries LOCATION '\''/var/lib/postgresql/ts/data'\'';" $POSTGRES_DB' >> /docker-entrypoint-initdb.d/0_obmp_init.sh



