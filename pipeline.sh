#!/bin/bash
faa=$(sed "${1}q;d" faa_list.txt)
name=$(sed "${1}q;d" basename_list.txt)
echo $1
echo $faa
echo $name

singularity run --fakeroot --containall --bind ./:/data/ -w --unsquash msconvert.sif wine msconvert --outdir /data/ --outfile $name.indexed.mzML /data/$name.raw
conda run -n search_env python clean_fasta.py $faa
./comet.linux.exe -Pcomet.params -Dfiltered_$faa $name.indexed.mzML
grep -v -- 'nan' $name.indexed.pin > $name.filtered.pin
singularity run --fakeroot --containall --bind ./:/data/ -w --unsquash percolator.sif percolator -U --reset-algorithm -m /data/$name.pout /data/$name.filtered.pin
conda run -n search_env python percolator_to_flashlfq.py $name.pout
mkdir $name.results
cp $name.pout $name.results
java -jar Dinosaur-1.2.0.free.jar --outDir=$name.results $name.indexed.mzML
conda run -n search_env python match_dinosaur_peaks.py -d $name.results/$name.indexed.features.tsv -p $name.txt -o $name.results/$name.peptide_AUC.tsv
cp -r $name.results ../
