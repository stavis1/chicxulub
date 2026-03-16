process convert_raw_file {
    container 'stavisvols/psp_sipros_mono:latest'
    stageInMode 'link'
    shell '/bin/bash', '-u'

    input:
    tuple val(row), path(options), path(raw_file), path(faa)

    output:
    tuple val(row), path(options), path('*.mzML'), path(faa)

    script:
    """
    if [[ ( $raw_file == *.raw ) || ( $raw_file == *.RAW ) ]]
    then
        (timeout 10m mono /software/ThermoRawFileParser.exe -i $raw_file -o ./ -f 2; exit 0)
        ls *.mzML
    fi
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

workflow peptide_search {
    take:
    params
    
    main:
    //identify peptides
    mapped_features = convert_raw_file(params)
        | comet
        | percolator
    //quantify peptides
        | dinosaur
        | feature_mapper
        | map {data -> data + [file(data[0].organism_map)]}

    emit:
    mapped_features
}
