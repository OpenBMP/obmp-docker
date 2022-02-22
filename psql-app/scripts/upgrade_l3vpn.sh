#!/bin/bash
# Upgrade script for L3VPN
#
#  Copyright (c) 2022 Cisco Systems, Inc. and Tim Evens.  All rights reserved.
#
# Author: Tim Evens <tim@evensweb.com>
#

. /usr/local/openbmp/pg_profile && psql -c "select * from l3vpn_rib limit 1" > /dev/null 2>&1

if [[ $? -ne 0 ]]; then
  echo "==> Upgrading L3VPN SQL ======================================= "
  psql < /usr/local/openbmp/database/10_l3vpn.sql
  echo "==> Done upgrading L3VPN SQL ================================== "
fi