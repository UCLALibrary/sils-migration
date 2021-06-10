#!/bin/sh
# QAD test script

clear
for DB in ethnodb filmntvdb ucladb; do
  TEST_BASE=${DB}_test
  rm ${TEST_BASE}*
  # symlinked files can't be handled by windows marcview.exe
  cp -p mega_test_record.mrc ${TEST_BASE}.mrc
  python3 process_general_bibs.py ${TEST_BASE}.mrc ${TEST_BASE}_after.mrc
  marcview.exe ${TEST_BASE}.mrc > ${TEST_BASE}_before.txt  
  marcview.exe ${TEST_BASE}_after.mrc > ${TEST_BASE}_after.txt  
  #diff -y -W 208 ${TEST_BASE}_before.txt ${TEST_BASE}_after.txt
  grep FTVA ${TEST_BASE}*.txt
done

