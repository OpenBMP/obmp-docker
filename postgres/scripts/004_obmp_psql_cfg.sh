#!/bin/bash

# OpenBMP Postgres configuration
#
#  Copyright (c) 2022 Cisco Systems, Inc. and Tim Evens.  All rights reserved.
#


# Create SSL cert
openssl req -x509 -newkey rsa:4096 -nodes -subj "/C=US/ST=CA/L=Seattle/O=OpenBMP/CN=localhost"  \
        -keyout $PGDATA/psql_server.key -out $PGDATA/psql_server.crt -days 2048 \

# Init timeseries location
mkdir -p $PGDATA_TS
chmod 0700 $PGDATA_TS
psql -U $POSTGRES_USER -c "CREATE TABLESPACE timeseries LOCATION '$PGDATA_TS';" $POSTGRES_DB

# Update postgres conf
sed -i -e "s/^\#*listen_addresses.*=.*/listen_addresses = '*'/" $PGDATA/postgresql.conf
sed -i -e "s/^\#*ssl[ ]*=.*/ssl = on/" $PGDATA/postgresql.conf
sed -i -e "s/^\#*ssl_cert_file.*=.*/ssl_cert_file =  '${PGDATA//\//\\\/}\/psql_server.crt'/" $PGDATA/postgresql.conf
sed -i -e "s/^\#*ssl_key_file.*=.*/ssl_key_file =  '${PGDATA//\//\\\/}\/psql_server.key'/" $PGDATA/postgresql.conf

sed -i -e "s/^shared_preload_libraries.*/shared_preload_libraries = 'timescaledb,pg_cron'/g" $PGDATA/postgresql.conf

echo "cron.database_name = 'openbmp'" >> $PGDATA/postgresql.conf

egrep -q -e '^hostssl( |\t)+all' $PGDATA/pg_hba.conf
if [[ $? ]]; then
    echo 'hostssl    all        all        0.0.0.0/0        md5' >> $PGDATA/pg_hba.conf
fi


pg_ctl -D "$PGDATA" -m fast -w restart