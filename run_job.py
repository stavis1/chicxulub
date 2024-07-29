#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jul 29 10:46:29 2024

@author: 4vt
"""

import os
import re
import subprocess

faa_files = [f for f in os.listdir() if f.endswith('.faa')]
identifiers = [re.search(r'\A([^_]+)_', f) for f in faa_files]
basenames = [re.search(r'(.+)\.[^\.]+\Z',f).group(1) for f in os.listdir() if f.lower().endswith('.raw')]

jobs = [(faa, next((b for b in basenames if i in b), None)) for i,faa in zip(identifiers, faa_files)]
jobs = [j for j in jobs if j[1] is not None]

with open('faa_list.txt', 'w') as faa_out:
    faa_out.write('\n'.join(j[0] for j in jobs))
with open('basename_list.txt', 'w') as bnames_out:
    bnames_out.write('\n'.join(j[0] for j in jobs))

with open('run_pipeline.sbatch', 'r') as sbatch_in:
    with open('this_batch_pipeline_runner.sbatch','w') as sbatch_out:
        for line in sbatch_in:
            if line.startswith('#SBATCH --array'):
                line = re.sub(r'(=1-)\d+', f'\1{len(jobs)}', line)
            sbatch_out.write(line)
    
subprocess.run('sbatch this_batch_pipeline_runner.sbatch', shell = True)

