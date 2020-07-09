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

##### Main routine starts here #####

# Get voyager environment, for vars and for cron
. `echo $HOME | sed "s/$LOGNAME/voyager/"`/.profile.local

# Enable python3, which is not on by default for voyager user
source /opt/rh/rh-python38/enable

# Base directory
DIR=/m1/voyager/ucladb/local/sils_migration

# Put large files in /tmp
OUT_DIR=/tmp/vanguard
if [ ! -d ${OUT_DIR} ]; then
  mkdir ${OUT_DIR}
fi

# Only bib records, for multiple databases
TYPE=bib
######for DB in ethnodb filmntvdb ucladb; do
for DB in ethnodb; do
  # DB-specific directories for extract program and logs
  DB_DIR=/m1/voyager/${DB}

  # Code for record type required by the extract program
  case ${TYPE} in
    bib ) VGERTYPE=B;;
  esac

  # Set MAXID (largest id in table) with get_max_id function
  _get_max_id ${DB} ${TYPE}
  echo -e "\nExtracting up to ${MAXID} ${TYPE} records from ${DB}"

  # Extract up to 100K records at a time
  # Assume we'll always start at 1, end at MAXID
  INTERVAL=100000
  START=1
  END=`expr ${START} + ${INTERVAL} - 1`

  # Loop to do the actual work
  while [ ${START} -le ${MAXID} ]; do
    # Save time extracting records: don't look for records beyond MAXID
    if [ ${END} -gt ${MAXID} ]; then
      END=${MAXID}
    fi

	EXTRACT_FILE=${OUT_DIR}/${DB}_${TYPE}_${START}_${END}.mrc
	UPDATE_FILE=${OUT_DIR}/`basename ${EXTRACT_FILE} .mrc`.out
	# Extract program adds to existing files, so remove these just in case they exist
	rm -f ${EXTRACT_FILE} ${UPDATE_FILE}

	# Extract the records
	echo -e "\n`date` Extracting ${EXTRACT_FILE} ..."
	# TODO: Remove echo
	echo ${DB_DIR}/sbin/Pmarcexport -o${EXTRACT_FILE} -r${VGERTYPE} -mR -t${START}-${END} -q

	# Delete the useless export log; assumes no other exports happening during the same time.
	LOG=`ls -1rt ${DB_DIR}/rpt/log.exp.* 2>/dev/null | tail -1`
	# TODO: Remove echo
	if [ ${LOG} ]; then
      echo rm ${LOG}
	fi

	# Process the records via python program
	# TODO: Remove echo
	echo python3 ${DIR}/vanguard.py ${EXTRACT_FILE} ${UPDATE_FILE}

	# Load the updated records back into Voyager, using the GDC bib import profile
	# TODO: Remove echo
	echo ${VGER_SCRIPT}/vger_bulkimport_file_NOKEY ${UPDATE_FILE} ${DB} GDC_B_AU

	# Clean up
	# TODO: Remove echo
	echo rm ${EXTRACT_FILE} ${UPDATE_FILE}

	# Prepare for next loop iteration
	START=`expr ${START} + ${INTERVAL}`
	END=`expr ${END} + ${INTERVAL}`
  done # Main loop
done # DB


