#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Jul 26 16:53:18 2024

@author: 4vt
"""

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-d', '--dinosaur', action = 'store', required = True,
                    help = 'A Dinosaur result file')
parser.add_argument('-p', '--pout', action = 'store', required = True,
                    help = 'A FlashLFQ input file.')
parser.add_argument('-o', '--out', action = 'store', required = True,
                    help = 'The name of the output file.')
parser.add_argument('--fdr', action = 'store', required = False, type = float, default = 0.01,
                    help = 'The name of the output file.')
parser.add_argument('--ppm', action = 'store', required = False, type = float, default = 10, 
                    help = 'The name of the output file.')
parser.add_argument('--charges', action = 'store', required = False, type = str, default = '1,2,3,4,5,6',
                    help = 'The name of the output file.')
parser.add_argument('--cores', action = 'store', required = False, type = int, default = -1,
                    help = 'The name of the output file.')
args = parser.parse_args()
args.charges = list(int(c) for c in args.charge.split(','))
if args.cores < 1:
    import os
    args.cores = os.cpu_count()

from multiprocessing import Pool
from collections import defaultdict
from sortedcontainers import SortedList
import pandas as pd
import numpy as np


#read in data
features = pd.read_csv(args.dinosaur, sep = '\t')
features = features[[c in args.charges for c in features['charge']]]
psms = pd.read_csv(args.pout, sep = '\t')

#build psm index dictionaries for fast lookup
psm_rt = {i:r for i,r in zip(psms.index, psms['Scan Retention Time'])}
psm_mass = {i:m for i,m in zip(psms.index, psms['Peptide Monoisotopic Mass'])}
seq_prots = {s:p for s,p in zip(psms['Full Sequence'], psms['Protein Accession'])}

#build feature indices for fast lookup
rtstart_idx = SortedList(zip(features['rtStart'], features.index))
rtend_idx = SortedList(zip(features['rtEnd'], features.index))
mass_idx = SortedList(zip(features['mass'], features.index))
features['intensityCorr'] = features['intensitySum']/features['charge']
feature_intensity = {idx:i for idx,i in zip(features.index, features['intensityCorr'])}

max_rt_width = max(features['rtEnd'] - features['rtStart'])

#find all features matching to a PSM
def map_feature(psm_idx):
    rt = psm_rt[psm_idx]
    mass = psm_mass[psm_idx]
    ppm = (mass/1e6)*args.ppm
    rtstart_set = set((i[1] for i in rtstart_idx.irange((rt-max_rt_width,), (rt,))))
    rtend_set = set((i[1] for i in rtend_idx.irange((rt,), (rt+max_rt_width,))))
    rt_set = rtstart_set.intersection(rtend_set)
    mass_set = set((i[1] for i in mass_idx.irange((mass-ppm,),(mass+ppm,))))
    feature_set = rt_set.intersection(mass_set)
    return feature_set

#parallelize map_feature() calls
with Pool(args.cores) as p:
    feature_map = p.map(map_feature, range(psms.shape[0]))

#peptide rollup 
class peptide():
    def __init__(self, seq):
        self.seq = seq
        self.psm_indices = []
        self.features = set([])
        self.proteins = seq_prots[self.seq]
    
    def add_psm(self, psm_index, features):
        self.psm_indices.append(psm_index)
        self.features.update(features)
    
    def remove_bad_features(self, bad_features):
        self.features = [f for f in self.features if f not in bad_features]
        
    def calculate_intensity(self, intensity_map):
        self.intensity = np.sum([intensity_map[f] for f in self.features])
    
    def report(self):
        return (self.seq, 
                self.intensity, 
                ';'.join((str(i) for i in self.psm_indices)), 
                ';'.join((str(i) for i in self.features)),
                self.proteins)

class keydefaultdict(defaultdict):
    def __missing__(self, key):
        if self.default_factory is None:
            raise KeyError( key )
        else:
            ret = self[key] = self.default_factory(key)
            return ret

peptides = keydefaultdict(peptide)
for seq, psm, feature_set in zip(psms['Full Sequence'], psms.index, feature_map):
    if feature_set:
        peptides[seq].add_psm(psm, feature_set)

#remove degenerate features
feature_peptides = defaultdict(lambda:[])
for peptide in peptides.values():
    for feature in peptide.features:
        feature_peptides[feature].append(peptide.seq)
bad_features = set(f for f,p in feature_peptides.items() if len(p) > 1)

for peptide in peptides.values():
    peptide.remove_bad_features(bad_features)
peptide_list = [pep for pep in peptides.values() if pep.features]

#calculate intensity
for peptide in peptide_list:
    peptide.calculate_intensity(feature_intensity)

#report
peptide_data = pd.DataFrame(np.array([p.report() for p in peptide_list]),
                            columns = ('sequence', 'intensity', 'psm_indices', 'feature_indices', 'proteins'))
peptide_data.to_csv(args.out, sep = '\t', index = False)

