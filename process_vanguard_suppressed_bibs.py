import os
import sys
import copy
from pymarc import Record, Field, MARCReader, MARCWriter

#SILSLA-17

def modify_suppressed_bibs(record):
	"""Replace (OCoLC) with (Suppressed) in 035 $a for suppressed records"""
	for fld in record.get_fields("035"):
		if fld["a"] is not None and fld["a"].startswith("(OCoLC)"):
			fld["a"] = (fld["a"]).replace("(OCoLC)", "(Suppressed)")

def do_SILSLA_17(record):
	modify_suppressed_bibs(record)

if len(sys.argv) != 3:
    raise ValueError(f"Usage: {sys.argv[0]} in_file out_file")

reader = MARCReader(open(sys.argv[1], "rb"))
writer = MARCWriter(open(sys.argv[2], "wb"))

for record in reader:
	do_SILSLA_17(record)
	writer.write(record)

writer.close()
reader.close()