# syntax=docker/dockerfile:1.3
# Collector: openbmp/collector
#
#  Copyright (c) 2021-2022 Cisco Systems, Inc. and others.  All rights reserved.
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
# Use buildkit - either via export DOCKER_BUILDKIT=1 or by using buildx cli
#
#   Example docker build:
#     tar -c -C ../../ ./obmp-collector ./obmp-docker/collector \
#           | docker buildx build --platform linux/amd64 --progress=plain \
#                 --build-arg VERSION=2.2.3 \
#                 -f obmp-docker/collector/Dockerfile -t openbmp/collector:2.2.3 -
#

# -----------------------------------------------
# stage: Build collector
# -----------------------------------------------
FROM openbmp/dev-image:latest AS build

COPY obmp-collector/ /ws
WORKDIR /ws

RUN rm -rf build && mkdir -p build && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX:PATH=/usr ../ \
    && make \
    && make install


# -----------------------------------------------
# stage: Final container
# -----------------------------------------------
# Pull base image.
FROM debian:stable-slim

# Add files.
ADD --chmod=755 obmp-docker/collector/scripts/install /tmp/
ADD --chmod=755 obmp-docker/collector/scripts/run /usr/sbin/

ARG VERSION=0

# Copy files from previous stages
COPY --chmod=755 --from=build /usr/bin/openbmpd /usr/bin/
COPY --from=build /usr/etc/openbmp/openbmpd.conf /usr/etc/openbmp/openbmpd.conf

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
