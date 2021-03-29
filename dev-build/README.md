OpenBMP Collector Container
----------------------------
Collector container is the container for collecting BMP messages from BMP senders, e.g. routers.
This container can be distributed.

#### Container Includes
* **Openbmpd** - Latest collector (listening port is TCP 5000)

### Recommended Current Linux Distributions

  1. Ubuntu 14.04/Trusty
  1. CentOS 7/RHEL 7

### 1) Install docker
Docker host should be **Linux x86_64**.   Follow the [Docker Instructions](https://docs.docker.com/installation/) to install docker.  

- - -

### 2) Download the docker image

    docker pull openbmp/collector

- - -

### 3) [OPTIONAL] Add persistent configs

#### On host create persistent config location

    mkdir -p /var/openbmp/config
    chmod 777 /var/openbmp/config

#### config/hosts
You can add custom host entries so that the collector will reverse lookup IP addresses
using a persistent hosts file.

Run docker with ```-v /var/openbmp/config:/config``` to make use of the persistent config files.

#### config/openbmpd.conf
You can provide a customized **openbmpd.conf**.  See [Config Example](https://github.com/OpenBMP/openbmp/blob/master/Server/openbmpd.conf)

### 4) Run docker container

#### Environment Variables
Below table lists the environment variables that can be used with ``docker run -e <name=value>``

NAME | Value | Details
:---- | ----- |:-------
KAFKA\_FQDN | hostanme or IP | Kafka broker hostname[:port].  Hostname can be an IP address
OPENBMP\_ADMIN\_ID | name or IP | Name or IP of the collector, default is the docker hostname
OPENBMP\_BUFFER | Size in MB | Defines the openbmpd buffer per router for BMP messages. Default is 16 MB.

#### Run normally

> ##### IMPORTANT
> You must define the **KAFKA_FQDN** as a 'hostname'.  If all containers are running on the same node, this
> hostname can be local specific, such as 'localhost' or 'myhost'. If Kafka is running on a different server,
> than the consumers and producers, then the KAFKA_FQDN should be a valid hostname that can be resolved using DNS.
> This can be internal DNS or manually done by updating the /etc/hosts file on each machine.

    docker run -d --name=openbmp_collector -e KAFKA_FQDN=localhost \
         --sysctl net.ipv4.tcp_keepalive_intvl=30 \
         --sysctl net.ipv4.tcp_keepalive_probes=5 \
         --sysctl net.ipv4.tcp_keepalive_time=180 \
         -v /var/openbmp/config:/config \
         -p 5000:5000 \
         openbmp/collector


### Monitoring/Troubleshooting

You can use standard docker exec commands to monitor the log files.  To monitor 
openbmp, use ```docker exec openbmp_collector tail -f /var/log/openbmpd.log```

Alternatively, it can be easier at times to navigate all the log files from within the container. You can do so using:
    
    docker exec -it openbmp_collector bash


#### docker logs
You can use ```docker logs openbmp_collector``` to get the console logs. This is useful if the container exits due to
invalid start or for another reason.

     



