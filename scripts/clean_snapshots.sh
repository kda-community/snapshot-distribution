#/bin/bash

source snapshot_fcts.sh

for i in $(seq 3 30)
  do dt=$(date --date="-${i}day" +%F)
     if [ -x $SNAPSHOT_DIR/full/$dt ] || [ -x $SNAPSHOT_DIR/full/$dt ]
        then do_destroy $dt
     fi
done

