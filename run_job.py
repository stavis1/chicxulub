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
identifiers = [re.search(r'\A([^_]+)_', f).group(1) for f in faa_files]
basenames = [re.search(r'(.+)\.[^\.]+\Z',f).group(1) for f in os.listdir() if f.lower().endswith('.raw')]

if len(faa_files) > 1:
    jobs = [(faa, next((b for b in basenames if i.lower() in b.lower()), None)) for i,faa in zip(identifiers, faa_files)]
    jobs = [j for j in jobs if j[1] is not None]
else:
    jobs = [(faa_files[0], b) for b in basenames]

with open('faa_list.txt', 'w') as faa_out:
    faa_out.write('\n'.join(j[0] for j in jobs))
with open('basename_list.txt', 'w') as bnames_out:
    bnames_out.write('\n'.join(j[1] for j in jobs))

subprocess.run(f'sbatch --array=1-{len(jobs)} run_pipeline.sbatch', shell = True)

