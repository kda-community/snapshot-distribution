#!/bin/bash

CHECKSUM_TMP_DIR="/checksummer"
CHECKSUM_FILE=BLAKE2SUMS
CHECKSUM_BIN=b2sum


do_checksum_volume() {
 local v=$1
 local ro_property=$(zfs get -H readonly $v | cut -f3)
 local mount_property=$(zfs get -H mountpoint $v | cut -f3)
 local tmpdir=$(mktemp -d "$CHECKSUM_TMP_DIR/csum.XXXXXX")
 mkdir -p $tmpdir 

 zfs set readonly=off $v
 zfs set mountpoint=$tmpdir $v

 cd $tmpdir

 if [ -f $CHECKSUM_FILE ]
 	then rm -f $CHECKSUM_FILE 
 fi

 $CHECKSUM_BIN * > $CHECKSUM_FILE

 cd $CHECKSUM_TMP_DIR

 zfs set mountpoint=$mount_property $v
 zfs set readonly=$ro_property $v

 rm -rf $tmpdir
}

