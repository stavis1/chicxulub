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

./pipeline.sh $SLURM_ARRAY_TASK_ID
