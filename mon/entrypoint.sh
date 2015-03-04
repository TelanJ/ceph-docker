#!/bin/bash

main() {
  echo "Initializing Mon"

  HOSTNAME=`hostname -s`

  MON_NAME=${MON_NAME:-"$HOSTNAME"}

  KV_TYPE=${$KV_TYPE:"etcd"}
  KV_PORT=${KV_PORT:-8500}
  KV_IP=${KV_IP:-172.17.42.1}
  KV="$KV_IP:$KV_PORT"

  KV_PATH=${KV_PATH:-/ceph}

  validate

  if [ ! -e /etc/ceph/ceph.conf ]; then

    case "$KV_TYPE" in
    'static')
    echo "Configuring Static conf"
    create_conf_static
    ;;
    'consul')
    echo "Configure Consul conf"
    create_conf_kv
    ;;
    'etcd')
    echo "Configure etcd conf"
    create_conf_kv
    ;;
    esac

  fi

  # If we don't have a monitor keyring, this is a new monitor
  if [ ! -e /var/lib/ceph/mon/ceph-${MON_NAME}/keyring ]; then
    create_keyring_monmap
  fi

  echo "Starting Mon"
  exec /usr/bin/ceph-mon -d -i ${MON_NAME} --public-addr ${MON_IP}:6789
}

validate() {


  if [ ! -n "$MON_NAME" ]; then
     echo "ERROR- MON_NAME must be defined as the name of the monitor"
     exit 1
  fi

  if [ ! -n "$MON_IP" ]; then
     echo "ERROR- MON_IP must be defined as the IP address of the monitor"
     exit 1
  fi


}

create_conf_static() {
  ### Bootstrap the ceph cluster

  fsid=$(uuidgen)
  cat <<ENDHERE >/etc/ceph/ceph.conf
fsid = $fsid
mon initial members = ${MON_NAME}
mon host = ${MON_IP}
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
ENDHERE

  # Generate administrator key
  ceph-authtool /etc/ceph/ceph.client.admin.keyring --create-keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'

  # Generate the mon. key
  ceph-authtool /etc/ceph/ceph.mon.keyring --create-keyring --gen-key -n mon. --cap mon 'allow *'

  # Generate initial monitor map
  monmaptool --create --add ${MON_NAME} ${MON_IP} --fsid ${fsid} /etc/ceph/monmap
fi

}

create_conf_kv() {
  if ! kv_query mon_setup_complete >/dev/null 2>&1 ; then
    echo "Ceph hasn't yet been configured. Trying to deploy..."

    # let's rock and roll. we need to obtain a lock so we can ensure only one machine is trying to deploy the cluster
    if kv_set_default mon_setup_lock ${HOSTNAME} \
    || [[ kv_query mon_setup_lock == "$HOSTNAME" ]] ; then
      echo "Obtained the lock to proceed with setting up."

      # set some defaults in consul if they're not passed in as environment variables
      # these are templated in ceph.conf
      kv_set_default osd/osd_pool_default_size 3
      kv_set_default osd/osd_pool_default_pg_num 128
      kv_set_default osd/osd_pool_default_pgp_num 128
      kv_set_default osd/osd_recovery_delay_start 15

      fsid=$(uuidgen)
      kv_set_default fsid ${fsid}

        # Generate administrator key
      ceph-authtool /etc/ceph/ceph.client.admin.keyring --create-keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'

      # Generate the mon. key
      ceph-authtool /etc/ceph/ceph.mon.keyring --create-keyring --gen-key -n mon. --cap mon 'allow *'

      # Generate initial monitor map
      monmaptool --create --add ${HOSTNAME} ${HOST} --fsid ${fsid} /etc/ceph/monmap

      mon_keyring=`cat /etc/ceph/ceph.mon.keyring`
      admin_keyring=`cat /etc/ceph/ceph.client.admin.keyring`

      kv_set_default keyring/mon ${mon_keyring}
      kv_set_default keyring/admin ${admin_keyring}

      # mark setup as complete
      echo "setup complete."
      kv_set_default mon_setup_complete ceph-complete

    else
      until kv_query mon_setup_complete 2>&1 ; do
        echo "waiting for another monitor to complete setup..."
        sleep 5
      done
    fi
  fi



  until confd -onetime -backend ${KV_TYPE} -node ${KV_IP}:${KV_PORT} >/dev/null 2>&1; do
    echo "waiting for confd to write initial templates..."
    sleep 5
  done

}

create_keyring_monmap() {

  if [ ! -e /etc/ceph/ceph.client.admin.keyring ]; then
     echo "ERROR- /etc/ceph/ceph.client.admin.keyring must exist; get it from your existing mon"
     exit 2
  fi

  if [ ! -e /etc/ceph/ceph.mon.keyring ]; then
     echo "ERROR- /etc/ceph/ceph.mon.keyring must exist.  You can extract it from your current monitor by running 'ceph auth get mon. -o /tmp/ceph.mon.keyring'"
     exit 3
  fi

  if [ ! -e /etc/ceph/monmap ]; then
     echo "ERROR- /etc/ceph/monmap must exist.  You can extract it from your current monitor by running 'ceph mon getmap -o /tmp/monmap'"
     exit 4
  fi

  # Import the client.admin keyring and the monitor keyring into a new, temporary one
  ceph-authtool /tmp/ceph.mon.keyring --create-keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
  ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.mon.keyring

  # Make the monitor directory
  mkdir -p /var/lib/ceph/mon/ceph-${MON_NAME}

  # Prepare the monitor daemon's directory with the map and keyring
  ceph-mon --mkfs -i ${MON_NAME} --monmap /etc/ceph/monmap --keyring /tmp/ceph.mon.keyring

  # Clean up the temporary key
  rm /tmp/ceph.mon.keyring

}

kv_set_default() {
  set +e

  case "$KV_TYPE" in
  'etcd')
    etcdctl --no-sync -C $KV mk $KV_PATH/$1 $2 >/dev/null 2>&1
  ;;
  'consul')
    curl -X PUT -d "${2}" http://${KV}/v1/kv${KV_PATH}/${1}?token=${TOKEN} >/dev/null 2>&1
  ;;
  esac

  if [[ $? -ne 0 && $? -ne 4 ]]; then
    echo "kv_set_default: an error occurred. aborting..."
    exit 1
  fi

  set -e
}

kv_query() {
  case "$KV_TYPE" in
  'etcd')
    etcdctl --no-sync -C $KV get ${KV_PATH}/$1
  ;;
  'consul')
    curl -f http://${KV}/v1/kv${KV_PATH}/${1}?token=${TOKEN}&raw
  ;;
  esac
}

main "$@"
