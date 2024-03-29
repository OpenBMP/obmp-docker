# Development build container: openbmp/dev-image
#
#  Copyright (c) 2021-2022 Cisco Systems, Inc. and others.  All rights reserved.
#
#  Container used to build the OpenBMP components
#
# Author: Tim Evens <tim@openbmp.org>
#
# BUILD: docker buildx build  --platform linux/amd64 --progress=plain -t openbmp/dev-image:latest .

FROM debian:stable-slim AS build

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /ws

# Install the various depends
RUN apt-get update
RUN apt-get install -y openjdk-17-jdk-headless maven
RUN mkdir -p /usr/share/man/man1/ \
    && apt-get -y install git gcc g++ libboost-dev cmake libssl-dev libsasl2-dev \
         curl wget libgss-dev   liblz4-dev libzstd-dev
    # zlib1g-dev

# Build/install zlib - zlib1g-dev does not work for static builds of librdkafka
RUN cd /tmp && git clone https://github.com/madler/zlib.git \
    && cd zlib \
    && git checkout v1.2.12 \
    && CFLAGS=-fPIC  ./configure --static \
    && make install

# Build/install librdkafka
RUN cd /tmp && git clone https://github.com/edenhill/librdkafka.git \
    && cd librdkafka \
    && git checkout v1.9.2 \
    && ./configure --enable-static --disable-curl \
    && make \
    && make install

# Installed under /usr/local/lib

# Build/install yaml-cpp
RUN cd /tmp && git clone https://github.com/jbeder/yaml-cpp.git \
    && cd yaml-cpp \
    && git checkout yaml-cpp-0.7.0 \
    && mkdir build && cd build \
    && cmake -DYAML_BUILD_SHARED_LIB=OFF .. \
    && make && make install \
    && cd /tmp

# Clean up
RUN rm -rf /tmp/* && apt-get clean

