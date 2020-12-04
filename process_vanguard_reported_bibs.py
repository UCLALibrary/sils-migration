import sys
import copy
from pymarc import Record, Field, MARCReader, MARCWriter

#SILSLA-47

def modify_reported_bibs(record):
    """Replace (OCoLC) with (Reported) in any 035 subfield for reported records"""
    for fld in record.get_fields("035"):
        # 035 should not have multiple $a... but some records do
        # Subfield iteration and manipulation in pymarc is ... not good.
        # fld.get_subfields('a') returns only values; fld.subfields returns a list 
        # with code,value,code,value etc. - not a list of tuples....
        # Old-school loop over fld.subfields, getting 2 values (code,val) at a time;
        # change relevant subfields.
        for i in range(0, len(fld.subfields), 2):
            code, val = fld.subfields[i], fld.subfields[i+1]
            if val.startswith('(OCoLC)'):
                fld.subfields[i+1] = val.replace('(OCoLC)', '(Reported)')

def do_SILSLA_47(record):
    modify_reported_bibs(record)

if len(sys.argv) != 3:
    raise ValueError(f"Usage: {sys.argv[0]} in_file out_file")

reader = MARCReader(open(sys.argv[1], "rb"))
writer = MARCWriter(open(sys.argv[2], "wb"))

for record in reader:
    do_SILSLA_47(record)
    writer.write(record)

writer.close()
reader.close()

