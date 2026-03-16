process qauantify_annotations {
    container 'stavisvols/quantify_annotations:latest'
    containerOptions "--bind $launchDir:/data/"

    input:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path(psms), path(peptides), path(features), path(intensities), val(option_paths), val(faa_path), path(organism_map)
    val annotated_faas

    output:
    tuple path('*.quants'), path(options), path(intensities)

    script:
    //calculate job hash to identify correct annotated fasta
    dl_params_hash = option_paths.find {it.getName() == 'download_eggnog_data_params'}
    dl_params_hash = dl_params_hash.text.digest('MD2')
    search_params_hash = option_paths.find {it.getName() == 'emapper_params'}
    search_params_hash = search_params_hash.text.digest('MD2')
    faa_name = faa_path.getBaseName()
    id = dl_params_hash + search_params_hash + faa_name

    //find annotated fasta
    annotations = annotated_faas.find {it[0] == id}[1]
    
    """
    if [ -s $organism_map ]; then
        python /scripts/quantify_annotations.py --eggnog $annotations --peptides $intensities --toml eggnog_quantification_params --out $intensities --organisms $organism_map
    else
        python /scripts/quantify_annotations.py --eggnog $annotations --peptides $intensities --toml eggnog_quantification_params --out $intensities
    fi
    """
}

process merge_quantified_annotations {
    container 'stavisvols/quantify_annotations:latest'
    publishDir params.results_dir, mode: 'copy'

    input:
    path quantified_annotations

    output:
    path '*.quantification'

    script:
    """
    python /scripts/merge_quantified_annotations.py --toml eggnog_quantification_params --extension quants --pep_extension intensities --out merged --data_dir ./
    """
}

workflow quantify {
    take:
    mapped_features
    annotated_faas
    
    main:
    //quantify annotations and merge results
    qauantify_annotations(mapped_features, annotated_faas)
        | flatten
        | unique { it.getName() }
        | collect
        | merge_quantified_annotations
}
