import sys
import copy
from pymarc import Record, Field, MARCReader, MARCWriter

#SILSLA-13

def get_5xx_fields(field_mapping_dict):
	for old_field in range(500, 600):
		if old_field != 590:
			field_mapping_dict[old_field] = '590'

def change_CLU(record):
	"""Change field when original field's $5 starts with CLU"""
	field_mapping = {
					'655':'695',
					'700':'970',
					'710':'971',
					'730':'973',
					'740':'974'
				}
	get_5xx_fields(field_mapping)
	for old_field in field_mapping.keys():
		new_field = field_mapping[old_field]
		for fld in record.get_fields(old_field):
			if fld['5'] != None and fld['5'].startswith('CLU'):
				fld.tag = new_field
				record.add_ordered_field(fld)

def delete_752(record):
	"""Delete 752 field if it's $5 starts with CLU"""
	for fld in record.get_fields('752'):
		if fld['5'] != None and fld['5'].startswith('CLU'):
			record.remove_field(fld)

def do_SILSLA_13(record):
	change_CLU(record)
	delete_752(record)

#SILSLA-14

def delete_956(record):
	"""Delete all 956 fields"""
	for fld in record.get_fields('956'):
		record.remove_field(fld)

def copy_856(record):
	"""Copy contents of 856 into new 956 field"""
	for fld in record.get_fields('856'):
		fld_956 = copy.copy(fld)
		fld_956.tag = '956'
		record.add_ordered_field(fld_956)	

def do_SILSLA_14(record):
	delete_956(record)
	copy_856(record)

if len(sys.argv) != 3:
    raise ValueError(f'Usage: {sys.argv[0]} in_file out_file')

reader = MARCReader(open(sys.argv[1], 'rb'))
writer = MARCWriter(open(sys.argv[2], 'wb'))

for record in reader:
	do_SILSLA_13(record)
	do_SILSLA_14(record)
	writer.write(record)

writer.close()
reader.close()
