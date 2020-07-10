#!/bin/bash

# Extracts suppressed bibs with OCLC numbers from all 3 Voyager databases,
# calls appropriate cleanup programs for each file,
# and loads updated records back into the relevant database.
# Uses SQL to target relevant bibs only, since most records
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

# Only bib records, for multiple databases
TYPE=bib
for DB in ethnodb filmntvdb ucladb; do
  # DB-specific directories for extract program and logs
  DB_DIR=/m1/voyager/${DB}

  # Code for record type required by the extract program
  case ${TYPE} in
    bib ) VGERTYPE=B;;
	*   ) echo "ERROR: Invalid type ${TYPE} - exiting"; exit 1;;
  esac

  # Query to get db-specific bib record ids: suppressed records with OCLC numbers
  SQL_FILE=${OUT_DIR}/suppressed_${DB}_${TYPE}.sql
  (
    echo "set linesize 10;"
	echo "select bm.bib_id"
	echo "from ${DB}.bib_master bm"
	echo "inner join ${DB}.bib_index bi on bm.bib_id = bi.bib_id and bi.index_code = '0350' and bi.normal_heading like 'UCOCLC%'"
	echo "where suppress_in_opac = 'Y'"
	echo "order by bm.bib_id;"
  ) > ${SQL_FILE}

  # Run the query to get the record ids; data will be in SQL_FILE.out
  ${VGER_SCRIPT}/vger_sqlplus_run ucla_preaddb ${SQL_FILE}
  ID_FILE=${SQL_FILE}.out
  wc -l ${ID_FILE}

  EXTRACT_FILE=${OUT_DIR}/suppressed_${DB}_${TYPE}.mrc
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
  python3 ${DIR}/process_vanguard_suppressed_bibs.py ${EXTRACT_FILE} ${UPDATE_FILE}

  # Load the updated records back into Voyager
  # TODO: Remove echo
  echo "${VGER_SCRIPT}/vger_bulkimport_file_NOKEY ${UPDATE_FILE} ${DB} GDC_B_AU"

  # Clean up
  # TODO: Remove echo
  echo rm ${EXTRACT_FILE} ${UPDATE_FILE} ${SQL_FILE} ${ID_FILE}

done # DB
