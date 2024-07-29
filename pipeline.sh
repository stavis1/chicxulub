#!/bin/bash
faa=$(sed "${1}q;d" faa_list.txt)
name=$(sed "${1}q;d" basename_list.txt)

singularity run --fakeroot msconvert.sif wine msconvert --outfile $name.indexed.mzML $name.mzML
conda run -p ~/search_env python clean_fasta.py $faa
./comet.linux.exe -Pmegan_searches.params -Dfiltered_$faa $name.indexed.mzML
grep -v -- 'nan' $name.indexed.pin > $name.filtered.pin
singularity run percolator.sif percolator -U --reset-algorithm -m $name.pout $name.filtered.pin
conda run -p ~/search_env python percolator_to_flashlfq.py $name.pout
mkdir $name.results
singularity run flashlfq.sif --thr 8 --idt $name.txt --rep ./ --out $name.results
java -jar Dinosaur-1.2.0.free.jar --outDir=$name.results $name.indexed.mzML
conda run -p ~/search_env python match_dinosaur_peaks.py -d $name.results/$name.indexed.features.tsv -p $name.txt -o $name.results/$name.peptide_AUC.tsv
