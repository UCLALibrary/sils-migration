"""
Implements MARC manipulations from sections 3-5 of SILSLA-18.
The program:
* Deletes relevant 590 field(s)
* Deletes relevant 599 field(s)
* Deletes all 793 fields
* Deletes or modifies SCP 856 fields, based on has_po parameter
Parameters:
* in_file: input file of MARC records
* out_file: output file of updated MARC records
* has_po_(Y/N): Y/N flag, whether records have a linked PO.
"""
import sys
from pymarc import MARCReader, MARCWriter

def modify_035(record):
	""" Change 035 prefix from (OCoLC) to (SCP-OCoLC) """
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
                fld.subfields[i+1] = val.replace('(OCoLC)', '(SCP-OCoLC)')

def delete_590(record):
	""" Delete 590 field containing $a UCLA Library - CDL shared resource """
	for fld in record.get_fields('590'):
		# Should be only one $a per 590 field
		if fld['a'].startswith('UCLA Library - CDL shared resource'):
			record.remove_field(fld)

def delete_599(record):
	""" Delete 599 field where $a is UPD or DEL or NEW, and $c is present """
	scp_vals = ['DEL', 'NEW', 'UPD']
	for fld in record.get_fields('599'):
		# Should be only one $a per 599 field
		if (fld['a'] in scp_vals) and (fld['c'] is not None):
			record.remove_field(fld)			

def delete_793(record):
	""" Delete 793 field regardless of content """
	for fld in record.get_fields('793'):
		record.remove_field(fld)

def delete_856(record):
	""" Delete 856 field where $x is CDL or UC open access """
	scp_vals = ['CDL', 'UC open access']
	for fld in record.get_fields('856'):
		# 856 can have multiple $x
		for sfld in fld.get_subfields('x'):
			if sfld in scp_vals:
				record.remove_field(fld)
				# If fld was deleted, break out of the sfld loop
				break

def modify_856(record):
	""" Modify 856 field where $x is CDL or UC open access,
		setting 856 $u dummyURL
	"""
	scp_vals = ['CDL', 'UC open access']
	for fld in record.get_fields('856'):
		# 856 can have multiple $x
		for sfld in fld.get_subfields('x'):
			if sfld in scp_vals:
				# Should be only one $u per 856 field
				fld['u'] = 'dummyURL'
				# If fld was modified, break out of the sfld loop
				break

### Main code starts here ###
if len(sys.argv) != 4:
    raise ValueError(f'Usage: {sys.argv[0]} in_file out_file has_po_(Y/N)')
reader = MARCReader(open(sys.argv[1], 'rb'))
writer = MARCWriter(open(sys.argv[2], 'wb'))
has_po = sys.argv[3]
if has_po not in ['Y', 'N']:
	raise ValueError(f'Invalid value {has_po}; must be Y or N')

for record in reader:
	delete_590(record)
	delete_599(record)
	delete_793(record)
	if has_po == 'Y':
		# Case 4 from specs
		modify_856(record)
	else:
		# Cases 3 and 5 from specs
		delete_856(record)

	# Done making changes, save the changed record to file
	writer.write(record)
    	
# Cleanup
writer.close()
reader.close()
