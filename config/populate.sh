#!/bin/bash
#populate the KV store with ceph.conf parameters

IP="192.168.200.90"


#ceph-common
consuloretcd -A ${IP} put -c common/cephx true
consuloretcd -A ${IP} put -c common/cephx_require_signatures false
consuloretcd -A ${IP} put -c common/cephx_cluster_require_signatures true
consuloretcd -A ${IP} put -c common/cephx_service_require_signatures false
consuloretcd -A ${IP} -c common/max_open_files 131072
consuloretcd -A ${IP} -c common/disable_in_memory_logs true

#monitor
consuloretcd -A ${IP} -c mon/mon_osd_down_out_interval 600
consuloretcd -A ${IP} -c mon/mon_osd_min_down_reporters 4
consuloretcd -A ${IP} -c mon/mon_clock_drift_allowed .15
consuloretcd -A ${IP} -c mon/mon_clock_drift_warn_backoff 30
consuloretcd -A ${IP} -c mon/mon_osd_full_ratio .95
consuloretcd -A ${IP} -c mon/mon_osd_nearfull_ratio .85
consuloretcd -A ${IP} -c mon/mon_osd_report_timeout 300

#osd
consuloretcd -A ${IP} -c osd/journal_size 100
consuloretcd -A ${IP} -c osd/pool_default_pg_num 128
consuloretcd -A ${IP} -c osd/pool_default_pgp_num 128
consuloretcd -A ${IP} -c osd/pool_default_size 3
consuloretcd -A ${IP} -c osd/pool_default_min_size 1
consuloretcd -A ${IP} -c osd/cluster_network 192.168.42.0/24
consuloretcd -A ${IP} -c osd/public_network 192.168.42.0/24
consuloretcd -A ${IP} -c osd/osd_mkfs_type xfs
consuloretcd -A ${IP} -c osd/osd_mkfs_options_xfs "-f -i size=2048"
consuloretcd -A ${IP} -c osd/osd_mount_options_xfs noatime,largeio,inode,swalloc
consuloretcd -A ${IP} -c osd/osd_mon_heartbeat_interval 30

#crush
consuloretcd -A ${IP} -c crush/pool_default_crush_rule 0
consuloretcd -A ${IP} -c crush/osd_crush_update_on_start true

#backend
consuloretcd -A ${IP} -c backend/osd_objectstore filestore

#performance tuning
consuloretcd -A ${IP} -c perf/filestore_merge_threshold 40
consuloretcd -A ${IP} -c perf/filestore_split_multiple 8
consuloretcd -A ${IP} -c perf/osd_op_threads 8
consuloretcd -A ${IP} -c perf/filestore_op_threads 8
consuloretcd -A ${IP} -c perf/filestore_max_sync_interval 5
consuloretcd -A ${IP} -c perf/osd_max_scrubs 1

#recovery tuning
consuloretcd -A ${IP} -c rec/osd_recovery_max_active 5
consuloretcd -A ${IP} -c rec/osd_max_backfills 2
consuloretcd -A ${IP} -c rec/osd_recovery_op_priority 2
consuloretcd -A ${IP} -c rec/osd_client_op_priority 63
consuloretcd -A ${IP} -c rec/osd_recovery_max_chunk 1048576
consuloretcd -A ${IP} -c rec/osd_recovery_threads 1

#ports
consuloretcd -A ${IP} -c ports/mon_port 6789
consuloretcd -A ${IP} -c ports/ms_bind_port_min 6800
consuloretcd -A ${IP} -c ports/ms_bind_port_max 7100


#rbd
consuloretcd -A ${IP} -c rbd/rbd_cache_enabled true
consuloretcd -A ${IP} -c rbd/rbd_cache_writethrough_until_flush true

#other
consuloretcd -A ${IP} -c other/use_inktank_ceph_repo true
consuloretcd -A ${IP} -c other/iscsi_support false
consuloretcd -A ${IP} -c other/ceph_reduced_log_verbosity false
consuloretcd -A ${IP} -c other/radosgw false
consuloretcd -A ${IP} -c other/mds false