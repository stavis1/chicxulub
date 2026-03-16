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

workflow process_params {
    main:
    //make results directory
    file(params.results_dir).mkdir()
    file(params.design).copyTo(params.results_dir)

    //parse the combined parameters file
    params = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)
        | map {r -> tuple(r, file(r.options), file(r.spectra), file(r.sequences))}
        | params_parser

    emit:
    params
}
