# proteomics_cluster_submission
A Nextflow pipeline for computationally intensive searches of large-scale bottom-up proteomics datasets.

## Usage
1. Ensure that you are on a system that has Singularity, Nextflow, and SLURM.
2. Clone the repositiory by running `git clone https://github.com/stavis1/proteomics_cluster_submission`
3. Edit the nextflow.config file where indicated to use your SLRUM account, maximum queue size, desired partition, and quality of service.
4. Make parameters files for comet and xcms and place them in the directory with your .raw and .faa files.
5. Fill out a design.tsv file based on the template. All paths in the file should be absolute. 
6. Run `nextflow run /path/to/proteomics_cluster_submission/main.nf --design design.tsv` 
