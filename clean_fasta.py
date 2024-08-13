import sys
import re

with open(sys.argv[1], 'r') as faa_in:
    with open(sys.argv[2], 'w') as faa_out:
        for line in faa_in:
            line = re.sub(r'[^ -~\n]', '', line)
            line = re.sub(r'\*', '', line)
            faa_out.write(line)
