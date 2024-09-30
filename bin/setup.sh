#!/usr/bin/env bash

work_dir=$1
cd $work_dir/exes/
#Download comet executable
if [ ! -f comet.linux.exe ]; then
    wget https://github.com/UWPR/Comet/releases/download/v2024.01.1/comet.linux.exe
    chmod +x comet.linux.exe
fi

#Build singularity contianer
if [ ! -f msconvert.sif ]; then
    singularity build msconvert.sif docker://stavisvols/msconvert:latest
fi

#Build percolator container
if [ ! -f percolator.sif ]; then
    singularity build percolator.sif docker://stavisvols/percolator_for_pipeline:latest
fi

#Build xcms container
if [ ! -f xcms.sif ]; then
    singularity build xcms.sif docker://stavisvols/xcms_quantify_features:latest
fi

#Build feature mapper container
if [ ! -f feature_mapper.sif ]; then
    singularity build feature_mapper.sif docker://stavisvols/feature_mapper:latest
fi
