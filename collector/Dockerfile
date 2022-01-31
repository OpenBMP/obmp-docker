# Collector: openbmp/collector
#
#  Copyright (c) 2021-2022 Cisco Systems, Inc. and Tim Evens.  All rights reserved.
#
# Author: Tim Evens <tim@openbmp.org>
#
# BUILD:
#
#   Docker context does not support multiple paths or mounting volumes for builds.
#   In effort to build the container from local git clones, we dynamically build a context
#
#   Clone the obmp-collector and obmp-docker repos into the same directory.
#   Change directories to obmp-docker/collector and run the below from that
#   directory.
#
#   Example docker build:
#     tar -cL -C ../../ ./obmp-collector ./obmp-docker/collector \
#           | docker build --build-arg VERSION=2.0.2 \
#                 -f obmp-docker/collector/Dockerfile -t openbmp/collector:2.0.2 -
#

# -----------------------------------------------
# stage: Build collector
# -----------------------------------------------
FROM openbmp/dev-image:latest AS build

COPY obmp-collector/ /ws
WORKDIR /ws

RUN mkdir -p build && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr ../ \
    && make \
    && make install


# -----------------------------------------------
# stage: Final container
# -----------------------------------------------
# Pull base image.
FROM debian:bullseye-slim

# Add files.
ADD obmp-docker/collector/scripts/install /tmp/
ADD obmp-docker/collector/scripts/run /usr/sbin/

ARG VERSION=0

# Copy files from previous stages
COPY --from=build /usr/bin/openbmpd /usr/bin/
COPY --from=build /usr/etc/openbmp/openbmpd.conf /usr/etc/openbmp/openbmpd.conf
COPY --from=build /etc/init/openbmpd.conf /etc/init/openbmpd.conf
COPY --from=build /etc/default/openbmpd.new /etc/default/openbmpd
COPY --from=build /etc/logrotate.d/openbmpd /etc/logrotate.d/openbmpd

# Proxy servers
#ENV http_proxy http://proxy:80
#ENV https_proxy http://proxy:80
#ENV no_proxy "domain.com"

# Run Install script
RUN /tmp/install

# Define mount points.
VOLUME ["/config"]

# Define working directory.
WORKDIR /tmp

# Define default command.
CMD ["/usr/sbin/run"]

# Expose ports.
# openbmpd/collector
EXPOSE 5000         
