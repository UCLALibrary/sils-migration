import os
import sys
import copy
from pymarc import Record, Field, MARCReader, MARCWriter
from pymarc_extensions import move_field_safe, remove_field_safe

# SILSLA-13

def change_CLU(record):
	"""Change field when original field's $5 starts with CLU"""
	field_mapping = {
		"500": "590",
		"501": "590",
		"506": "596",
		"540": "597",
		"541": "594",
		"561": "591",
		"563": "593",
		"655": "694",
		"692": "696",
		"693": "697",
		"699": "695",
		"700": "970",
		"710": "971",
		"730": "973",
		"740": "974",
	}
	for old_tag in field_mapping.keys():
		new_tag = field_mapping[old_tag]
		for fld in record.get_fields(old_tag):
			if fld["5"] is not None and fld["5"].startswith("CLU"):
				move_field_safe(record, fld, new_tag)

def delete_752(record):
	"""Delete 752 field if its $5 starts with CLU"""
	for fld in record.get_fields("752"):
		if fld["5"] is not None and fld["5"].startswith("CLU"):
			remove_field_safe(record, fld)

def do_SILSLA_13(record):
	change_CLU(record)
	delete_752(record)

# SILSLA-14

def delete_956(record):
	"""Delete all 956 fields"""
	for fld in record.get_fields("956"):
		remove_field_safe(record, fld)

def copy_856(record):
	"""Copy contents of 856 into new 956 field"""
	for fld in record.get_fields("856"):
		fld_956 = copy.copy(fld)
		fld_956.tag = "956"
		record.add_ordered_field(fld_956)

def do_SILSLA_14(record):
	delete_956(record)
	copy_856(record)

# SILSLA-15

def delete_various_9xx(record):
	"""Delete various 9xx fields"""
	for fld in record.get_fields(
		"996", "966", "951", "920", "992", "962", "949", "960", "961", "964", "987", "990"
	):
		remove_field_safe(record, fld)

def get_dbcode(filename):
	"""Helper function to get dbcode from filename"""
	basename = os.path.basename(filename)
	# Assumes caller will name files like ethnodb_bib_..., ucladb_mfhd_... etc.
	dbcode = basename.split("_")[0]
	if dbcode in ["filmntvdb", "ucladb", "ethnodb"]:
		return dbcode
	else:
		raise ValueError(
			f"Usage: {filename} filename must include originating dbcode"
		)

def copy_001(record, dbcode):
	"""Copy 001 field, append dbcode, and add as $a to 996"""
	for fld in record.get_fields("001"):
		voyager_code = "{}-{}".format(copy.copy(fld.value()), dbcode)
		fld_996 = Field(tag="996", indicators=[' ',' '], subfields=['a', voyager_code])
		record.add_ordered_field(fld_996)

def move_6xx(record):
	"""Move various 6xx fields, which used to be in change_CLU()"""
	# Functionally the same as move_9xx, but isolating since last-minute change
	field_mapping = {
		"692": "696",
		"693": "697",
		"699": "695",
	}
	for old_tag in field_mapping.keys():
		new_tag = field_mapping[old_tag]
		for fld in record.get_fields(old_tag):
			move_field_safe(record, fld, new_tag)

def move_9xx(record):
	"""Move various 9xx fields"""
	field_mapping = {"901": "966", "910": "951", "916": "964", "935": "992", "936": "986", "948": "962"}
	for old_tag in field_mapping.keys():
		new_tag = field_mapping[old_tag]
		for fld in record.get_fields(old_tag):
			move_field_safe(record, fld, new_tag)

def move_939_fatadb(record):
	"""For FATADB records, remove 963 field and move 939 to 963"""
	for old_fld in record.get_fields("963"):
		remove_field_safe(record, old_fld)
	for fld in record.get_fields("939"):
		new_tag = "963"
		move_field_safe(record, fld, new_tag)

def delete_remaining_low_9xx(record):
	"""After all the 9xx moves and deletes above, remove remaining 900-949"""
	for tag in range(900, 950):
		# get_fields() requires string argument
		for fld in record.get_fields(str(tag)):
			remove_field_safe(record, fld)

def do_SILSLA_15_bib(record, dbcode):
	delete_various_9xx(record)
	copy_001(record, dbcode)
	move_6xx(record)
	move_9xx(record)
	delete_remaining_low_9xx(record)

#SILSLA-16

def delete_019(record):
	"""Delete all 019 fields"""
	for fld in record.get_fields("019"):
		remove_field_safe(record, fld)

def delete_035_subfield(record):
	"""Delete 035 $9 where appropriate"""
	for fld in record.get_fields("035"):
		if fld["9"] is not None and fld["9"] == 'ExL' and fld["a"] is not None:
			fld.delete_subfield("9")

def delete_035(record):
	"""Delete 035 field where appropriate"""
	for fld in record.get_fields("035"):
		if fld["9"] is not None and fld["9"] == 'ExL' and fld["a"] is None:
			remove_field_safe(record, fld)
		# SILSLA-85: Delete OCLC 035 if it only has $z
		# Confirmed already that all $z fields with no $a have no other subflds
		if fld["z"] is not None and fld["z"].startswith('(OCoLC)') and fld["a"] is None:
			remove_field_safe(record, fld)

def delete_035_no_prefix(record):
	"""Delete 035 field when $a has no (prefix)"""
	for fld in record.get_fields("035"):
		if fld["a"] is not None and fld["a"].startswith('(') is False:
			remove_field_safe(record, fld)

def delete_035_unprefixed_z(record):
	"""Delete each 035 $z with no (prefix), if field has $a (prefix)"""
	for fld in record.get_fields("035"):
		if fld["a"] is not None and fld["a"].startswith('(') is True:
			# PyMARC subfields, as tuples, truly suck
			# Find the start of each unwanted tuple
			# Loop backwards through the unwanted to pop them out of the list
			# Must go backwards since popping the middle changes the list...
			all_idx = [i for i in range(len(fld.subfields)) if (i % 2 == 0 and fld.subfields[i] == "z" and fld.subfields[i+1].startswith('(') is False)]
			for idx in reversed(all_idx):
				fld.subfields.pop(idx)   #pop value
				fld.subfields.pop(idx)   #pop code

def move_035(record):
	"""Move value of 035 $9 to 992 $c"""
	for fld in record.get_fields("035"):
		if fld["9"] is not None and fld["9"] != 'ExL':
			sfld = copy.copy(fld["9"])
			record.remove_field(fld)
			fld_992 = Field(tag="992", indicators=[' ',' '], subfields=['c', sfld])
			record.add_ordered_field(fld_992)

def do_SILSLA_16(record):
	delete_019(record)
	delete_035_subfield(record)
	delete_035(record)
	move_035(record)
	# Do these after other 035 updates
	delete_035_no_prefix(record)
	delete_035_unprefixed_z(record)

if len(sys.argv) != 3:
	raise ValueError(f"Usage: {sys.argv[0]} in_file out_file")

reader = MARCReader(open(sys.argv[1], "rb"), utf8_handling="ignore")
writer = MARCWriter(open(sys.argv[2], "wb"))
dbcode = get_dbcode(sys.argv[1])

for record in reader:
	do_SILSLA_13(record)
	do_SILSLA_14(record)
	if dbcode == "filmntvdb":
		move_939_fatadb(record)
	do_SILSLA_15_bib(record, dbcode)
	do_SILSLA_16(record)
	writer.write(record)

writer.close()
reader.close()
