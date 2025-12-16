#/bin/bash

source snapshot_fcts.sh

TO_KEEP=5

for i in $(seq $TO_KEEP 30)
  do dt=$(date --date="-${i}day" +%F)
     if [ -x $SNAPSHOT_DIR/full/$dt ] || [ -x $SNAPSHOT_DIR/full/$dt ]
        then do_destroy $dt
     fi
done

