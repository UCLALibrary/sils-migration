#!/bin/bash

# Extracts bib records from all 3 Voyager databases,
# calls appropriate cleanup programs for each file,
# and loads updated records back into the relevant database.
# SILSLA-20

##########################################################################
# Get max record id of a type for a database
_get_max_id() {
  DB=$1
  TYPE=$2
  SCHEMA=ucla_preaddb
  PASSWORD=ucla_preaddb
  SQLFILE=max_${DB}_${TYPE}.sql
  echo "select 'MAXID=', max(${TYPE}_id) from ${DB}.${TYPE}_master;" > ${SQLFILE}
  MAXID=`sqlplus ${SCHEMA}/${PASSWORD} < ${SQLFILE} | grep "MAXID=" | awk '{print $2}'`
  rm ${SQLFILE}
}
##########################################################################

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

##### Main routine starts here #####

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

# Put large files in /tmp
OUT_DIR=/tmp/alma_migration
if [ ! -d ${OUT_DIR} ]; then
  mkdir ${OUT_DIR}
fi

# Only bib records, for multiple databases
TYPE=bib
###for DB in ethnodb filmntvdb ucladb; do
for DB in ucladb; do
  # DB-specific directories for extract program and logs
  DB_DIR=/m1/voyager/${DB}
  # For Oracle USERPASS
  source ${DB_DIR}/ini/voyager.env

  # Code for record type required by the extract program
  case ${TYPE} in
    bib ) VGERTYPE=B;;
    *   ) echo "ERROR: Invalid type ${TYPE} - exiting"; exit 1;;
  esac

  # Set MAXID (largest id in table) with get_max_id function
  _get_max_id ${DB} ${TYPE}
  echo -e "\nExtracting up to ${MAXID} ${TYPE} records from ${DB}"

  # Extract up to 1000 records at a time
  # Assume we'll always start at 1, end at MAXID
  INTERVAL=1000
  START=1
  END=`expr ${START} + ${INTERVAL} - 1`

  # Loop to do the actual work
  while [ ${START} -le ${MAXID} ]; do
    # Save time extracting records: don't look for records beyond MAXID
    if [ ${END} -gt ${MAXID} ]; then
      END=${MAXID}
    fi

    echo "Processing ${DB} ${TYPE} ${START} ${END}: `date`"

	EXTRACT_FILE=${OUT_DIR}/${DB}_${TYPE}_${START}_${END}.mrc
	UPDATE_FILE=${OUT_DIR}/`basename ${EXTRACT_FILE} .mrc`.out
	# Extract program adds to existing files, so remove these just in case they exist
	rm -f ${EXTRACT_FILE} ${UPDATE_FILE}

	# Extract the records
	echo -e "\n`date` Extracting ${EXTRACT_FILE} ..."
	${DB_DIR}/sbin/Pmarcexport -o${EXTRACT_FILE} -r${VGERTYPE} -mR -t${START}-${END} -q

	# Delete the useless export log; assumes no other exports happening during the same time.
	LOG=`ls -1rt ${DB_DIR}/rpt/log.exp.* 2>/dev/null | tail -1`
	if [ ${LOG} ]; then
      rm ${LOG}
	fi

	# Process the records via python program
	python3 ${DIR}/process_general_bibs.py ${EXTRACT_FILE} ${UPDATE_FILE}

    # Above steps are quick, import below is slow; stagger imports to reduce clumping
    ###sleep 15

	# Load the updated records back into Voyager, using the GDC bib import profile
	# ${VGER_SCRIPT}/vger_bulkimport_file_NOKEY ${UPDATE_FILE} ${DB} GDC_B_AU
    # Run bulkimport directly rather than via Pbulkimport script, which complicates parallel runs
    BULKIMPORT="/m1/voyager/bin/2010.0.0/bulkimport -d VGER -u ${USERPASS} -c ${DB_DIR}/ini/voyager.ini"
    # Set a meaningful log name for import
    BULK_NAME=`basename ${UPDATE_FILE}`.bulk
    # Run in background
    ${BULKIMPORT} -L ${BULK_NAME} -f ${UPDATE_FILE} -i GDC_B_AU &

    # Run no more than 6 imports at once; wait here until a slot opens up
    job_limit 6

	# Clean up
	rm ${EXTRACT_FILE} ##### ${UPDATE_FILE}

	# Prepare for next loop iteration
	START=`expr ${START} + ${INTERVAL}`
	END=`expr ${END} + ${INTERVAL}`
  done # Main loop
done # DB


