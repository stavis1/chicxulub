#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Oct 23 11:28:36 2024

@author: 4vt
"""

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-e', '--eggnog', action = 'store', required = True,
                    help = 'The eggnog .annotations file.')
parser.add_argument('-p', '--peptides', action = 'store', required = True,
                    help = 'The .intensities file from the feature mapper step.')
parser.add_argument('-t', '--toml', action = 'store', required = True,
                    help = 'The options toml.')
parser.add_argument('-o', '--out', action = 'store', required = True,
                    help = 'The base name for all results files.')
parser.add_argument('-m', '--organisms', action = 'store', required = False, default = False,
                    help = 'A tab separated mapping between fasta headers and organism IDs.')
args = parser.parse_args()

import tomllib
from collections import defaultdict
import numpy as np
import pandas as pd

class keydefaultdict(defaultdict):
    '''
    subclass of defaultdict that passes the key to the first
    argument of the default function
    '''
    def __missing__(self, key):
        if self.default_factory is None:
            raise KeyError( key )
        else:
            ret = self[key] = self.default_factory(key)
            return ret

class Annotation:
    def __init__(self, name):
        self.name = name
        self.coherent = 0
        self.all = 0
        self.npeptides = 0
        self.ncoherent = 0
    
    def add_intensity(self, val, is_coherent):
        if np.isfinite(val):
            if is_coherent:
                self.coherent += val
                self.ncoherent += 1
            self.npeptides += 1
            self.all += val
    
    def report(self):
        return (self.name, self.coherent, self.ncoherent, self.all, self.npeptides)

class Peptide:
    def __init__(self, sequence, intensity, proteins):
        self.sequence = sequence
        self.intensity = intensity
        self.proteins = proteins.split(options['protein_delimiter'])
        self.coherent_annotations = {}
        self.incoherent_annotations = {}
    
    def annotate_self(self, protein_annotations):
        for ann_type in options['annotation_classes']:
            if not ann_type == 'protein':
                annotations = [protein_annotations[ann_type][protein] for protein in self.proteins]
                annotations = [a for a in annotations if a] #remove unannotated proteins
                all_annotations = set([ann for prot_anns in annotations for ann in prot_anns])
                
                #coherent annotations show up in all proteins that a peptide maps to.
                if annotations:
                    #we find the mutual intersection of all sets of annotations.
                    coherent = set(annotations.pop())
                    for prot_anns in annotations:
                        coherent &= set(prot_anns)
                    self.coherent_annotations[ann_type] = coherent
                else:
                    self.coherent_annotations[ann_type] = set()
                
                #incoherent annotations show up in only a subset of proteins a peptide maps to.
                self.incoherent_annotations[ann_type] = all_annotations - self.coherent_annotations[ann_type]
            
        #add protein as an annotation 
        if len(self.proteins) == 1:
            self.coherent_annotations['protein'] = set(self.proteins)
        else:
            self.coherent_annotations['protein'] = set()
        self.incoherent_annotations['protein'] = set(self.proteins)
            
#parse options file
with open(args.toml, 'rb') as toml:
    options = tomllib.load(toml)

#read eggnog data
eggnog = pd.read_csv(args.eggnog, skiprows = 4, sep = '\t')
eggnog = eggnog[[not p.startswith('##') for p in eggnog['#query']]]
if 'COG_category' in options['annotation_classes']:
    eggnog['COG_category'] = [','.join(c) for c in eggnog['COG_category']]

#add organism information to eggnog file
if args.organisms:
    organism_file = pd.read_csv(args.organisms, sep = '\t', header = None)
    organism_map = defaultdict(lambda : '-',
                               {header.split()[0]:org for header, org in zip(organism_file.iloc[:,0], organism_file.iloc[:,1])})
    eggnog['organism'] = [organism_map[p] for p in eggnog['#query']]

#collect eggnog annotation information
protein_annotations = {}
for ann_type in options['annotation_classes']:
    if ann_type != 'protein':
        protein_annotation_map = {prot:anns.split(',') for prot, anns in zip(eggnog['#query'], eggnog[ann_type]) if anns != '-'}
        protein_annotations[ann_type] = defaultdict(lambda: [], protein_annotation_map)    

#collect peptide information
peptide_quants = pd.read_csv(args.peptides, sep = '\t')
total_intensity = np.nansum(peptide_quants['intensity'])
peptides = [Peptide(s, i, p) for s,i,p in zip(peptide_quants['sequence'], peptide_quants['intensity'], peptide_quants['proteins'])]
for peptide in peptides:
    peptide.annotate_self(protein_annotations)

#sum peptide intensities across annotation objects
annotations = {ann_type:keydefaultdict(Annotation) for ann_type in options['annotation_classes']}
for ann_type in options['annotation_classes']:
    for peptide in peptides:
        for annotation in peptide.coherent_annotations[ann_type]:
            annotations[ann_type][annotation].add_intensity(peptide.intensity, is_coherent = True)
        for annotation in peptide.incoherent_annotations[ann_type]:
            annotations[ann_type][annotation].add_intensity(peptide.intensity, is_coherent = False)

#write report files
for ann_type in options['annotation_classes']:
    report = pd.DataFrame([ann.report() for ann in annotations[ann_type].values()],
                          columns = ['annotation', 'coherent_fraction', 'N_coherent', 'all_fraction', 'N_all'])
    report['coherent_fraction'] = report['coherent_fraction']/total_intensity
    report['all_fraction'] = report['all_fraction']/total_intensity
    report.to_csv(f'{args.out}.{ann_type}.quants', sep = '\t', index = False)
