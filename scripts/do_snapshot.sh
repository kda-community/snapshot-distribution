#/bin/bash

source snapshot_fcts.sh

DATE=$(date +%F)

if [ -x $SNAPSHOT_DIR/full/$DATE ] || [ -x $SNAPSHOT_DIR/full/$DATE ]
then echo "Snapshot already exist"
else do_snapshot $DATE 
     do_compaction $DATE 
     do_mount $DATE 
fi

