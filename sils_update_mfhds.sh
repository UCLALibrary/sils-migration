#!/bin/bash

# Extracts holdings records from all 3 Voyager databases,
# calls appropriate cleanup programs for each file,
# and loads updated records back into the relevant database.
# Uses SQL to target relevant holdings only, since most records
# do not need changing.
# SILSLA-20

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
OUT_DIR=/tmp/vanguard
if [ ! -d ${OUT_DIR} ]; then
  mkdir ${OUT_DIR}
fi

# Only holdings records, for multiple databases
TYPE=mfhd
for DB in ethnodb filmntvdb ucladb; do
  # DB-specific directories for extract program and logs
  DB_DIR=/m1/voyager/${DB}

  # Code for record type required by the extract program
  case ${TYPE} in
    mfhd ) VGERTYPE=H;;
	*    ) echo "ERROR: Invalid type ${TYPE} - exiting"; exit 1;;
  esac

  # Query to get db-specific holdings record ids with 901 fields
  SQL="set linesize 10;\nselect distinct record_id from vger_subfields.${DB}_mfhd_subfield where tag like '901%' order by record_id;"
  SQL_FILE=${OUT_DIR}/${DB}_${TYPE}.sql
  echo -e ${SQL} > ${SQL_FILE}

  # Run the query to get the record ids; data will be in SQL_FILE.out
  ${VGER_SCRIPT}/vger_sqlplus_run ucla_preaddb ${SQL_FILE}
  ID_FILE=${SQL_FILE}.out
  wc -l ${ID_FILE}

  EXTRACT_FILE=${OUT_DIR}/${DB}_${TYPE}.mrc
  UPDATE_FILE=${OUT_DIR}/`basename ${EXTRACT_FILE} .mrc`.out
  # Extract program adds to existing files, so remove these just in case they exist
  rm -f ${EXTRACT_FILE} ${UPDATE_FILE}

  # Extract the records, using the ids from the SQL results
  echo -e "\n`date` Extracting ${EXTRACT_FILE} ..."
  ${DB_DIR}/sbin/Pmarcexport -o${EXTRACT_FILE} -r${VGERTYPE} -mM -t${ID_FILE} -q

  # Delete the useless export log; assumes no other exports happening during the same time.
  LOG=`ls -1rt ${DB_DIR}/rpt/log.exp.* 2>/dev/null | tail -1`
  if [ ${LOG} ]; then
    rm ${LOG}
  fi

  # Process the records via python program
  python3 ${DIR}/process_vanguard_mfhds.py ${EXTRACT_FILE} ${UPDATE_FILE}

  # Load the updated records back into Voyager
  # TODO: Remove echo... and write program
  echo "***** You can't use bulk import for this, so write a program!"

  # Clean up
  # TODO: Remove echo
  echo rm ${EXTRACT_FILE} ${UPDATE_FILE} ${SQL_FILE} ${ID_FILE}

done # DB
