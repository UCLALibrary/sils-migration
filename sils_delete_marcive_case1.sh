#!/bin/bash

###############################################################
# Function to allow only N jobs to run at once #####
# Credit: https://stackoverflow.com/a/33048123
job_limit () {
    # Test for single positive integer input
    if (( $# == 1 )) && [[ $1 =~ ^[1-9][0-9]*$ ]]
    then
        # Check number of running jobs
        joblist=($(jobs -rp))
        while (( ${#joblist[*]} >= $1 ))
        do
            # Wait for any job to finish
            command='wait '${joblist[0]}
            for job in ${joblist[@]:1}
            do
                command+=' || wait '$job
            done
            eval $command
            joblist=($(jobs -rp))
        done
   fi
}
###############################################################

### Main script starts here ###

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
OUT_DIR=/tmp/alma_migration
if [ ! -d ${OUT_DIR} ]; then
  mkdir ${OUT_DIR}
fi

ALL_ID_FILE=${OUT_DIR}/marcive_case1.sql.out
wc -l ${ALL_ID_FILE}

# Split into 1000 files with roughly equal number of lines
# with suffixes of 000..999
FILE_BASE=marcive_case1_ids
split --numeric-suffixes --number=l/1000 ${ALL_ID_FILE} ${OUT_DIR}/${FILE_BASE}.

BASE=/m1/voyager/ucladb
# For Oracle USERPASS
source ${BASE}/ini/voyager.env

# Run bulkimport directly rather than via Pbulkimport script, which complicates parallel runs
BULKIMPORT="/m1/voyager/bin/2010.0.0/bulkimport -d VGER -u ${USERPASS} -c ${BASE}/ini/voyager.ini"

# For each list of ids, export an interleaved file of bib + mfhd, then delete all via bulkimport.
for SEQ in `seq -w 0 999`; do
  ID_FILE=${OUT_DIR}/${FILE_BASE}.${SEQ}
  echo "Processing ${ID_FILE}..."
  MARC_FILE=${OUT_DIR}/`basename ${ID_FILE}`.mrc
  ${BASE}/sbin/Pmarcexport -o${MARC_FILE} -rG -mM -t${ID_FILE} -q

  # Extracts are quick; wait 10 seconds before starting the import, to reduce clumping
  sleep 10

  # Set a meaningful log name for import
  BULK_NAME=`basename ${MARC_FILE}`.bulk
  # Run bulkimport with -x (del bibs) and -r (del mfhds)
  # Run in background
  ${BULKIMPORT} -L ${BULK_NAME} -f ${MARC_FILE} -i GDC_B_AU -x -r &

  # Run no more than 6 imports at once; wait here until a slot opens up
  job_limit 6

  # Clean up
  rm ${ID_FILE}
  # These can't be deleted here as bulkimport is using them in the background
  ##### rm ${MARC_FILE} ${RPT}/*.marcive_case1_ids.${SEQ}.mrc.bulk
  # OK to remove cumulative files of deleted records, which slow down performance as they grow
  rm ${RPT}/deleted.bib.marc ${RPT}/deleted.mfhd.marc

done

