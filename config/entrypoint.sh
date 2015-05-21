#!/bin/bash
set -e 

if [ ! -n "$MON_NAME" ]; then
  echo >&2 "ERROR: MON_NAME must be defined as the name of the monitor"
  exit 1
fi
 
if [ ! -n "$MON_IP" ]; then
  echo >&2 "ERROR: MON_IP must be defined as the IP address of the monitor"
  exit 1
fi

if [ ! -n "$CONFD_IP" ]; then
  echo >&2 "ERROR: CONFD_IP must be defined as the IP address of the KV Store"
  exit 1
fi

if [ ! -n "$CONFD_PORT" ]; then
  echo >&2 "ERROR: CONFD_PORT must be defined as the Port address of the KV Store"
  exit 1
fi

if [ ! -n "$CONFD_BACKEND" ]; then
  echo >&2 "ERROR: CONFD_BACKEND must be defined as the backend of the CONFD"
  exit 1
fi

if [ ! -n "$kv_type" ]; then
  echo >&2 "ERROR: kv_type must be defined"
  exit 1
fi

if [ ! -n "$kv_port" ]; then
  echo >&2 "ERROR: kv_type must be defined"
  exit 1
fi
 
CLUSTER=${CLUSTER:-ceph}
CLUSTER_PATH=ceph-config/$CLUSTER

consuloretcd -A ${CONFD_IP} -p ${kv_port} CAS -${kv_type} mon_host/${MON_NAME} ${MON_IP}

if [ -e /etc/ceph/ceph.conf ]; then
  echo "Found existing config. Syncing"
  confd -onetime -backend ${CONFD_BACKEND} -node ${CONFD_IP}:${CONFD_PORT}
fi

sudo cp /config/ceph.conf.tmpl /etc/confd/templates/
sudo cp /config/ceph.conf.toml /etc/confd/conf.d/

# Acquire lock to not run into race conditions with parallel bootstraps
until consuloretcd -A ${CONFD_IP} -p ${kv_port} CAS -${kv_type} ${CLUSTER_PATH}/lock $MON_NAME > /dev/null 2>&1 ; do
  echo "Configuration is locked by another host. Waiting."
  sleep 1
done

if consuloretcd get -${kv_type} ${CLUSTER_PATH}/done > /dev/null 2>%1 ; then
  echo "Configuration found for cluster ${CLUSTER}. Writing to disk."

  consuloretcd -A ${CONFD_IP} -p ${kv_port} get -${kv_type} ${CLUSTER_PATH}/ceph.conf > /etc/ceph/ceph.conf
  consuloretcd -A ${CONFD_IP} -p ${kv_port} get -${kv_type} ${CLUSTER_PATH}/ceph.mon.keyring > /etc/ceph/ceph.mon.keyring
  consuloretcd -A ${CONFD_IP} -p ${kv_port} get -${kv_type} ${CLUSTER_PATH}/ceph.client.admin.keyring > /etc/ceph/ceph.client.admin.keyring

  ceph mon getmap -o /etc/ceph/monmap
else 
  echo "No configuration found for cluster ${CLUSTER}. Generating."
  export fsid=$(uuidgen)
  confd -onetime -backend ${CONFD_BACKEND} -node ${CONFD_IP}:${CONFD_PORT}

  ceph-authtool /etc/ceph/ceph.client.admin.keyring --create-keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'
  ceph-authtool /etc/ceph/ceph.mon.keyring --create-keyring --gen-key -n mon. --cap mon 'allow *'
  monmaptool --create --add ${MON_NAME} ${MON_IP} --fsid ${fsid}  /etc/ceph/monmap

  export CEPHCONF=$(cat /etc/ceph/ceph.conf)
  export MONKEY=$(cat /etc/ceph/ceph.mon.keyring)
  export ADKEY=$(cat /etc/ceph/ceph.client.admin.keyring)

  consuloretcd -A ${CONFD_IP} -p ${kv_port} put -${kv_type} ${CLUSTER_PATH}/ceph.conf "$CEPHCONF"
  consuloretcd -A ${CONFD_IP} -p ${kv_port} put -${kv_type} ${CLUSTER_PATH}/ceph.mon.keyring "$MONKEY"
  consuloretcd -A ${CONFD_IP} -p ${kv_port} put -${kv_type} ${CLUSTER_PATH}/ceph.client.admin.keyring "$ADKEY"
    
  echo "completed initialization for ${MON_NAME}"
  consuloretcd -A ${CONFD_IP} -p ${kv_port} put -${kv_type} ${CLUSTER_PATH}/done true > /dev/null 2>&1
fi

consuloretcd -A ${CONFD_IP} -p ${kv_port} delete -${kv_type} ${CLUSTER_PATH}/lock > /dev/null 2>&1

