ceph-config
===========

This Dockerfile may be used to bootstrap a cluster or add the cluster configuration
to a new host. It uses etcd to store the cluster config. It is especially suitable
to setup ceph on CoreOS.

The following strategy is applied:

  * An `/etc/ceph/ceph.conf` is found, do nothing.
  * If a cluster configuration is available, it will be written to `/etc/ceph`
  * If no cluster configuration is available, it will be bootstrapped. A lock mechanism 
    is used to allow concurrent deployment of multiple hosts.

## Usage 

To bootstrap a new cluster run:

`docker run -e MON_NAME=vagrant -e MON_IP=192.168.200.10 -e CONFD_IP=192.168.200.90 -e CONFD_PORT=8500 -e CONFD_BACKEND=consul -e kv_type=consul -e kv_port=8500 -v /etc/ceph:/etc/ceph -v /path/to/ceph-docker/config/templates/:/config ceph/config`

This will generate:

  *  `ceph.conf` 
  *  `ceph.client.admin.keyring` 
  *  `ceph.mon.keyring` 
  *  `monmap` 

Except the `monmap` the config will be stored in etcd under `/ceph-config/${CLUSTER}`. 

In case a configuration for the cluster is found, the configuration will be pulled
from etcd and written to `/etc/ceph`.

Multiple concurrent invocations will block until the first host finished to generate 
the configuration.

## Configuration

The following environment variables can be used to configure the bootstrapping:

  * `CLUSTER` is the name of the ceph cluster (defaults to: "ceph") 

Mandatory Configuration:
  * `MON_NAME` is the name of the monitor. Usually the short hostname
  * `MON_IP` is the IP address of the monitor (public)
  * `kv_type` is the backend to be used in connecting to the KV store (i.e. consul, etcd)
