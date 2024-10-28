#!/bin/bash

#slurm directives
#SBATCH -A bsd
#SBATCH -p batch
#SBATCH --qos=bsd-batch
#SBATCH -t 4:00:00
#SBATCH --nodes=1
#SBATCH -c 1
#SBATCH --mem=16g
#SBATCH -J msconvert

#parse inputs
temp_dir=$(realpath $1)
raw_dir=$(realpath $2)
msconvert=$(realpath $3)

#set up workspace
if [ ! -d $temp_dir ]; then
	mkdir $temp_dir
fi
cd $temp_dir

#make a array job script
cat > array_job.sbatch << 'EOL'
#!/bin/bash

#slurm directives
#SBATCH -A bsd
#SBATCH -p batch
#SBATCH --qos=bsd-batch
#SBATCH -t 4:00:00
#SBATCH --nodes=1
#SBATCH -c 1
#SBATCH --mem=16g
#SBATCH -J msconvert

#parse inputs
temp_dir=$(realpath $1)
raw_dir=$(realpath $2)
msconvert=$(realpath $3)
file_number=$SLURM_ARRAY_TASK_ID
pid=$$

#find the raw file to convert
shopt -s nocaseglob
raws=($(find $raw_dir -iname '*.raw'))
raw=${raws[$file_number]}

#set up workspace
mkdir $temp_dir/$pid
mkdir $temp_dir/$pid/wine_temp
mkdir $temp_dir/$pid/data
cp $raw $temp_dir/$pid/data
cd $temp_dir/$pid

#run msconvert
singularity run --bind data/:/data/ --bind wine_temp:/wineprefix64 $msconvert bash /run_msconvert.sh "--outdir /data/ /data/$raw"

#clean up workspace
mv data/*.mzML $raw_dir
cd ..
rm -rf $pid
EOL

#find the number of raw files to convert
n_raws=$(find $raw_dir -iname '*.raw' -printf '.' | wc -m)

#submit the slurm array job
sbatch --array=0-$n_raws array_job.sbatch $temp_dir $raw_dir $msconvert
