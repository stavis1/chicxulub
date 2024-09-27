params.design = "$launchDir/design.tsv"
params.cys_alk = 'const'
params.results_dir = launchDir
design = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)

process setup_exes {
    output:
    val env_name, emit: env
    val "$projectDir/exes/comet.linux.exe", emit: comet
    val "$projectDir/exes/msconvert.sif", emit: msconvert
    val "$projectDir/exes/percolator.sif", emit: percolator
    val "$projectDir/exes/xcms.sif", emit: xcms
    val "$projectDir/exes/feature_mapper.sif", emit: feature_mapper

    script:
    env_name = 'search_env'
    """
    bash $projectDir/setup.sh $projectDir
    """
}

process msconvert {
    publishDir params.results_dir, mode: 'symlink', pattern '*.mzML'

    input:
    val row
    val msconvert

    output:
    tuple val(row), path("${row.spectra}.mzML"), emit: mzml

    script:
    """
    $projectDir/msconvert.sh $launchDir $msconvert $row.spectra
    """
}

process comet {
    input:
    tuple val(row), path(mzml)
    val comet

    output:
    tuple val(row), path(mzml), path("${pin}.pin"), emit: pin

    script:
    pin = mzml.getName()
    """
    $comet -P$launchDir/$row.params -D$launchDir/$row.sequences -N$pin $mzml
    grep -vE '[[:space:]]-?nan[[:space:]]' ${pin}.pin > tmp
    mv tmp ${pin}.pin
    """
}

process percolator {
    publishDir params.results_dir, mode: 'copy', pattern '*.p*'

    input:
    tuple val(row), path(mzml), path(pin)
    val percolator

    output:
    tuple val(row), path(mzml), path(pin), path("${basename}.psms"), path("${basename}.peptides"), emit: pout
    
    script:
    basename = pin.getName()
    """
    singularity run --bind ./:/data/ $percolator percolator \\
        -K ';' \\
        -m /data/${basename}.psms \\
        -r /data/${basename}.peptides \\
        /data/$basename
    """
}

process xcms {
    input:
    tuple val(row), path(mzml), path(pin), path(psms), path(peptides)
    val xcms

    output:
    tuple val(row), path(mzml), path(pin), path(psms), path(peptides), path("${row.spectra}.features"), emit: features

    script:
    """
    singularity run --bind ./:/data/ $xcms Rscript /xcms/xcms_quantify_features.R \\
        --mzml $mzml \\
        --output ${mzml}.features \\
        --xcms_params $launchDir/$row.xcms_params \\
        --peakmerge_params $launchDir/$row.merge_params \\
        --algorithm xcms_cw
        
    """
}

process feature_mapper {
    publishDir params.results_dir, mode: 'copy', pattern '*.intensities'

    input:
    tuple val(row), path(mzml), path(pin), path(psms), path(peptides), path(features)
    val feature_mapper

    output:
    tuple val(row), path(mzml), path(pin), path(psms), path(peptides), path(features), path("${basename_peptides}.intensities"), emit: intensities

    script:
    basename_peptides = peptides.getName()
    """
    singularity run --bin ./:/data/ $feature_mapper python /mapper/feature_mapper.py \\
        --features $features \\
        --peptide $peptides \\
        --psms $psms \\
        --mzml $mzml \\
        --varaible_c_alk $params.cys_alk \\
        --output ${basename_peptides}.intensities
    """
}

workflow {    
    //download necessary tools and containers
    setup_exes()
    
    //identification
    msconvert(design, setup_exes.out.msconvert)
    comet(msconvert.out.mzml, setup_exes.out.comet)
    percolator(comet.out.pin, setup_exes.out.percolator)
    
    //quantification
    xcms(percolator.out.pout, setup_exes.out.xcms)
    feature_mapper(xcms.out.features, setup_exes.out.feature_mapper)
}

