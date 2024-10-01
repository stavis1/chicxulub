# -*- coding: utf-8 -*-
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-p', '--params', action = 'store', required = True,
                    help = 'The parameters file to parse.')
args = parser.parse_args()

with open(args.params, 'r') as params:
    files = {f.split('\n')[0]:'\n'.join(f.split('\n')[1:]).strip()+'\n' for f in params.read().split('##')[1:]}

for file_name in files.keys():
    with open(file_name, 'w') as file:
        file.write(files[file_name])

