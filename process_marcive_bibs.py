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
	delete_856(record)

	# Done making changes, save the changed record to file
	writer.write(record)
    	
# Cleanup
writer.close()
reader.close()
