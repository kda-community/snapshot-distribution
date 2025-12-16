#!/bin/sh

LIVE_DIR=/live
SNAPSHOT_DIR=/snapshots
COMPACTION_DIR=/compaction_2
COMPACT_BIN=/home/kadena/compact

R_SNAPSHOT_DIR=$LIVE_DIR/0/rocksDb/.zfs/snapshot
S_SNAPSHOT_DIR=$LIVE_DIR/0/sqlite/.zfs/snapshot


do_destroy() {
  local d=$1
  local r_snapshot=tank/live-rocksDb@$d
  local s_snapshot=tank/live-sqlite@$d
  local r_clone=tank/clone-rocksDb-$d
  local s_clone=tank/clone-sqlite-$d
  local r_compacted_vol=tank/compacted-rocksDb-$d
  local s_compacted_vol=tank/compacted-sqlite-$d

  echo "Cleaning $d"a
  echo "-- Destroyng clones"
  zfs destroy $r_clone
  zfs destroy $s_clone

  echo "-- Destroying compacted clones"
  zfs destroy $r_compacted_vol
  zfs destroy $s_compacted_vol

  echo "-- Destroying snapshots"
  zfs destroy $r_snapshot
  zfs destroy $s_snapshot

  echo "-- Cleaniing directores"
  rm -rf $SNAPSHOT_DIR/full/$d
  rm -rf $SNAPSHOT_DIR/compacted/$d

}


do_compaction() {
  local d=$1
  local r_snapshot=tank/live-rocksDb@$d
  local s_snapshot=tank/live-sqlite@$d
  local r_clone=tank/clone-rocksDb-tmp
  local s_clone=tank/clone-sqlite-tmp

  local r_mount=$COMPACTION_DIR/src/0/rocksDb
  local s_mount=$COMPACTION_DIR/src/0/sqlite

  local r_compacted_vol=tank/compacted-rocksDb-$d
  local s_compacted_vol=tank/compacted-sqlite-$d

  local LOG_DIR=$COMPACTION_DIR/logs
  local SRC_DIR=$COMPACTION_DIR/src
  local DST_DIR=$COMPACTION_DIR/dst
  local TMP_DST_DIR=$COMPACTION_DIR/dst/_tmp
  local MAIN_LOG=$LOG_DIR/main.log

  mkdir -p $SRC_DIR/0
  mkdir -p $DST_DIR
  mkdir -p $LOG_DIR

  echo "Doing compaction $d"
  echo "-- Cloning and mounting snapshots for compaction"
  zfs clone -o mountpoint=$r_mount $r_snapshot $r_clone
  zfs clone -o mountpoint=$s_mount $s_snapshot $s_clone

  echo "-- Creating destination volume"
  zfs create -o mountpoint=$COMPACTION_DIR/dst/ -o compression=off $r_compacted_vol

  echo "-- Starting compaction"
  ulimit -n 10000
  # Copy the stdout/stder to another log file
  $COMPACT_BIN  --from $SRC_DIR --to $TMP_DST_DIR --log-dir $LOG_DIR --compact-rocksdb --no-compact-pact 2>&1 | tee $MAIN_LOG
  echo "-- Compaction done"

  # Extract and print compaction height
  local COMPACT_HEIGHT=$(grep -o 'targetBlockHeight: [0-9]\+' $MAIN_LOG | grep -o '[0-9]\+')

  echo "-- Preparing Clones"
  mv $TMP_DST_DIR/0/rocksDb/* $DST_DIR

  # Copy snapshot date
  cat $SRC_DIR/0/rocksDb/snapshot_date > $DST_DIR/snapshot_date

  # Print compaction height
  echo $COMPACT_HEIGHT > $DST_DIR/COMPACTION_HEIGHT

  # Clean Temporary dir
  rm -rf $TMP_DST_DIR

  # Unmount the RocksDB compacted volume
  zfs set mountpoint=none $r_compacted_vol
  # And make it readonly 
  zfs set mountpoint=none $r_compacted_vol
  zfs set readonly=on $r_compacted_vol

  # And do another final clone for Sqlite
  zfs clone -o readonly=on -o mountpoint=none $s_snapshot $s_compacted_vol

  echo "-- Removing temporary clones"
  zfs destroy $r_clone
  zfs destroy $s_clone
  rm -rf $SRC_DIR $DST_DIR
}

do_snapshot() {
  local d=$1
  local r_snapshot=tank/live-rocksDb@$d
  local s_snapshot=tank/live-sqlite@$d
  local r_clone=tank/clone-rocksDb-$d
  local s_clone=tank/clone-sqlite-$d

  echo "Doing snapshot $d"
  # Stop the node
  echo "-- Stopping node"
  systemctl stop chainweb-node
  sleep 10

  echo "-- Cleaning DB"
  cd /live/0/rocksDb
  rm -f *.log
  rm -f *.tmp
  rm -f MANIFEST-*.temp
  rm -f CURRENT.bak
  rm -f OPTIONS-*.bak
  rm -f LOG.old.*

  echo "-- Printing date"
  date > /live/0/rocksDb/snapshot_date
  date > /live/0/sqlite/snapshot_date

  echo "-- Snapshooting the DB"
  zfs snapshot $r_snapshot
  zfs snapshot $s_snapshot

  rm -f /live/0/*/snapshot_date


  echo "-- Restarting node"
  systemctl start chainweb-node

  echo "-- Cloning"
  zfs clone -o readonly=on -o mountpoint=none $r_snapshot $r_clone
  zfs clone -o readonly=on -o mountpoint=none $s_snapshot $s_clone
}

do_mount() {
  local d=$1
  local r_clone=tank/clone-rocksDb-$d
  local s_clone=tank/clone-sqlite-$d
  local r_compacted_vol=tank/compacted-rocksDb-$d
  local s_compacted_vol=tank/compacted-sqlite-$d


  local r_mount=$SNAPSHOT_DIR/full/$d/0/rocksDb
  local s_mount=$SNAPSHOT_DIR/full/$d/0/sqlite
  local r_c_mount=$SNAPSHOT_DIR/compacted/$d/0/rocksDb
  local s_c_mount=$SNAPSHOT_DIR/compacted/$d/0/sqlite

  echo "Mounting Clones"
  mkdir -p $SNAPSHOT_DIR/full/$d
  mkdir -p $SNAPSHOT_DIR/compacted/$d

  zfs set mountpoint=$r_mount $r_clone
  zfs set mountpoint=$s_mount $s_clone
  zfs set mountpoint=$r_c_mount $r_compacted_vol
  zfs set mountpoint=$s_c_mount $s_compacted_vol
}
