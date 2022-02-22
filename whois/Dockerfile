# syntax=docker/dockerfile:1.3
# Postgres Backend: openbmp/whois
#
# Copyright (c) 2022 Cisco Systems, Inc. and others.  All rights reserved.
#
# BUILD:
#     tar -c -C ../../ ./obmp-whois ./obmp-docker/whois  \
#           | docker buildx build --platform linux/amd64 --progress=plain \
#                 -f obmp-docker/whois/Dockerfile -t openbmp/whois:2.1.0 -

# -----------------------------------------------
# stage: Build
# -----------------------------------------------
FROM golang:alpine AS build

WORKDIR /ws

COPY obmp-whois/ /ws

ENV GO111MODULE=on
ENV GCGO_ENABLED=0
ENV GOARCH=amd64
ENV GOOS=linux

RUN apk add --no-cache bash git
RUN cd /ws && go mod tidy

# Build the app
RUN cd /ws && go build -o obmp-whoisd .


# -----------------------------------------------
# stage: Final container
# -----------------------------------------------
FROM alpine

COPY --from=build  /ws/obmp-whoisd /usr/local/bin/

WORKDIR /tmp

# Environment varialbes that should be set when running container
#   Defaults are given below
ENV DB_MAX_THREADS=10
ENV WHOIS_PORT=43

ENV PGHOST=obmp-psql
ENV PGDATABASE=openbmp
ENV PGUSER=openbmp
ENV PGPASSWORD=openbmp
ENV PGPORT=5432

EXPOSE 43

# -- general depends
RUN apk add --no-cache bash

# -- set entry point to bash and act as login (load profile)
ENTRYPOINT /usr/local/bin/obmp-whoisd --logfile /dev/stdout -p $WHOIS_PORT -t $DB_MAX_THREADS