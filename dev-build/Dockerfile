# Collector: openbmp/collector
#
#  Copyright (c) 2013-2021 Cisco Systems, Inc. and others.  All rights reserved.
#  Copyright (c) 2013-2021 Tim Evens (tim@evensweb.com).  All rights reserved.
#
# Author: Tim Evens <tim@openbmp.org>
#
# BUILD: docker build -t openbmp/collector .

# -----------------------------------------------
# stage: Build collector
# -----------------------------------------------
FROM ubuntu:focal AS build

WORKDIR /ws

RUN apt-get update \
    && apt-get install git gcc g++ libboost-dev cmake zlib1g-dev libssl1.1 libsasl2-2 libssl-dev libsasl2-dev

RUN cd /tmp && git clone https://github.com/edenhill/librdkafka.git \
    && cd librdkafka \
    && ./configure \
    && make \
    && make install
    && cd /tmp

RUN  git clone https://github.com/jbeder/yaml-cpp.git \
    && cd yaml-cpp \
    && mkdir build && cd build \
    && make \
    && make install
    && cd /tmp

RUN cd /ws && mkdir build && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr ../ \
    && make \
    && make install

# -----------------------------------------------
# stage: Final container
# -----------------------------------------------
# Pull base image.
FROM ubuntu:focal

# Proxy/if behind firewall
#   Update your /etc/sysconfig/docker or /etc/default/docker file by adding proxy envs there using export <var>=<val>

# Add files.
ADD scripts/install /tmp/
ADD scripts/run /usr/sbin/

ARG BUILD_NUMBER=0

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
