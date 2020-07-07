from pymarc import Record, Field, MARCReader

import re

file_name = '/Users/ashtonprigge/repos/pymarc_work/bib10000.mrc'

"""
#SILSLA-13
def change_5xx_CLU(record):
	for field in range(500, 600):
		if field != 590:
			if record[field] != None:
				value = record[field].value()
				print(value)
				if record[field]['5'] != None:
					subfield = record[field]['5'].value()
					if bool(re.search(r'^CLU', str(subfield))) == True:
						record['590'] = str(value)
						record.remove_field(field)
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
		if record[old_field] != None:
			value = record[old_field].value()
			subfield = record[old_field].get_subfields()
			if record[old_field]['5'] != None:
				subfield = record[old_field]['5'].value() 
				if bool(re.search(r'^CLU', str(subfield))) == True:
					field = Field(tag=new_field)

					#record[new_field] = str(value)
					record.add_field(field)
					record.remove_field(old_field)
	return record

def delete_752_CLU(record):
	if record['752'] != None:
		if record[old_field]['5'] != None:
			subfield = record[old_field]['5'].value()
			if bool(re.search(r'^CLU', str(subfield))) == True:
				record.remove_field('752')
	return record
"""	
def clean_record(file_name):
	reader = MARCReader(open(file_name, 'rb'), permissive=True)
	for record in reader:
		#change_5xx_CLU(record)
		#change_CLU(record)
		#delete_752_CLU(record)
		subfield = record.get_subfields()
		print(subfield)


clean_record(file_name)
