#!/usr/bin/env bash

launchDir=$1
msconvert=$2
spectra=$3
wine_temp=$(mktemp -d)

singularity run --containall --bind $launchDir:/data/ --bind $wine_temp:/wineprefix64 $msconvert bash /run_msconvert.sh "--outdir /data/ --outfile $spectra.mzML /data/$spectra"
rm -rf $wine_temp
mv $launchDir/$spectra.mzML ./
