#!/bin/bash

### WIP ###



# Get voyager environment, for vars and for cron
. `echo $HOME | sed "s/$LOGNAME/voyager/"`/.profile.local

# Is it safe?
if [ `hostname` != "t-w-voyager01" ]; then
  echo "ERROR: This can only run on the test server - exiting"
  exit 1
fi

# Enable python3, which is not on by default for voyager user
source /opt/rh/rh-python38/enable

# Base directory
DIR=/m1/voyager/ucladb/local/sils_migration
cd ${DIR}

# Put large files in /tmp
OUT_DIR=/tmp/vanguard
if [ ! -d ${OUT_DIR} ]; then
  mkdir ${OUT_DIR}
fi

ALL_ID_FILE=${OUT_DIR}/scp_silsla18_case1.sql.out
wc -l ${ALL_ID_FILE}

# Split into 20 files with roughly equal number of lines
# with suffixes of 01...20
FILE_BASE=scp_case1_ids
split --numeric-suffixes=1 --number=l/20 ${ALL_ID_FILE} ${OUT_DIR}/${FILE_BASE}.

BASE=/m1/voyager/ucladb
# For each list of ids, export an interleaved file of bib + mfhd, then delete all via bulkimport.
for ID_FILE in ${OUT_DIR}/${FILE_BASE}.0[1-4]; do
  echo "Processing ${ID_FILE}..."
  MARC_FILE=${OUT_DIR}/`basename ${ID_FILE}`.mrc
  ${BASE}/sbin/Pmarcexport -o${MARC_FILE} -rG -mM -t${ID_FILE} -q

  BULK_NAME=`basename ${MARC_FILE}`.bulk
  # Run bulkimport with -x (del bibs) and -r (del mfhds)
  ${BASE}/sbin/Pbulkimport -f${MARC_FILE} -iGDC_B_AU -L${BULK_NAME} -x -r -M

  # TODO: Lots of stuff for running multiples.....
  # For now, sleep for 60 seconds before starting the next, while testing 4
  sleep 60

  # Clean up
  rm ${ID_FILE} ##### ${MARC_FILE}
done
