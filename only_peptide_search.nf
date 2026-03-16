include { process_params } from './subworkflows/process_params' 
include { peptide_search } from './subworkflows/peptide_search' 

params.results_dir = "$launchDir/results"

workflow {    
    params = process_params()
    mapped_features = peptide_search(params)
}
