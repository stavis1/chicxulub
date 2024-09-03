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
    singularity build --fakeroot msconvert.sif docker://proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:latest
    #Some clusters don't allow users to build containers so we fall back on remote builds
    return_code=$?
    if [ $return_code != 0 ]; then
        singularity build --remote msconvert.sif docker://proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:latest
    fi
fi

#Build percolator container
if [ ! -f percolator.sif ]; then
    singularity build --fakeroot percolator.sif percolator.def
    return_code=$?
    if [ $return_code != 0 ]; then
        singularity build --remote percolator.sif percolator.def
        return_code=$?
        if [ $return_code != 0 ]; then
            echo 'There appears to be something wrong with singularity remote builds. Try running "singularity remote login"'
        fi
    fi
fi
