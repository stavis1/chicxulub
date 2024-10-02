params.design = "$launchDir/design.tsv"
params.results_dir = launchDir
design = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)

process msconvert {
    beforeScript 'mkdir wine_temp'
    afterScript 'rm -rf wine_temp'
    container 'stavisvols/msconvert:latest'
    containerOptions '--bind wine_temp:/wineprefix64'
    publishDir params.results_dir, mode: 'symlink', pattern: '*.mzML'

    input:
    val row

    output:
    tuple val(row), path("${row.spectra}.mzML"), emit: mzml

    script:
    """
    bash /run_msconvert.sh "--outdir ./ --outfile ${row.spectra}.mzML $launchDir/${row.spectra}"
    """
}

process comet {
    container 'stavisvols/comet_for_pipeline:latest'

    input:
    tuple val(row), path(mzml)

    output:
    tuple val(row), path(mzml), path("${pin}.pin"), emit: pin

    script:
    pin = mzml.getName()
    """
    /comet/comet.linux.exe -P$launchDir/$row.params -D$launchDir/$row.sequences -N$pin $mzml
    grep -vE '[[:space:]]-?nan[[:space:]]' ${pin}.pin > tmp
    mv tmp ${pin}.pin
    """
}

process percolator {
    container 'stavisvols/percolator_for_pipeline:latest'
    publishDir params.results_dir, mode: 'copy', pattern: '*.p*'

    input:
    tuple val(row), path(mzml), path(pin)

    output:
    tuple val(row), path(mzml), path(pin), path("${basename}.psms"), path("${basename}.peptides"), emit: pout
    
    script:
    basename = pin.getName()
    """
    percolator \\
        -K ';' \\
        -m ${basename}.psms \\
        -r ${basename}.peptides \\
        $basename
    """
}

process xcms {
    container 'stavisvols/xcms_quantify_features:latest'

    input:
    tuple val(row), path(mzml), path(pin), path(psms), path(peptides)

    output:
    tuple val(row), path(mzml), path(pin), path(psms), path(peptides), path("${mzml}.features"), emit: features

    script:
    """
    Rscript /xcms/xcms_quantify_features.R \\
        --mzml $mzml \\
        --output ${mzml}.features \\
        --xcms_params $launchDir/$row.xcms_params \\
        --peakmerge_params $launchDir/$row.merge_params \\
        --algorithm xcms_cwip
        
    """
}

process feature_mapper {
    container 'stavisvols/feature_mapper:latest'
    publishDir params.results_dir, mode: 'copy', pattern: '*.intensities'

    input:
    tuple val(row), path(mzml), path(pin), path(psms), path(peptides), path(features)

    output:
    tuple val(row), path(mzml), path(pin), path(psms), path(peptides), path(features), path("${basename_peptides}.intensities"), emit: intensities

    script:
    basename_peptides = peptides.getName()
    """
    python /mapper/options_parser.py \\
        --params $launchDir/$row.params
    python /mapper/feature_mapper.py \\
        --features $features \\
        --peptide $peptides \\
        --psms $psms \\
        --mzml $mzml \\
        --params feature_mapper_params \\
        --output ${basename_peptides}.intensities
    """
}

workflow {    
    //identification
    msconvert(design)
    comet(msconvert.out.mzml)
    percolator(comet.out.pin)
    
    //quantification
    xcms(percolator.out.pout)
    feature_mapper(xcms.out.features)
}

