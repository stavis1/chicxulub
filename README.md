# Chicxulub
A Nextflow pipeline for computationally intensive searches of large-scale bottom-up proteomics datasets.

## Usage
1. Ensure that you are on a system that has Apptainer, Nextflow, and SLURM.
2. Clone the repositiory by running `git clone https://github.com/stavis1/chicxulub`
3. Edit the nextflow.config file where indicated to use your SLRUM account, maximum queue size, desired partition, and quality of service.
4. Make edit the `default_params.txt` file for your experiment and place it in the same folder as your `.mzML` and `.fasta` files.
5. Fill out a `design.tsv` file based on the template. All paths in the file should be absolute. 
6. Run `nextflow run /path/to/proteomics_cluster_submission/main.nf --design design.tsv` 
