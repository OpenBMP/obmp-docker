#!/bin/bash
# Postgres Backend: Run script
#
#  Copyright (c) 2021-2022 Cisco Systems, Inc. and others.  All rights reserved.
#
# Author: Tim Evens <tim@evensweb.com>
#

# Postgres details - Can be set using docker -e
export POSTGRES_USER=${POSTGRES_USER:="openbmp"}
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:="openbmp"}
export POSTGRES_HOST=${POSTGRES_HOST:="127.0.0.1"}
export POSTGRES_PORT=${POSTGRES_PORT:="5432"}
export POSTGRES_DB=${POSTGRES_DB:="openbmp"}
export POSTGRES_SSL_ENABLE=${POSTGRES_SSL_ENABLE:="true"}
export POSTGRES_SSL_MODE=${POSTGRES_SSL_MODE:="require"}
export MEM=${MEM:="1"}                          # mem in gigabytes
export PGCONNECT_TIMEOUT=15

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Functions
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# -----------------------------------------------
# Check Kafka to make sure it's valid
# -----------------------------------------------
check_kafka() {
    echo "===> Performing Kafka check"

    if [[ ${KAFKA_FQDN:-""} == "" ]]; then
       echo "ERROR: Missing ENV KAFKA_FQDN.  Cannot proceed until you add that in docker run -e KAFKA_FQDN=<...>"
       exit 1

    fi

    echo "===> Checking Kafka bootstrap server connection"
    kafkacat -u -b $KAFKA_FQDN -L | grep broker

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to connect to Kafka at $KAFKA_FQDN, check the docker run -e KAFKA_FQDN= value"
        exit 1
    fi

    echo "testing" | timeout 5 kafkacat -b $KAFKA_FQDN -P -t openbmp.parsed.test
    echo "===> Checking if we can successfully consume messages"
    timeout 5 kafkacat -u -b $KAFKA_FQDN -C -c 1 -o beginning -t openbmp.parsed.test > /dev/null

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to connect to Kafka broker, check the Kafka 'advertised.listeners' configuration."
        echo "       Advertised hostname must be reachable within the container. You can run this container"
        echo "       with --add-host <hostname>:<ip> to map the ip address within the container."
        echo "       You can also add/update the persistent /config/hosts file with the broker hostname/ip."
        exit 1
    fi
}

# -----------------------------------------------
# Configure Postgres shell profile
# -----------------------------------------------
config_postgres_profile() {
    echo "===> Configuring PostgreSQL Shell Profile"

    echo "export PGUSER=$POSTGRES_USER" > /usr/local/openbmp/pg_profile
    echo "export PGPASSWORD=$POSTGRES_PASSWORD" >> /usr/local/openbmp/pg_profile
    echo "export PGHOST=$POSTGRES_HOST" >> /usr/local/openbmp/pg_profile
    echo "export PGPORT=$POSTGRES_PORT" >> /usr/local/openbmp/pg_profile
    echo "export PGDATABASE=$POSTGRES_DB" >> /usr/local/openbmp/pg_profile
}

