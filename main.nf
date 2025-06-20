params.results_dir = "$launchDir/results"

process params_parser {
    container 'stavisvols/params_parser:latest'

    input:
    tuple val(row), path(options), path(spectra), path(sequences)

    output:
    tuple val(row), path('*_params'), path(spectra), path(sequences)

    script:
    """
    python /parser/options_parser.py --params ${row.options}
    """
}

process comet {
    container 'stavisvols/comet_for_pipeline:latest'

    input:
    tuple val(row), path(options), path(mzml), path(faa)

    output:
    tuple val(row), path(options), path(mzml), path(faa), path("${pin}.pin")

    script:
    pin = row.identifier
    """
    /comet/comet.linux.exe -Pcomet_params -D$faa -N$pin $mzml
    grep -vE '[[:space:]]-?nan[[:space:]]' ${pin}.pin > tmp
    mv tmp ${pin}.pin
    """
}

process percolator {
    container 'stavisvols/percolator_for_pipeline:latest'
    containerOptions "--bind $launchDir:/data/"

    input:
    tuple val(row), path(options), path(mzml), path(faa), path(pin)

    output:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path("${basename}.psms"), path("${basename}.peptides")
    
    script:
    basename = row.identifier
    """
    percolator \\
        --parameter-file percolator_params \\
        -m ${basename}.psms \\
        -r ${basename}.peptides \\
        ${basename}.pin
    """
}

process dinosaur {
    container 'stavisvols/dinosaur_for_pipeline:latest'

    input:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path(psms), path(peptides)

    output:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path(psms), path(peptides), path("${basename}.features.tsv")

    script:
    basename = row.identifier
    """
    timeout -k 5 60m java -Xmx16g -jar /dinosaur/Dinosaur.jar --advParams=dinosaur_params --concurrency=4 --nReport=0 --outName=${basename} $mzml && : || :
    ls *.features.tsv
    """
}

process feature_mapper {
    container 'stavisvols/feature_mapper:latest'
    publishDir params.results_dir, mode: 'copy', pattern: '*.filtered'
    
    input:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path(psms), path(peptides), path(features)

    output:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path("${basename}.psms.filtered"), path("${basename}.peptides.filtered"), path(features), path("${basename}.intensities"), path(options), path(faa)

    script:
    basename = row.identifier
    """
    python /mapper/feature_mapper.py \\
        --features $features \\
        --peptide $peptides \\
        --psms $psms \\
        --mzml $mzml \\
        --params feature_mapper_params \\
        --output ${basename}.intensities
    """
}

process eggnog_db_setup {
    container 'stavisvols/eggnog_for_pipeline:latest'
    containerOptions "--bind $projectDir/cache:/cache/"
    publishDir "$projectDir/cache/", mode: 'copy', pattern: "$id", overwrite: false

    input:
    tuple val(id), path(options)

    output:
    tuple val(id), path(id)

    script:
    """
    if [ -e /cache/$id ]; then
        cp -r /cache/$id ./
    elif [ -e /cache/precomputed ]; then
        mkdir $id
    else
        mkdir $id
        eggnog_wrapper.py --task download --options $options --run_args '-y --data_dir $id'
    fi
    """
}

process collect_eggnog_search_jobs {
    cache false

    input:
    tuple val(row), val(options), path(mzml), val(faa)
    val eggnog_db_list

    output:
    tuple val(results_id), path(linked_database), path(linked_faa), path(linked_params)

    exec:
    //find eggnog database
    dl_params_hash = options.find {it.getName() == 'download_eggnog_data_params'}
    dl_params_hash = dl_params_hash.text.digest('MD2')
    eggnog_database = eggnog_db_list.find {it[0] == dl_params_hash}
    eggnog_database = file(eggnog_database[1])

    //link eggnog database to workDir
    linked_database = task.workDir.resolve(eggnog_database.getName())
    eggnog_database.mklink(linked_database)

    //find eggnog search params and link them to workDir
    search_params = options.find {it.getName() == 'emapper_params'}
    linked_params = task.workDir.resolve(search_params.getName())
    search_params.mklink(linked_params)

    //link faa file to workDir
    linked_faa = task.workDir.resolve(faa.getName())
    faa.mklink(linked_faa)

    //calculate job hash for uniqueness check
    results_id = dl_params_hash + search_params.text.digest('MD2') + faa.getBaseName()
}

process eggnog_search {
    container 'stavisvols/eggnog_for_pipeline:latest'
    containerOptions "--bind $workDir/emapper_cache:/cache/"
    publishDir "$workDir/emapper_cache/$id", mode: 'copy', pattern: "${faa_file}.emapper.annotations", overwrite: false
    beforeScript "if [ ! -d $workDir/emapper_cache/$id ]; then mkdir -p $workDir/emapper_cache/$id; fi"


    input:
    tuple val(id), path(eggnog_database), path(faa_file), path(search_options)

    output:
    tuple val(id), path("${faa_file}.emapper.annotations")

    script:
    """
    if [ -f /cache/$id/${faa_file}.emapper.annotations ]; then
        cp /cache/$id/${faa_file}.emapper.annotations ${faa_file}.emapper.annotations
    elif [ -e /cache/precomputed ]; then
        cp /cache/precomputed/precomputed.emapper.annotations ${faa_file}.emapper.annotations
    else
        eggnog_wrapper.py --task search --options $search_options --run_args '-i $faa_file -o ${faa_file} --output_dir ./ --data_dir $eggnog_database'
    fi
    """
}

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

workflow {    
    //make results directory
    file(params.results_dir).mkdir()
    file(params.design).copyTo(params.results_dir)

    //parse the combined parameters file
    params = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)
        | map {r -> tuple(r, file(r.options), file(r.spectra), file(r.sequences))}
        | params_parser

    //download the database files for each unique required eggnog DB
    eggnog_db_list = params 
        | map {row, files, mzml, faa -> 
            dl_params = files.find {it.getName() == 'download_eggnog_data_params'}
            [dl_params.text.digest('MD2'), dl_params]
            } 
        | unique {hash, path -> hash}
        | eggnog_db_setup 
        | toList

    //annotate each .faa + db combination using eggnog
    annotated_faas = collect_eggnog_search_jobs(params, eggnog_db_list)
        | unique {hash, db, faa, options -> hash}
        | eggnog_search
        | toList

    //identify peptides
    mapped_features = comet(params)
        | percolator
    //quantify peptides
        | dinosaur
        | feature_mapper
        | map {data -> data + [file(data[0].organism_map)]}
 
    //quantify annotations and merge results
    qauantify_annotations(mapped_features, annotated_faas)
        | flatten
        | unique { it.getName() }
        | collect
        | merge_quantified_annotations
}

