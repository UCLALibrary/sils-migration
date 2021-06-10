#!/bin/sh
# QAD test script

clear
#python3 test_pymarc_extensions.py before.mrc after.mrc
python3 process_general_bibs.py ucladb_test.mrc after.mrc
marcview.exe ucladb_test.mrc > before.txt
marcview.exe after.mrc > after.txt
diff -y -W 208 before.txt after.txt

