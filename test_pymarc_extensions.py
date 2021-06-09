import sys
from pymarc import MARCReader, MARCWriter
from pymarc_extensions import move_field_safe, remove_field_safe

if len(sys.argv) != 3:
	raise ValueError(f'Usage: {sys.argv[0]} in_file out_file')
reader = MARCReader(open(sys.argv[1], 'rb'))
writer = MARCWriter(open(sys.argv[2], 'wb'))

def test_remove_field_safe(record):
	for fld in record.get_fields('650'):
		remove_field_safe(record, fld)

def test_move_field_safe(record):
	for fld in record.get_fields('500'):
		move_field_safe(record, fld, '995')

for record in reader:
	#test_remove_field_safe(record)
	test_move_field_safe(record)
	# Done making changes, save the changed record to file
	writer.write(record)
		
# Cleanup
writer.close()
reader.close()
