#!/bin/sh
# QAD test script

clear
python3 test_pymarc_extensions.py before.mrc after.mrc
marcview.exe before.mrc > before.txt
marcview.exe after.mrc > after.txt
diff before.txt after.txt

