#!/bin/bash

# postgres: Init script
#
#  Copyright (c) 2021-2022 Cisco Systems, Inc. and Tim Evens.  All rights reserved.
#

# >> NOTE, before adding extensions, required preload/config should be done first in 004_obmp_psql_cfg.sh

# Add extensions
psql -U $POSTGRES_USER -c "CREATE EXTENSION IF NOT EXISTS postgis CASCADE;" $POSTGRES_DB
psql -U $POSTGRES_USER -c "CREATE EXTENSION IF NOT EXISTS pgrouting CASCADE;" $POSTGRES_DB

# Add cron extension and config
psql -U $POSTGRES_USER -c "CREATE EXTENSION IF NOT EXISTS pg_cron;" $POSTGRES_DB
psql -U $POSTGRES_USER -c "GRANT USAGE ON SCHEMA cron TO $POSTGRES_USER;" $POSTGRES_DB

