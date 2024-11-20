#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Oct  7 10:05:12 2024

@author: 4vt
"""

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('--features', action = 'store', required = True,
                    help = 'The feature table output of xcms.sif.')
parser.add_argument('--peptides', action = 'store', required = True,
                    help = 'The peptides output of Percolator.')
parser.add_argument('--psms', action = 'store', required = True,
                    help = 'The psms output of Percolator.')
parser.add_argument('--mzml', action = 'store', required = True,
                    help = 'The mzML file associated with the PSM table.')
parser.add_argument('--params', action = 'store', required = True,
                    help = 'A toml file of parameters')
parser.add_argument('--output', action = 'store', required = True,
                    help = 'The name of the results file.')
args = parser.parse_args()

from collections import defaultdict
from multiprocessing import Pool
import re
import tomllib

import pymzml
from sortedcontainers import SortedList
import numpy as np
import pandas as pd

with open(args.params, 'rb') as params_file:
    params = tomllib.load(params_file)

H = 1.007276
H2O = 18.010565 
aa_masses = {'G':57.021463735,
             'A':71.037113805,
             'S':87.032028435,
             'P':97.052763875,
             'V':99.068413945,
             'T':101.047678505,
             'C':103.009184505 if params['variable_c_alk'] == True else 160.030648505,
             'L':113.084064015,
             'I':113.084064015,
             'N':114.04292747,
             'D':115.026943065,
             'Q':128.05857754,
             'K':128.09496305,
             'E':129.042593135,
             'M':131.040484645,
             'H':137.058911875,
             'F':147.068413945,
             'U':150.953633405,
             'R':156.10111105,
             'Y':163.063328575,
             'W':186.07931298,
             'O':237.147726925}

class Feature:
    def __init__(self, start, end, mz, intensity):
        self.queries = []
        self.start = start
        self.end = end
        self.mz = mz
        self.intensity = intensity
        self.hash = hash((start, end, mz, intensity))
    
    def __hash__(self):
        return self.hash
    
    def is_degenerate(self):
        return len(set(query.seq for query in self.queries)) > 1

class Psm:
    def __init__(self, name, seq, pep):
        self.pep = pep
        self.name = name
        self.scan = int(re.search(r'(\d+)_\d+_\d+\Z', name).group(1))        
        self.seq = re.search(r'\.((?:[A-Z](?:\[[^\]]+\])?)+)\.', seq).group(1)
        self.charge = int(re.search(r'(\d+)_\d+\Z', name).group(1))
        self.rt = scan_rt[self.scan]
        self.features = []

class Query:
    def __init__(self, mz, rt, seq):
        self.hash = hash((mz, rt, seq))
        self.mz = mz
        self.rt = rt
        self.seq = seq
        
    def __hash__(self):
        return self.hash

class Peptide():
    def __init__(self, seq, prots):
        self.seq = re.search(r'\.((?:[A-Z](?:\[[^\]]+\])?)+)\.', seq).group(1)
        self.prots = prots
        self.psms = []
        self.queries = []
        self.features = set()
    
    def add_psm(self, psm):
        self.psms.append(psm)
    
    def make_queries(self):
        pepmass = self.calc_peptide_mass()
        self.queries = [Query(pepmass/p.charge, p.rt, self.seq) for p in self.psms]
        obs_charges = set(psm.charge for psm in self.psms)
        mean_rt = np.mean([psm.rt for psm in self.psms])
        required_charges = [c for c in params['charges'] if c not in obs_charges]
        self.queries.extend([Query(pepmass/c, mean_rt, self.seq) for c in required_charges])
        return self.queries
    
    def find_queries(self, query_map):
        hashes = [hash(q) for q in self.queries]
        self.queries = [query_map[h] for h in hashes]
        self.features = set([feature_map[hash(f)] for q in queries for f in q.features])
    
    def remove_bad_features(self):
        self.features = set(f for f in self.features if not f.is_degenerate())
        
    def calculate_intensity(self):
        self.intensity = np.sum([f.intensity for f in self.features])
    
    def report(self):
        self.remove_bad_features()
        self.calculate_intensity()
        return (self.seq, 
                self.intensity,
                self.prots)

    def calc_peptide_mass(self):
        mass = np.sum([aa_masses[aa] for aa in re.findall(r'[A-Z]', self.seq)])
        mass += np.sum([float(mod) for mod in re.findall(r'\d+(?:\.\d+)?', self.seq)])
        mass += H2O
        return mass

def attach_features(query):
    started_before = set(f[1] for f in rt_starts.irange((query.rt - max_Δrt, ), (query.rt,)))
    ended_after = set(f[1] for f in rt_ends.irange((query.rt, ), (query.rt + max_Δrt,)))
    Δmz = (query.mz/1e6)*params['ppm']
    mz_matched = set(f[1] for f in mzs.irange((query.mz - Δmz,), (query.mz + Δmz,)))
    features = started_before.intersection(ended_after).intersection(mz_matched)
    query.features = features
    return query

#map scan numbers to retention times
run = pymzml.run.Reader(args.mzml)
scan_rt = {s.ID:s.scan_time_in_minutes() for s in run}

#read and process feauture table
feature_table = pd.read_csv(args.features, sep = '\t').replace(0, np.nan)
fcols = ['rtStart', 'rtEnd', 'mz', 'intensityApex']
features = [Feature(start, end, mz, intensity) for start, end, mz, intensity in zip(*[feature_table[c] for c in fcols])]

#make psm objects
psm_table = pd.read_csv(args.psms, sep = '\t')
psm_table = psm_table[psm_table['q-value'] < params['FDR']]
psms = [Psm(name, seq, pep) for name, seq, pep in zip(psm_table['PSMId'], psm_table['peptide'], psm_table['posterior_error_prob'])]

#keep only best scoring PSM per scan
scans = defaultdict(lambda: [])
for psm in psms:
    scans[psm.scan].append(psm)
psms = [min(scan, key = lambda x: x.pep) for scan in scans.values()]

#make peptide objects
peptide_table = pd.read_csv(args.peptides, sep = '\t')
peptide_table = peptide_table[peptide_table['q-value'] < params['FDR']]
peptides = [Peptide(seq, prots) for seq, prots in zip(peptide_table['peptide'], peptide_table['proteinIds'])]

#filter psms to ones that map to extant peptides
observed_peptides = set([p.seq for p in peptides])
psms = [psm for psm in psms if psm.seq in observed_peptides]

#map psms to peptides
peptide_map = {p.seq:p for p in peptides}
for psm in psms:
    peptide_map[psm.seq].add_psm(psm)

#get feature queries
queries = [q for peptide in peptides for q in peptide.make_queries()]

#set up data structures for fast lookup
rt_starts = SortedList([(f.start, f) for f in features], key = lambda x: x[0])
rt_ends = SortedList([(f.end, f) for f in features], key = lambda x: x[0])
max_Δrt = max(f.end - f.start for f in features)
mzs = SortedList([(f.mz, f) for f in features], key = lambda x: x[0])
feature_map = {hash(f):f for f in features}

#map queries to features
with Pool(params['cores']) as p:
    queries = p.map(attach_features, queries)
for query in queries:
    for feature in psm.features:
        feature_map[hash(feature)].queries.append(query)

#map queries back to peptides b/c multiprocessing breaks the connection
query_map = {hash(q):q for q in queries}
for peptide in peptides:
    peptide.find_queries(query_map)

#report quantified peptides
intensities = pd.DataFrame((pep.report() for pep in peptides),
                           columns = ('sequence', 'intensity', 'proteins'))
intensities = intensities[intensities['intensity'] > 0.0]
intensities.to_csv(args.output, sep = '\t', index = False)
