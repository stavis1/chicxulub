#!/bin/bash

work_dir=$1
cd $work_dir
#Set up conda environment for python scripts
#At each step of this script we skip the step if it has already been done
if [ ! -d ~/.conda/envs/search_env ]; then
    conda env create -n search_env -f env/search_env.yml
fi

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
    singularity build percolator.sif docker://stavisvols/percolator_for_pipeline
fi
