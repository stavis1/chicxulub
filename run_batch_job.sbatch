#!/bin/bash

#SBATCH -A ACF-UTK0011
#SBATCH -p campus
#SBATCH --qos=campus
#SBATCH -t 24:00:00
#SBATCH --nodes=1
#SBATCH -c 8
#SBATCH --mem=32g
#SBATCH -J batch1_searches
#SBATCH --output=setup_out_%j_%a.log
#SBATCH --error=setup_err_%j_%a.log
#SBATCH --mail-type=ALL
#SBATCH --mail-user=stavis@vols.utk.edu

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ ! -d ~/.conda/envs/search_env ]; then
	conda env create -n search_env -f $SCRIPT_DIR/env/search_env.yml
fi

cd $SCRIPT_DIR/exes/
if [ ! -f comet.linux.exe ]; then
        wget https://github.com/UWPR/Comet/releases/download/v2024.01.1/comet.linux.exe
	chmod +x comet.linux.exe
fi

if [ ! -f Dinosaur-1.2.0.free.jar ]; then
        wget https://github.com/fickludd/dinosaur/releases/download/1.2.0/Dinosaur-1.2.0.free.jar
fi

if [ ! -f msconvert.sif ]; then
	singularity build --fakeroot msconvert.sif docker://proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:latest
fi

if [ ! -f flashlfq.sif ]; then
        singularity build --fakeroot flashlfq.sif flashlfq.def
fi

if [ ! -f percolator.sif ]; then
	wget https://github.com/percolator/percolator/releases/download/rel-3-07-01/percolator-noxml-v3-07-linux-amd64.deb
        singularity build --fakeroot percolator.sif percolator.def
fi

rm -r $1/tmp
mkdir $1/tmp
cd $1/tmp
cp $SCRIPT_DIR/*.* ./
ln ../*.raw ./
ln ../*.faa ./
ln ../comet.params ./
ln -s $SCRIPT_DIR/exes/* .

conda run -n search_env python run_job.py
