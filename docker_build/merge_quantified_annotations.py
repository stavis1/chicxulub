#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Oct 23 14:11:09 2024

@author: 4vt
"""

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-t', '--toml', action = 'store', required = True,
                    help = 'The options toml.')
parser.add_argument('-d', '--data_dir', action = 'store', required = False, default = './',
                    help = 'Where the data files to merge are stored.')
parser.add_argument('-e', '--extension', action = 'store', required = True,
                    help = 'The file extension that single-run quantification files use.')
parser.add_argument('-p', '--pep_extension', action = 'store', required = True,
                    help = 'The file extension that single-run quantification files use.')
parser.add_argument('-o', '--out', action = 'store', required = True,
                    help = 'The base name for all results files.')
args = parser.parse_args()

import tomllib
import os
import re
import pandas as pd

#parse options file
with open(args.toml, 'rb') as toml:
    options = tomllib.load(toml)

#the quantification files for all annotation types
all_files = [f for f in os.listdir(args.data_dir) if f.endswith(args.extension)]

#we make a single combined output for each annotation type
for ann_type in options['annotation_classes']:
    extension = re.compile(f'\\.{ann_type}\\.{args.extension}\\Z')
    files = [os.path.join(args.data_dir, f) for f in all_files if re.search(extension, f) is not None]
    
    data = []
    for f in files:
        newdata = pd.read_csv(f, sep = '\t')
        newdata.index = newdata['annotation']
        del newdata['annotation']
        suffix = re.search(f'([^\\\\/]+)\\.intensities\\..+\\.{args.extension}\\Z', f).group(1)
        newdata.columns = [f'{c}_{suffix}' for c in newdata.columns]
        data.append(newdata)
    data = pd.concat(data, axis = 1)
    data.to_csv(f'{args.out}.{ann_type}.quantification', sep = '\t')

#the peptide quantification files
extension = re.compile(args.pep_extension)
pep_files =  [os.path.join(args.data_dir, f) for f in os.listdir(args.data_dir) if f.endswith(args.pep_extension)]

#make a merged output for peptide intensity quantifications
data = []
for f in pep_files:
    newdata = pd.read_csv(f, sep = '\t')
    newdata.index = newdata['sequence']
    del newdata['sequence']
    suffix = re.search(f'([^\\\\/]+)\\.intensities\\..+\\.{args.extension}\\Z', f).group(1)
    newdata.columns = [f'{c}_{suffix}' for c in newdata.columns]
    data.append(newdata)
data = pd.concat(data, axis = 1)
data.to_csv(f'{args.out}.peptides.quantification', sep = '\t')

