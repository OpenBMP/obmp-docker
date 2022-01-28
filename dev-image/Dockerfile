# Development build container: openbmp/dev-image
#
#  Copyright (c) 2021-2022 Cisco Systems, Inc. and others.  All rights reserved.
#  Copyright (c) 2021-2022 Tim Evens.  All rights reserved.
#
#  Container used to build the OpenBMP components
#
# Author: Tim Evens <tim@openbmp.org>
#
# BUILD: docker build -t openbmp/dev-image .
#        docker tag openbmp/dev-image openbmp/dev-image:latest

FROM debian:bullseye-slim AS build

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /ws

# Install the various depends
RUN apt-get update
RUN apt-get install -y openjdk-17-jdk-headless maven
RUN mkdir -p /usr/share/man/man1/ \
    && apt-get -y install git gcc g++ libboost-dev cmake zlib1g-dev libssl-dev libsasl2-dev \
         liblz4-dev libzstd-dev librdkafka-dev


# Build/install yaml-cpp
RUN cd /tmp && git clone https://github.com/jbeder/yaml-cpp.git \
    && cd yaml-cpp \
    && mkdir build && cd build \
    && cmake -DBUILD_SHARED_LIBS=OFF .. \
    && make && make install \
    && cd /tmp

# Clean up
RUN rm -rf /tmp/* && apt-get clean

