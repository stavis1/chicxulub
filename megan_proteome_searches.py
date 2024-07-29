#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jul 22 15:12:02 2024

@author: 4vt
"""

import os
import subprocess
import re
import sys
import time

njobs = int(sys.argv[1])
noext = re.compile(r'(.+)\.[^\.]+\Z')

#parse data
faas = [f for f in os.listdir() if f.endswith('.faa')]
identifiers = [re.search(r'\A([^_]+)_', f).group(1).upper() for f in faas]
mzmls = [re.search(noext,f).group(1) for f in os.listdir() if f.upper().endswith('.MZML')]
completed = [re.search(noext,f).group(1) for f in os.listdir() if f.endswith('.results')]

#set up jobs
jobs = [(f, next((m for m in mzmls if i in m), None)) for f,i in zip(faas, identifiers)]
for job in jobs:
    if job[1] is None:
        print(f'Fasta file {job[0]} does not have a matching mzML file.', flush = True)
jobs = [j for j in jobs if j[1] is not None and j[1] not in completed]
print(f'Now running {len(jobs)} jobs out of {len(faas)} total .faa files.', flush = True)

def run_job(job):
    print(f'Running job {job[0]} {job[1]}', flush = True)
    proc = subprocess.Popen(f'./search_pipeline.sh {job[0]} {job[1]}.', shell = True)
    return proc

#run the scheduler. This will run up to njobs simultaneously.
running = []
while jobs:
    #process finished jobs
    for job in running:
        if job.poll() is not None:
            running.remove(job)
    
    #start new jobs
    for _ in range(njobs - len(running)):
        job = run_job(jobs.pop())
    
    time.sleep(20)

#ensure all jobs run to completion
while running:
    for job in running:
        if job.poll() is None:
            job.wait()
            running.remove(job)
        else:
            running.remove(job)


