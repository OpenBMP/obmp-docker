# Postgres Container
#
#  Copyright (c) 2021 Cisco Systems, Inc. and Tim Evens.  All rights reserved.
#
#  Build:
#       docker build -t openbmp/postgres:build-NNN .
#
#  Run:
#       docker run --rm -it -p 5432:5432 \
#              -e POSTGRES_PASSWORD=openbmp \
#              -e POSTGRES_USER=openbmp \
#              -e POSTGRES_DB=openbmp \
#              openbmp/postgres:build-NNN

FROM timescale/timescaledb:2.1.0-pg13

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
        -keyout /psql_server.key -out /psql_server.crt -days 365 \
    && chown postgres /psql_server.* \
    && mkdir -p /var/lib/postgresql/ts \
    && chown postgres /var/lib/postgresql/ts \
    && egrep -q -e '^hostssl( |\t)+all' /usr/local/share/postgresql/pg_hba.conf.sample || \
            echo 'hostssl    all        all        0.0.0.0/0        md5' >> /usr/local/share/postgresql/pg_hba.conf.sample \
    && sed -i -e "s/^\#*listen_addresses.*=.*/listen_addresses = '*'/" /usr/local/share/postgresql/postgresql.conf.sample \
    && sed -i -e "s/^\#*ssl[ ]*=.*/ssl = on/" /usr/local/share/postgresql/postgresql.conf.sample \
    && sed -i -e "s/^\#*ssl_cert_file.*=.*/ssl_cert_file = \'\/psql_server.crt\'/" /usr/local/share/postgresql/postgresql.conf.sample \
    && sed -i -e "s/^\#*ssl_key_file.*=.*/ssl_key_file = \'\/psql_server.key\'/" /usr/local/share/postgresql/postgresql.conf.sample \
    && sed -i -e "s/^\#*shared_buffers.*=.*/shared_buffers = ${MEM:-1}GB/" /usr/local/share/postgresql/postgresql.conf.sample \
    && sed -i -e "s/^\#*work_mem.*=.*/work_mem = $(( (${MEM:-1} * 1024) * 5 / 100))MB/" /usr/local/share/postgresql/postgresql.conf.sample

# Init timesries location
RUN echo 'chown postgres:postgres /var/lib/postgresql/ts' > /docker-entrypoint-initdb.d/0_obmp_init.sh \
    echo 'chmod 0700 /var/lib/postgresql/ts' >> /docker-entrypoint-initdb.d/0_obmp_init.sh \
    && echo 'psql -U $POSTGRES_USER -c "CREATE TABLESPACE timeseries LOCATION '\''/var/lib/postgresql/ts'\'';" $POSTGRES_DB' > /docker-entrypoint-initdb.d/0_obmp_init.sh



