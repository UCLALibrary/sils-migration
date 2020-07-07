""" Very basic program to dump binary MARC files as text """
import sys
from pymarc import MARCReader, TextWriter

if len(sys.argv) != 3:
    raise ValueError(f'Usage: {sys.argv[0]} marc_file text_file')
reader = MARCReader(open(sys.argv[1], 'rb'))
writer = TextWriter(open(sys.argv[2], 'wt'))

for record in reader:
	writer.write(record)

writer.close()
reader.close()

