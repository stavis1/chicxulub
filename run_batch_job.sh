#!/bin/bash

#SBATCH -A ACF-UTK0011
#SBATCH -p campus
#SBATCH --qos=campus
#SBATCH -t 24:00:00
#SBATCH --nodes=1
#SBATCH -c 8
#SBATCH --mem=32g
#SBATCH -J batch1_searches
#SBATCH --output=batch1_searches_out_%j_%a.log
#SBATCH --error=batch1_searches_err_%j_%a.log
#SBATCH --mail-type=ALL
#SBATCH --mail-user=stavis@vols.utk.edu

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ ! -d $SCRIPT_DIR/env/search_env]; then
	conda env create -p $SCRIPT_DIR/env/search_env -f $SCRIPT_DIR/env/search_env.yml
fi

cd $SCRIPT_DIR/exes/
if [ ! -f comet.linux.exe]; then
        wget https://github.com/UWPR/Comet/releases/download/v2024.01.1/comet.linux.exe
fi

if [ ! -f Dinosaur-1.2.0.free.jar]; then
        wget https://github.com/fickludd/dinosaur/releases/download/1.2.0/Dinosaur-1.2.0.free.jar
fi

if [ ! -f msconvert.sif]; then
	singularity build --fakeroot msconvert.sif docker://proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:latest
fi

if [ ! -f flashlfq.sif]; then
        singularity build --fakeroot flashlfq.sif docker://smithchemwisc/flashlfq:latest
fi

if [ ! -f percolator.sif]; then
	wget https://github.com/percolator/percolator/releases/download/rel-3-07-01/percolator-converters-v3-07-linux-amd64.deb
        singularity build --fakeroot percolator.sif percolator.def
fi

mkdir $1/tmp
cd $1/tmp
cp $SCRIPT_DIR/*.* ./
ln ../*.raw ./
ln ../*.faa ./
ln -s $SCRIPT_DIR/exes/* .

conda run -p $SCRIPT_DIR/env/search_env python run_job.py
