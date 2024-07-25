#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Jul 25 13:01:12 2024

@author: 4vt
"""

import sys
import pandas as pd
import pymzml
import re

sample = sys.argv[1]
pout = pd.read_csv(sample, sep = '\t')
pout['ScanNr'] = [int(re.search(r'(\d+)_\d+_\d+\Z', i).group(1)) for i in pout['PSMId']]
pout['charge'] = [int(re.search(r'(\d+)_\d+\Z', i).group(1)) for i in pout['PSMId']]
pout = pout[pout['q-value'] < 0.01]
pout = pout[[not 'DECOY' in p for p in pout['proteinIds']]]

pin = pd.read_csv(sample[:-5]+'.pin', sep = '\t')
calcmass = {i:m for i,m in zip(pin['SpecId'], pin['CalcMass'])}
pout['CalcMass'] = [calcmass[i] for i in pout['PSMId']]

mzml = pymzml.run.Reader(sample[:-5] + '.mzML')
scan_rt = {s.ID:s.scan_time_in_minutes() for s in mzml}

moff = pd.DataFrame({'peptide':[re.search(r'\.([A-Z]+)\.',re.sub(r'\[.+\]','',p)).group(1) for p in pout['peptide']],
                     'prot':pout['proteinIds'],
                     'mod_peptide':pout['peptide'],
                     'rt':[scan_rt[s] for s in pout['ScanNr']],
                     'mz':(pout['CalcMass']+pout['charge'])/pout['charge'],
                     'mass':pout['CalcMass'],
                     'charge':pout['charge']})

moff.to_csv(sample[:-5] + '.tomoff.txt', sep = '\t', index = False)

    