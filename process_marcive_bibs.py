"""
Implements MARC manipulations for case 2 of SILSLA-48 (MARCIVE bibs).
The program:
* Deletes all 856 fields in the given record.
Parameters:
* in_file: input file of MARC records
* out_file: output file of updated MARC records
"""
import sys
from pymarc import MARCReader, MARCWriter

def modify_035(record):
	""" Change 035 prefix from (OCoLC) to (MARCIVE) """
	for fld in record.get_fields('035'):
		# Prefix should only be in $a, for these records
		# 035 should not have multiple $a... but some records do
		# Subfield iteration and manipulation in pymarc is ... not good.
		# fld.get_subfields('a') returns only values
		# fld.subfields returns a list
		# with code,value,code,value etc. - not a list of tuples....
		# Old-school loop over fld.subfields, getting 2 values (code,val) at a time;
		# change relevant subfields.
		for i in range(0, len(fld.subfields), 2):
			code, val = fld.subfields[i], fld.subfields[i+1]
			if val.startswith('(OCoLC)'):
				fld.subfields[i+1] = val.replace('(OCoLC)', '(MARCIVE)')

def delete_856(record):
	""" Delete 856 field regardless of content """
	for fld in record.get_fields('856'):
		record.remove_field(fld)

### Main code starts here ###
if len(sys.argv) != 3:
	raise ValueError(f'Usage: {sys.argv[0]} in_file out_file')
reader = MARCReader(open(sys.argv[1], 'rb'))
writer = MARCWriter(open(sys.argv[2], 'wb'))

for record in reader:
	# Update 035, only if 008/23 = o
	# Don't make me iterate through non-repeatable fields...
	format = record.get_fields('008')[0].value()[23:24]
	if format == 'o':
		modify_035(record)
	
	delete_856(record)

	# Done making changes, save the changed record to file
	writer.write(record)
		
# Cleanup
writer.close()
reader.close()
