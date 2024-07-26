import sys
import re

with open(sys.argv[1], 'r') as faa_in:
    with open(f'filtered_{sys.argv[1]}', 'w') as faa_out:
        for line in faa_in:
            line = re.sub(r'[^ -~\n]', '', line)
            faa_out.write(line)
