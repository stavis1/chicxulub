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

workflow eggnog {
    take:
    params
    
    main:
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
    
    emit:
    annotated_faas
}
