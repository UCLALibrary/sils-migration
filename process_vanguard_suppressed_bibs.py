import sys
import copy
from pymarc import Record, Field, MARCReader, MARCWriter

#SILSLA-17

def modify_suppressed_bibs(record):
    """Replace (OCoLC) with (Suppressed) in 035 $a for suppressed records"""
    for fld in record.get_fields("035"):
        # 035 should not have multiple $a... but some records do
        # Subfield iteration and manipulation in pymarc is ... not good.
        # fld.get_subfields('a') returns only values; fld.subfields returns a list 
        # with code,value,code,value etc. - not a list of tuples....
        # Old-school loop over fld.subfields, getting 2 values (code,val) at a time;
        # change relevant subfields.
        for i in range(0, len(fld.subfields), 2):
            code, val = fld.subfields[i], fld.subfields[i+1]
            if code == 'a' and val.startswith('(OCoLC)'):
                fld.subfields[i+1] = val.replace('(OCoLC)', '(Suppressed)')

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

