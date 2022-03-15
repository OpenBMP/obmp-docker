#!/bin/bash

# postgres: Init script
#
#  Copyright (c) 2021 Cisco Systems, Inc. and Tim Evens.  All rights reserved.
#


# Init timesries location
mkdir -p /var/lib/postgresql/ts/data
chmod 0700 /var/lib/postgresql/ts/data
psql -U $POSTGRES_USER -c "CREATE TABLESPACE timeseries LOCATION '/var/lib/postgresql/ts/data';" $POSTGRES_DB

# Config pg cron to database schema
psql -U $POSTGRES_USER -c "CREATE EXTENSION pg_cron;" $POSTGRES_DB
psql -U $POSTGRES_USER -c "GRANT USAGE ON SCHEMA cron TO $POSTGRES_USER;" $POSTGRES_DB
