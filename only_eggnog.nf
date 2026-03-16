include { process_params } from './subworkflows/process_params' 
include { eggnog } from './subworkflows/eggnog' 

params.results_dir = "$launchDir/results"

workflow {    
    params = process_params()
    annotated_faas = eggnog(params)
}

