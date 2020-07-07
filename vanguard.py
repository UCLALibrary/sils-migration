import sys
from pymarc import Record, Field, MARCReader, MARCWriter

#SILSLA-13

def modify_5xx(record):
	for old_field in range(500, 600):
		if old_field != 590:
			for fld in record.get_fields(old_field):
				for sfld in fld.get_subfields('5'):
					if sfld.startswith('CLU'):
						fld.tag = '590'
						record.add_ordered_field(fld)
	return record

def change_CLU(record):
	field_mapping = {
					'655':'695',
					'700':'970',
					'710':'971',
					'730':'973',
					'740':'974'
				}
	for old_field in field_mapping.keys():
		new_field = field_mapping[old_field]
		for fld in record.get_fields(old_field):
			for sfld in fld.get_subfields('5'):
				if sfld.startswith('CLU'):
					fld.tag = new_field
					record.add_ordered_field(fld)
	return record

def delete_752(record):
	for fld in record.get_fields('752'):
		for sfld in fld.get_subfields('5'):
			if sfld.startswith('CLU'):
				record.remove_field(fld)			
	return record

def clean_record(file_name=None, out_file=None):
	reader = MARCReader(open(file_name, 'rb'))
	writer = MARCWriter(open(outfile, 'wb'))
	for record in reader:
		modify_5xx(record)
		change_CLU(record)
		delete_752(record)
		print(record)
		writer.write(record)
	writer.close()
	reader.close()