# -----------------------------------------------
# Initdb Postgres
# -----------------------------------------------
initdb_postgres() {
    if [[ ! -f /config/do_not_init_db ]]; then
      echo " ===> Initializing the DB"

      echo "Waiting for postgres to start..."
      done=0
      while [  $done -eq 0 ]; do
          psql -c "select 1;" > /dev/null 2>&1
          if [[ $? -ne 0 ]]; then
             echo "    postgres not running, sleeping for 20 seconds..."
             sleep 20
          else
              done=1
              break
          fi
      done

      # Load the schema files
      echo " ===> Loading Schemas"

      echo "------" > /var/log/db_schema_load.log
      for file in $(ls -v /usr/local/openbmp/database/*.sql); do
        echo " ===[ $file ] ========================================" >> /var/log/db_schema_load.log
        psql < $file >> /var/log/db_schema_load.log  2>&1
      done

      touch /config/do_not_init_db
    fi
}

# -----------------------------------------------
# Update hosts file
# -----------------------------------------------
update_hosts() {
    echo "===> Updating /etc/hosts"

    # Update the etc hosts file
    if [[ -f /config/hosts ]]; then
        cat /config/hosts >> /etc/hosts
    fi
}

# -----------------------------------------------
# Enable RPKI
# -----------------------------------------------
enable_rpki() {
    echo "===> Enabling RPKI"

    cat > /etc/cron.d/openbmp-rpki <<SETVAR
MAILTO=""

# Update RPKI
31 */2 * * *	root  . /usr/local/openbmp/pg_profile && /usr/local/openbmp/rpki_validator.py -u $PGUSER -p $PGPASSWORD -s $RPKI_URL --rpkipassword $RPKI_PASS --rpkiuser $RPKI_USER $PGHOST > /var/log/cron-rpki-import.log

SETVAR

}

# -----------------------------------------------
# Enable DB-IP import
# -----------------------------------------------
enable_dbip() {
    echo "===> Enabling DB-IP Import"

    cat > /etc/cron.d/openbmp-dbip <<SETVAR
MAILTO=""

$(( $RANDOM % 59 + 1 )) $(( $RANDOM % 23 + 1 )) 1 * *	root  /usr/local/openbmp/db-ip-import.sh 2>&1 > /var/log/cron-dbip-import.log

SETVAR

    # Load DB-IP on start
    echo "Running DB-IP Import"
   /usr/local/openbmp/db-ip-import.sh 2>/var/log/cron-dbip-import.log > /var/log/cron-dbip-import.log &
}


# -----------------------------------------------
# Enable IRR
# -----------------------------------------------
enable_irr() {
    echo "===> Enabling IRR"

    cat > /etc/cron.d/openbmp-irr <<SETVAR
MAILTO=""

# Update IRR
1 1 * * *	root  . /usr/local/openbmp/pg_profile && /usr/local/openbmp/gen_whois_route.py -u $PGUSER -p $PGPASSWORD $PGHOST 2>&1 > /var/log/irr_load.log

SETVAR

    # Load IRR data
    echo "Loading IRR data"
    /usr/local/openbmp/gen_whois_route.py -u $PGUSER -p $PGPASSWORD $PGHOST  2>/var/log/irr_load.log  > /var/log/irr_load.log &
}

# -----------------------------------------------
# config_cron
# -----------------------------------------------
config_cron() {
    cat > /etc/cron.d/openbmp <<SETVAR
MAILTO=""

# Update ASN info
6 */2 * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/gen_whois.lock /usr/local/openbmp/gen_whois_asn.py -u $PGUSER -p $PGPASSWORD $PGHOST > /var/log/asn_load.log 2>&1
5 1,12 * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/peeringdb.lock /usr/local/openbmp/peeringdb.py > /var/log/cron-peeringdb.log 2>&1

# Update aggregation table stats
*/5 * * * *  root   . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/update_chg_stats.lock psql -c "select update_chg_stats('5 minute')" > /var/log/cron-update_chg_stats.log 2>&1
*/5 * * * *  root   . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/update_l3vpn_chg_stats.lock psql -c "select update_l3vpn_chg_stats('5 minute')" > /var/log/cron-update_l3vpn_chg_stats.log 2>&1


# Update peer rib counts
*/15 * * * *	root   . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/update_peer_rib_counts.lock psql -c "select update_peer_rib_counts()"  > /var/log/cron-update_peer_rib_counts.log 2>&1

# Update peer update counts
*/30 * * * *    root   . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/update_peer_counts.lock psql -c "select update_peer_update_counts(1800)"  > /var/log/cron-update_peer_counts.log 2>&1

# Update global rib
*/5 * * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/global_ip_rib.lock psql -c "select update_global_ip_rib();" > /var/log/cron-update_global_ip_rib.log 2>&1
5 */4 * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/global_ip_rib.lock psql -c "select purge_global_ip_rib('6 hour');" > /var/log/cron-purge_global_ip_rib.log 2>&1

# Update origin stats
21 * * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/update_origin_stats.lock psql -c "select update_origin_stats('1 hour');" > /var/log/cron-update_origin_stats.log 2>&1


SETVAR

}

# -----------------------------------------------
# Upgrade SQL
# -----------------------------------------------
upgrade() {

  if [[ -f /config/do_not_init_db ]]; then

    if [[ ! -f /config/psql-app-upgraded.2.1.0 ]]; then
      echo "===> Upgrading to 2.1.0"
      /tmp/upgrade/upgrade_2.1.0.sh
      touch /config/psql-app-upgraded.2.1.0
      echo "===> Done with upgrade"
    fi

    if [[ ! -f /config/psql-app-upgraded.2.2.0 ]]; then
      echo "===> Upgrading to 2.2.0"
      /tmp/upgrade/upgrade_2.2.0.sh
      touch /config/psql-app-upgraded.2.2.0
      echo "===> Done with upgrade"
    fi

   if [[ ! -f /config/psql-app-upgraded.2.2.1 ]]; then
      echo "===> Upgrading to 2.2.1"
      /tmp/upgrade/upgrade_2.2.1.sh
      touch /config/psql-app-upgraded.2.2.1
      echo "===> Done with upgrade"
    fi

   if [[ ! -f /config/psql-app-upgraded.2.2.2 ]]; then
      echo "===> Upgrading to 2.2.2"
      /tmp/upgrade/upgrade_2.2.2.sh
      touch /config/psql-app-upgraded.2.2.2
      echo "===> Done with upgrade"
    fi

  else
      touch /config/psql-app-upgraded.2.1.0
      touch /config/psql-app-upgraded.2.2.0
      touch /config/psql-app-upgraded.2.2.1
      touch /config/psql-app-upgraded.2.2.2
  fi
}


# -----------------------------------------------
# run_consumer
# -----------------------------------------------
run_consumer() {
    echo "===> Starting consumer"

    if [[ ! -f /config/obmp-psql.yml ]]; then
        cd /config
        unzip /usr/local/openbmp/obmp-psql-consumer.jar obmp-psql.yml


        if [[ ! -f /config/obmp-psql.yml ]]; then
            echo "ERROR: Cannot create /config/obmp-psql.yml"
            echo "       Update permissions on /config volume to 7777 OR add configuration file to /config volume"
            exit 1
        fi

         # Update configuration
        sed -i -e "s/\([ ]*bootstrap.servers:\)\(.*\)/\1 \"${KAFKA_FQDN}\"/" /config/obmp-psql.yml
        sed -i -e "s/\([ ]*host[ ]*:\)\(.*\)/\1 \"${POSTGRES_HOST}:${POSTGRES_PORT}\"/" /config/obmp-psql.yml
        sed -i -e "s/\([ ]*username[ ]*:\)\(.*\)/\1 \"${POSTGRES_USER}\"/" /config/obmp-psql.yml
        sed -i -e "s/\([ ]*password[ ]*:\)\(.*\)/\1 \"${POSTGRES_PASSWORD}\"/" /config/obmp-psql.yml
        sed -i -e "s/\([ ]*db_name[ ]*:\)\(.*\)/\1 \"${POSTGRES_DB}\"/" /config/obmp-psql.yml
        sed -i -e "s/\([ ]*ssl_enable[ ]*:\)\(.*\)/\1 \"${POSTGRES_SSL_ENABLE}\"/" /config/obmp-psql.yml
        sed -i -e "s/\([ ]*ssl_mode[ ]*:\)\(.*\)/\1 \"${POSTGRES_SSL_MODE}\"/" /config/obmp-psql.yml
    fi

    heap_mem=${MEM}G

    # Run
    cd /var/log
    java -Xmx${heap_mem} -Xms128m -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions \
         -XX:InitiatingHeapOccupancyPercent=30 -XX:G1MixedGCLiveThresholdPercent=30 \
         -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 \
         -XX:+ExitOnOutOfMemoryError \
         -Duser.timezone=UTC \
         -jar /usr/local/openbmp/obmp-psql-consumer.jar \
         -cf /config/obmp-psql.yml > /var/log/psql-console.log &

    cd /tmp
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Run
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SYS_NUM_CPU=$(grep processor /proc/cpuinfo | wc -l)

# Clear locks
if [[ ! -d /tmp/locks ]]; then
  mkdir /tmp/locks
else
  rm -rf /tmp/locks/*
fi

update_hosts

check_kafka

config_postgres_profile

source /usr/local/openbmp/pg_profile

config_cron

rm -f /etc/cron.d/openbmp-rpki
if [[ ${ENABLE_RPKI:-""} != "" && $ENABLE_RPKI == 1 ]]; then
    enable_rpki
fi

rm -f /etc/cron.d/openbmp-irr
if [[ ${ENABLE_IRR:-""} != "" && $ENABLE_IRR == 1 ]]; then
    enable_irr
fi

rm -f /etc/cron.d/openbmp-dbip
if [[ ${ENABLE_DBIP:-""} != "" && $ENABLE_DBIP == 1 ]]; then
    enable_dbip
fi


initdb_postgres

# Get rid of previous rsyslogd pid
rm -f /var/run/rsyslogd.pid

service cron start
service rsyslog start

upgrade

run_consumer

echo "===> Now running!!!"

while [ 1 ]; do
    sleep 300
    pgrep -f obmp-psql-consumer.jar >/dev/null 2>&1
    if [[ $? != 0 ]]; then
      echo "PSQL consumer is not running, restarting in 30 seconds"
      cat /var/log/psql-console.log
      sleep 30
      run_consumer
    fi
done

