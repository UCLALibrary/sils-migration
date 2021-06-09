# Functions to do the things PyMARC doesn't do right
from pymarc import Record

def find_matching_880(record, fld):
	# Search the 880 fields for the corresponding $6
	# sfd6 will look like 880-XX; find matching 880 with $6 fld.tag-XX
	# Linking is via $6; there should be only one (if any)
	sfd6 = fld['6']
	if sfd6:
		linking_val = sfd6.replace('880', fld.tag)
		for fld880 in record.get_fields('880'):
			# 880 $6 can have character set info after the link,
			# so take just the first 6 characters
			fld880_linking_val = fld880['6'][0:6]
			if fld880_linking_val == linking_val:
				return fld880

def move_field_safe(record, fld, new_tag):
	# Make sure that when a non-880 is moved (e.g., 939->963),
	# any linked 880 field is updated to point to the new field.
	fld880 = find_matching_880(record, fld)
	if fld880:
		# We know fld880 has a $6 since that's how it was found.
		# Replace the original tag value in $6 with the new one.
		# e.g., 880 $6 old_tag-01 will become 880 $6 new_tag-01.
		old_tag = fld.tag
		fld880['6'] = fld880['6'].replace(old_tag, new_tag)
    # Update the tag in our copy of the field
	fld.tag = new_tag
    # Remove the original field from the record;
    # Don't remove_field_safe(), since we need the 880 to remain.
	record.remove_field(fld)
    # Add new field into the record
	record.add_ordered_field(fld)

def remove_field_safe(record, fld):
	# Make sure any linked 880 field is deleted along with requested field.
	fld880 = find_matching_880(record, fld)
	if fld880:
		record.remove_field(fld880)
	# Finally, call the original
	record.remove_field(fld)
