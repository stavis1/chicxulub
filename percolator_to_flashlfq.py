#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jul 22 16:02:31 2024

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

flfq = pd.DataFrame({'File Name':[sample[:-5] + '.mzML']*pout.shape[0],
                     'Base Sequence':[re.search(r'\.([A-Z]+)\.',re.sub(r'\[.+\]','',p)).group(1) for p in pout['peptide']],
                     'Full Sequence':pout['peptide'],
                     'Peptide Monoisotopic Mass':pout['CalcMass'],
                     'Scan Retention Time':[scan_rt[s] for s in pout['ScanNr']],
                     'Precursor Charge':pout['charge'],
                     'Protein Accession':pout['proteinIds']})

flfq.to_csv(sample[:-5] + '.txt', sep = '\t', index = False)

    