#!/bin/bash
# Upgrade script for L3VPN
#
#  Copyright (c) 2022 Cisco Systems, Inc. and Tim Evens.  All rights reserved.
#
# Author: Tim Evens <tim@evensweb.com>
#

source /usr/local/openbmp/pg_profile

echo "==> Upgrading to 2.2.0 SQL ==================================== "
psql < /tmp/upgrade/upgrade_2.2.0.sql
echo "==> Done upgrading to 2.2.0 SQL ================================== "


