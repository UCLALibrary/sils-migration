import sys
from pymarc import Record, Field, MARCReader, MARCWriter

#SILSLA-13

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
					value = record[old_field]
					field = Field(tag = new_field, data=value)
					record.add_field(field)
					record.remove_field(fld)
					
	return record

def delete_752(record):
	for fld in record.get_fields('752'):
		for sfld in fld.get_subfields('5'):
			if sfld.startswith('CLU'):
				record.remove_field(fld)			
	return record

def clean_record(file_name):
	reader = MARCReader(open(file_name, 'rb'))
	writer = MARCWriter(open('new_file.mrc', 'wb'))
	for record in reader:
		#change_5xx_CLU(record)
		change_CLU(record)
		delete_752(record)
	writer.write(record)
	writer.close()
	reader.close()