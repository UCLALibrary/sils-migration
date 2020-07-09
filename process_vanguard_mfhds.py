import os
import sys
from pymarc import Record, Field, MARCReader, MARCWriter

#SILSLA-15

def delete_966(record):
    """Delete 966 fields"""
    for fld in record.get_fields("966"):
        record.remove_field(fld)

def move_901(record):
    """Move 901 field to 966"""
    for fld in record.get_fields("901"):
        print(record)
        fld.tag = "966"
        record.remove_field(fld)
        record.add_ordered_field(fld)
        print(record)

def do_SILSLA_15_mfhd(record):
    delete_966(record)
    move_901(record)

if len(sys.argv) != 3:
    raise ValueError(f"Usage: {sys.argv[0]} in_file out_file")

reader = MARCReader(open(sys.argv[1], "rb"))
writer = MARCWriter(open(sys.argv[2], "wb"))

for record in reader:
    do_SILSLA_15_mfhd(record)
    writer.write(record)

writer.close()
reader.close()

