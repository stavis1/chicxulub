#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Sep 26 13:28:24 2024

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
from functools import cache
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
             'C':103.009184505 if params['variable_c_alk'] == 'variable' else 160.030648505,
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

class keydefaultdict(defaultdict):
    '''
    subclass of defaultdict that passes the key to the first argument of the default function
    '''
    def __missing__(self, key):
        if self.default_factory is None:
            raise KeyError( key )
        else:
            ret = self[key] = self.default_factory(key)
            return ret

def map_feature(psm_idx):
    '''
    arguments:
        psm_index (an integer) refers to the index in the psms table
    returns:
        feature_set (a set) of indices from the feature table that map to the PSM
    '''
    feature_set = set([])
    for charge in range(1,6):
        rt = psm_rt[psm_idx]
        mz = psm_mass[psm_idx]/charge + H
        ppm = (mz/1e6)*float(params['ppm'])
        rtstart_set = set((i[1] for i in rtstart_idx.irange((rt-max_rt_width,), (rt,))))
        rtend_set = set((i[1] for i in rtend_idx.irange((rt,), (rt+max_rt_width,))))
        rt_set = rtstart_set.intersection(rtend_set)
        mz_set = set((i[1] for i in mz_idx.irange((mz-ppm,),(mz+ppm,))))
        feature_set.update(rt_set.intersection(mz_set))
    return feature_set

def peptide_rollup(features, psms):
    '''
    arguments:
        features (a dataframe) must have columns: rt_start, rt_end, mz, intensity
        psms (a dataframe) must have columns: mass, rt, sequence, proteinIds
    returns:
        a dataframe with columns: sequence, intensity, proteins
    note that retention time should be in minutes
    '''
    
    #set up indexes as globals to use in parallelized map_feature() calls
    global psm_rt
    psm_rt = {i:rt for i,rt in zip(psms.index, psms['rt'])}
    global psm_mass
    psm_mass = {i:mass for i,mass in zip(psms.index, psms['mass'])}
    global rtstart_idx
    rtstart_idx = SortedList(zip(features['rt_start'] - float(params['rt_wiggle']), features.index))
    global rtend_idx
    rtend_idx = SortedList(zip(features['rt_end'] + float(params['rt_wiggle']), features.index))
    global max_rt_width
    max_rt_width = max(features['rt_end'] - features['rt_start'])
    global mz_idx
    mz_idx = SortedList(zip(features['mz'], features.index))
    intensity_map = {idx:intensity for idx, intensity in zip(features.index, features['intensity'])}
    
    #connect features to PSMs
    with Pool(params['cores']) as p:
        feature_map = p.map(map_feature, psms.index)
    
    #set up sequence to proteins mapping
    seq_prots = {s:p for s,p in zip(psms['sequence'], psms['proteinIds'])}

    class peptide():
        def __init__(self, seq):
            self.seq = seq
            self.prots = seq_prots[seq]
            self.psm_indices = []
            self.features = set([])
        
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
                    self.prots)
        
    #initialize peptide objects
    peptides = keydefaultdict(peptide)
    for seq, psm, feature_set in zip(psms['sequence'], psms.index, feature_map):
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
        peptide.calculate_intensity(intensity_map)
    
    #make results dataframe
    peptide_data = pd.DataFrame([p.report() for p in peptide_list],
                                columns = ('sequence', 'intensity', 'proteins'))
    return peptide_data

@cache
def calc_peptide_mass(sequence):
    '''
    arguments:
        sequence (a string) the entry in the 'peptide' column of the PSM table
    returns
        a float that is the monoisotopic mass of that peptidoform
    '''
    base_sequence = re.search(r'\A[^\.]+\.((?:[A-Z](?:\[[^\]]+\])?)+)\.[^\.]+\Z', sequence).group(1)
    mass = np.sum([aa_masses[aa] for aa in re.findall(r'[A-Z]', base_sequence)])
    mass += np.sum([float(mod) for mod in re.findall(r'\d+(?:\.\d+)?', base_sequence)])
    mass += H2O
    return mass

#map scan numbers to retention times
run = pymzml.run.Reader(args.mzml)
scan_rt = {s.ID:s.scan_time_in_minutes() for s in run}

#read and process feauture table
features = pd.read_csv(args.features, sep = '\t').replace(0, np.nan)
features.columns = ['mz',
                    'mzmin',
                    'mzmax',
                    'rt',
                    'rt_start',
                    'rt_end',
                    'intensity',
                    'intb',
                    'maxo',
                    'sn',
                    'sample']
features = features[['rt_start', 'rt_end', 'mz', 'intensity']]
features['rt_start'] = features['rt_start']/60
features['rt_end'] = features['rt_end']/60

#read identification tables
psms = pd.read_csv(args.psms, sep = '\t')
peptides = pd.read_csv(args.peptides, sep = '\t')

#filter psms to ones that map to extant peptides
observed_peptides = set(peptides['peptide'])
psms = psms[[pep in observed_peptides for pep in psms['peptide']]]

#set up necessary columns in PSM table
psms['sequence'] = psms['peptide']
psms['mass'] = [calc_peptide_mass(seq) for seq in psms['sequence']]
psms['scan'] = [int(re.search(r'(\d+)_\d+_\d+\Z', i).group(1)) for i in psms['PSMId']]
psms['rt'] = [scan_rt[s] for s in psms['scan']]

intensities = peptide_rollup(features, psms)
intensities.to_csv(args.output, sep = '\t', index = False)
