include { process_params } from './subworkflows/process_params' 
include { eggnog } from './subworkflows/eggnog' 
include { peptide_search } from './subworkflows/peptide_search' 
include { quantify } from './subworkflows/quantify' 

params.results_dir = "$launchDir/results"

workflow {    
    params = process_params()
    annotated_faas = eggnog(params)
    mapped_features = peptide_search(params)
    quantify(mapped_features, annotated_faas)
}

