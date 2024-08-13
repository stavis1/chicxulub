#!/bin/bash
faa=$(sed "${1}q;d" faa_list.txt)
name=$(sed "${1}q;d" basename_list.txt)
echo $1 | tee /dev/stderr
echo $faa | tee /dev/stderr
echo $name | tee /dev/stderr

singularity run --fakeroot --containall --bind ./:/data/ -w --unsquash msconvert.sif wine msconvert --outdir /data/ --outfile $name.indexed.mzML /data/$name.raw
conda run -n search_env python clean_fasta.py $faa $name.faa
./comet.linux.exe -Pcomet.params -D$name.faa $name.indexed.mzML
grep -v -- 'nan' $name.indexed.pin > $name.filtered.pin
singularity run --fakeroot --containall --bind ./:/data/ -w --unsquash percolator.sif percolator -U --reset-algorithm -w /data/$name.weights -m /data/$name.pout /data/$name.filtered.pin
mkdir $name.results
cp $name.pout $name.results
cp -r $name.results ../
