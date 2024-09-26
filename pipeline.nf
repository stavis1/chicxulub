params.design = "$launchDir/design.tsv"
design = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)

process setup_exes {
    output:
    val env_name, emit: env
    val "$projectDir/exes/comet.linux.exe", emit: comet
    val "$projectDir/exes/msconvert.sif", emit: msconvert
    val "$projectDir/exes/percolator.sif", emit: percolator

    script:
    env_name = 'search_env'
    """
    bash $projectDir/setup.sh $projectDir
    """
}

process msconvert {
    input:
    val row
    val msconvert

    output:
    path "${row.spectra}.mzML", emit: mzml

    script:
    """
    $projectDir/msconvert.sh $launchDir $msconvert $row.spectra
    """
}

process comet {
    input:
    val row
    val mzml
    val comet

    output:
    path "${pin}.pin", emit: pin

    script:
    pin = mzml.getName()
    """
    $comet -P$launchDir/$row.params -D$launchDir/$row.sequences -N$pin $mzml
    grep -vE '[[:space:]]-?nan[[:space:]]' ${pin}.pin > tmp
    mv tmp ${pin}.pin
    """
}

process percolator {
    input:
    path pin
    val percolator

    output:
    path "${basename}.psms", emit: psms
    path "${basename}.peptides", emit: peptides

    script:
    basename = pin.getName()
    """
    singularity run --bind ./:/data/ $percolator percolator -K ';' -m /data/${basename}.psms -r /data/${basename}.peptides /data/$basename
    """
}

process results {
    input:
    path psms
    path peptides

    script:
    basename_psms = psms.getName()
    basename_peptides = peptides.getName()
    """
    cp $psms $launchDir/$basename_psms
    cp $peptides $launchDir/$basename_peptides
    """
}

workflow {    
    setup_exes()
    msconvert(design, setup_exes.out.msconvert)
    comet(design, msconvert.out.mzml, setup_exes.out.comet)
    percolator(comet.out.pin, setup_exes.out.percolator)
}

