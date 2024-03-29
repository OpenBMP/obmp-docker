# syntax=docker/dockerfile:1.3
# Postgres Backend: openbmp/psql-app
#
# Copyright (c) 2021-2022 Cisco Systems, Inc. and others.  All rights reserved.
#
# Author: Tim Evens <tim@openbmp.org>
#
#   Docker context does not support multiple paths or mounting volumes for builds.
#   In effort to build the container from local git clones, we dynamically build a context
#
#   Clone the obmp-psql, obmp-java-api-message, and obmp-docker repos into the same directory.
#   Change directories to obmp-docker/psql-app and run the below from that
#   directory.
#
# Use buildkit - either via export DOCKER_BUILDKIT=1 or by using buildx cli
#
#   Example docker build:
#     tar -c -C ../../ ./obmp-psql ./obmp-docker/psql-app ./obmp-java-api-message \
#           | docker buildx build --platform linux/amd64 --progress=plain \
#                 --build-arg VERSION=2.2.2 \
#                 -f obmp-docker/psql-app/Dockerfile -t openbmp/psql-app:2.2.2 -

# -----------------------------------------------
# stage: Build
# -----------------------------------------------
FROM openbmp/dev-image:latest AS build

ARG VERSION=0.0.0

# Proxy servers
#ENV http_proxy http://proxy:80
#ENV https_proxy http://proxy:80
#ENV no_proxy "domain.com"

COPY obmp-psql/ /ws
COPY obmp-java-api-message/ /tmp/obmp-java-api-message
WORKDIR /ws

RUN cd /tmp/obmp-java-api-message \
    && mvn clean install \
    && cd /ws \
    && mvn clean package

# -----------------------------------------------
# stage: Final container
# -----------------------------------------------
FROM openjdk:17-slim

# Copy files from previous stages
COPY --from=build /ws/target/obmp-psql-consumer-0.1.0-SNAPSHOT.jar /usr/local/openbmp/obmp-psql-consumer.jar
COPY --from=build /ws/database/  /usr/local/openbmp/database
COPY  --chmod=755 --from=build /ws/cron_scripts/gen-whois/*.py /usr/local/openbmp/
COPY  --chmod=755 --from=build /ws/cron_scripts/peeringdb/*.py /usr/local/openbmp/
COPY  --chmod=755 --from=build /ws/cron_scripts/rpki/*.py /usr/local/openbmp/
COPY  --chmod=755 --from=build /ws/scripts/geo-csv-to-psql.py /usr/local/openbmp/
COPY  --chmod=755 --from=build /ws/scripts/db-ip-import.sh /usr/local/openbmp/

# Add files
ADD  --chmod=755 obmp-docker/psql-app/scripts/run /usr/sbin/
COPY --chmod=755 obmp-docker/psql-app/upgrade /tmp/upgrade

#----------------------------------
# Define persistent data volumes
VOLUME ["/config"]

#----------------------------------
# Expose ports.

# Consumer JMX console
EXPOSE 9005

#----------------------------------
# Define working directory.
WORKDIR /tmp

# Base setup tasks
RUN touch /usr/local/version-${VERSION} \
    && chmod 755 /usr/local/openbmp/*.py

#----------------------------------
# Install depends
RUN apt-get update \
    && apt-get install --allow-unauthenticated -y unzip curl wget whois vim rsyslog cron rsync kafkacat \
        procps python3-minimal python3-distutils python3-psycopg2  python3-dnspython postgresql-client \
    && ln -s /usr/bin/python3 /usr/bin/python

RUN cd /tmp && curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
    && python3 get-pip.py

RUN pip install ipaddr pykafka click netaddr

RUN pip3 install urllib3 requests

# Cleanup
RUN apt-get autoremove && apt-get clean

# Define default command.
CMD ["/usr/sbin/run"]

