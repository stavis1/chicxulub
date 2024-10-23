params.design = "$launchDir/design.tsv"
params.results_dir = launchDir

process params_parser {
    container 'stavisvols/params_parser:latest'
    containerOptions "--bind $launchDir:/data/"

    input:
    val row

    output:
    tuple val(row), path('*_params'), path("$row.spectra"), path("$row.sequences")

    script:
    """
    cp /data/$row.spectra ./
    cp /data/$row.sequences ./
    python /parser/options_parser.py --params /data/${row.options}
    """
}

process comet {
    container 'stavisvols/comet_for_pipeline:latest'

    input:
    tuple val(row), path(options), path(mzml), path(faa)

    output:
    tuple val(row), path(options), path(mzml), path(faa), path("${pin}.pin")

    script:
    pin = mzml.getName()
    """
    /comet/comet.linux.exe -Pcomet_params -D$faa -N$pin $mzml
    grep -vE '[[:space:]]-?nan[[:space:]]' ${pin}.pin > tmp
    mv tmp ${pin}.pin
    """
}

process percolator {
    container 'stavisvols/percolator_for_pipeline:latest'
    publishDir params.results_dir, mode: 'copy', pattern: '*.{psms,peptides}*'

    input:
    tuple val(row), path(options), path(mzml), path(faa), path(pin)

    output:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path("${basename}.psms"), path("${basename}.peptides")
    
    script:
    basename = pin.getName()
    """
    percolator \\
        --parameter-file percolator_params \\
        -m ${basename}.psms \\
        -r ${basename}.peptides \\
        $basename
    """
}

process dinosaur {
    container 'stavisvols/dinosaur_for_pipeline:latest'

    input:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path(psms), path(peptides)

    output:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path(psms), path(peptides), path("${mzml}.features.tsv")

    script:
    """
    java -Xmx16g -jar /dinosaur/Dinosaur.jar --advParams=dinosaur_params --concurrency=4 --outName=${mzml} $mzml
    """
}

process feature_mapper {
    container 'stavisvols/feature_mapper:latest'
    publishDir params.results_dir, mode: 'copy', pattern: '*.intensities'

    input:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path(psms), path(peptides), path(features)

    output:
    tuple val(row), path(options), path(mzml), path(faa), path(pin), path(psms), path(peptides), path(features), path("${basename_peptides}.intensities")

    script:
    basename_peptides = peptides.getName()
    """
    python /mapper/feature_mapper.py \\
        --features $features \\
        --peptide $peptides \\
        --psms $psms \\
        --mzml $mzml \\
        --params feature_mapper_params \\
        --output ${basename_peptides}.intensities
    """
}

process eggnog_db_setup {
    container 'stavisvols/eggnog_for_pipeline:latest'

    input:
    tuple val(id), path(options)

    output:
    tuple val(id), path(id)

    script:
    // """
    // mkdir $id
    // eggnog_wrapper.py --task download --options $options --run_args '-y --data_dir $id'
    // """
    """
    ln -s $launchDir/8350e5a3e24c153df2275c9f80692773 $id
    """
}

process collect_eggnog_search_jobs {
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
    results_id = dl_params_hash + search_params.text.digest('MD2') + faa.text.digest('MD2')
}

process eggnog_search {
    container 'stavisvols/eggnog_for_pipeline:latest'

    input:
    tuple val(id), path(eggnog_database), path(faa_file), path(search_options)

    output:
    tuple val(id), path("${faa_file}.annotations")

    script:
    """
    mkdir $id
    eggnog_wrapper.py --task search --options $search_options --run_args '-i $faa_file -o ${faa_file}.annotations --output_dir ./ --data_dir $eggnog_database'
    """
}

workflow {    
    //parse the combined parameters file
    design = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)
    params_parser(design)

    //download the database files for each unique required eggnog DB
    eggnog_db_list = params_parser.out 
        | map {row, files, mzml, faa -> 
            dl_params = files.find {it.getName() == 'download_eggnog_data_params'}
            [dl_params.text.digest('MD2'), dl_params]
            } 
        | unique {hash, path -> hash}
        | eggnog_db_setup 
        | toList

    //annotate each .faa + db combination using eggnog
    annotated_faas = collect_eggnog_search_jobs(params_parser.out, eggnog_db_list)
        | unique {hash, db, faa, options -> hash}
        | eggnog_search
        | toList

    //identification
    comet(params_parser.out)
    percolator(comet.out)
    
    //quantification
    dinosaur(percolator.out)
    feature_mapper(dinosaur.out)
}

