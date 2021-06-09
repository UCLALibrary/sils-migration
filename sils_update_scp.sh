#!/bin/bash

# Extracts SCP records from the UCLA db only,
# calls appropriate cleanup programs for each file,
# and loads updated records back into the relevant database.
# SILSLA-88

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
cd ${DIR}

# Put large files in /tmp
OUT_DIR=/tmp/alma_migration
if [ ! -d ${OUT_DIR} ]; then
  mkdir ${OUT_DIR}
fi

# Only bib records, only UCLA database
TYPE=bib
DB=ucladb
# DB-specific directories for extract program and logs
DB_DIR=/m1/voyager/${DB}

# Code for record type required by the extract program
case ${TYPE} in
  bib ) VGERTYPE=B;;
  *   ) echo "ERROR: Invalid type ${TYPE} - exiting"; exit 1;;
esac

# Run several SQL files, each covering a different scenario with different specs.
# Each spec needs separate/different handling.
for SPEC in 1 2 3 4 5; do
  SQL_FILE=SQL/scp_case${SPEC}.sql
  # Run the query to get the record ids; data will be in SQL_FILE.out in the same directory as SQL_FILE.
  ${VGER_SCRIPT}/vger_sqlplus_run ucla_preaddb ${SQL_FILE}
  ID_FILE=${OUT_DIR}/`basename ${SQL_FILE}.out`
  mv ${SQL_FILE}.out ${ID_FILE}
  wc -l ${ID_FILE}

  # Handle each list of ids differently.
  # Some lists may not be handled within this script (e.g., load into GDC and run a job there).
  case ${SPEC} in
    1 ) echo "##### CASE 1: Run sils_delete_scp_case1.sh #####"
        ;;
    2 ) echo "##### Load ${ID_FILE} into GDC and run a SUPPRESS ALL job #####"
        ;;
3|4|5 ) # Handle these cases the same, except process_scp_bibs.py varies based on case

	    EXTRACT_FILE=${OUT_DIR}/scp_case${SPEC}_${DB}_${TYPE}.mrc
    	UPDATE_FILE=${OUT_DIR}/`basename ${EXTRACT_FILE} .mrc`.out
	    # Extract program adds to existing files, so remove these just in case they exist
	    rm -f ${EXTRACT_FILE} ${UPDATE_FILE}

	    # Extract the records
	    echo -e "\n`date` Extracting ${EXTRACT_FILE} ..."
	    ${DB_DIR}/sbin/Pmarcexport -o${EXTRACT_FILE} -r${VGERTYPE} -mM -t${ID_FILE} -q

	    # Delete the useless export log; assumes no other exports happening during the same time.
	    LOG=`ls -1rt ${DB_DIR}/rpt/log.exp.* 2>/dev/null | tail -1`
	    if [ ${LOG} ]; then
          rm ${LOG}
	    fi

	    # Process the records via python program
	    python3 ${DIR}/process_scp_bibs.py ${EXTRACT_FILE} ${UPDATE_FILE} ${SPEC}

	    # Load the updated records back into Voyager, using the GDC bib import profile
	    ${VGER_SCRIPT}/vger_bulkimport_file_NOKEY ${UPDATE_FILE} ${DB} GDC_B_AU

	    # Clean up
	    rm ${EXTRACT_FILE} ${UPDATE_FILE} ### ${ID_FILE}
        ;;
  esac
done
