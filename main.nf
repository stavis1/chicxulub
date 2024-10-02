params.design = "$launchDir/design.tsv"
params.results_dir = launchDir
design = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)

process params_parser {
    container 'stavisvols/params_parser:latest'
    containerOptions "--bind $launchDir:/data/"

    input:
    val row

    output:
    tuple val(row), path('*.params')

    script:
    """
    python /parser/options_parser.py --params /data/${row.options}
    """

}

process msconvert {
    beforeScript 'mkdir wine_temp'
    afterScript 'rm -rf wine_temp'
    container 'stavisvols/msconvert:latest'
    containerOptions "--bind wine_temp:/wineprefix64 --bind $launchDir:/data/"
    publishDir params.results_dir, mode: 'symlink', pattern: '*.mzML'

    input:
    tuple val(row), path(options)

    output:
    tuple val(row), path(options), path("${row.spectra}.mzML")

    script:
    """
    bash /run_msconvert.sh "--outdir ./ --outfile ${row.spectra}.mzML /data/${row.spectra}"
    """
}

process comet {
    container 'stavisvols/comet_for_pipeline:latest'

    input:
    tuple val(row), path(options), path(mzml)

    output:
    tuple val(row), path(options), path(mzml), path("${pin}.pin")

    script:
    pin = mzml.getName()
    """
    /comet/comet.linux.exe -Pcomet.params -D$launchDir/$row.sequences -N$pin $mzml
    grep -vE '[[:space:]]-?nan[[:space:]]' ${pin}.pin > tmp
    mv tmp ${pin}.pin
    """
}

process percolator {
    container 'stavisvols/percolator_for_pipeline:latest'
    publishDir params.results_dir, mode: 'copy', pattern: '*.p*'

    input:
    tuple val(row), path(options), path(mzml), path(pin)

    output:
    tuple val(row), path(options), path(mzml), path(pin), path("${basename}.psms"), path("${basename}.peptides")
    
    script:
    basename = pin.getName()
    """
    percolator \\
        --parameter-file percolator.params \\
        -m ${basename}.psms \\
        -r ${basename}.peptides \\
        $basename
    """
}

process xcms {
    container 'stavisvols/xcms_quantify_features:latest'

    input:
    tuple val(row), path(options), path(mzml), path(pin), path(psms), path(peptides)

    output:
    tuple val(row), path(options), path(mzml), path(pin), path(psms), path(peptides), path("${mzml}.features")

    script:
    """
    Rscript /xcms/xcms_quantify_features.R \\
        --mzml $mzml \\
        --output ${mzml}.features \\
        --xcms_params xcms.params \\
        --peakmerge_params merge.params \\
        --algorithm xcms_cwip
        
    """
}

process feature_mapper {
    container 'stavisvols/feature_mapper:latest'
    publishDir params.results_dir, mode: 'copy', pattern: '*.intensities'

    input:
    tuple val(row), path(options), path(mzml), path(pin), path(psms), path(peptides), path(features)

    output:
    tuple val(row), path(options), path(mzml), path(pin), path(psms), path(peptides), path(features), path("${basename_peptides}.intensities")

    script:
    basename_peptides = peptides.getName()
    """
    python /mapper/feature_mapper.py \\
        --features $features \\
        --peptide $peptides \\
        --psms $psms \\
        --mzml $mzml \\
        --params feature_mapper.params \\
        --output ${basename_peptides}.intensities
    """
}

workflow {    
    //parse the combined parameters file
    params_parser(design)

    //identification
    msconvert(params_parser.out)
    comet(msconvert.out)
    percolator(comet.out)
    
    //quantification
    xcms(percolator.out)
    feature_mapper(xcms.out)
}

