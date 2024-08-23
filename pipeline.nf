params.design = "$launchDir/design.tsv"
design = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)

process setup_exes {
    output:
    val env_name, emit: env
    path "$projectDir/exes/comet.linux.exe", emit: comet
    path "$projectDir/exes/msconvert.sif", emit: msconvert
    path "$projectDir/exes/percolator.sif", emit: percolator

    script:
        env_name = 'search_env'
        """
        bash $projectDir/setup.sh
        """
}

process msconvert {
    input:
    val row
    val msconvert

    output:
    path "$launchDir/${row.spectra}.mzML", emit: mzml

    script:
    """
    singularity run --fakeroot --containall -w --bind $launchDir:/data/ $msconvert wine msconvert --outdir /data/ --outfile ${row.spectra}.mzML /data/$row.spectra
    """
}

process comet {
    input:
    val row
    val mzml
    val comet

    output:
    path '*.pin', emit: pin

    script:
    """
    $comet -P$launchDir/$row.params -D$launchDir/$row.sequences $mzml
    """

    stub:
    """
    touch test.pin
    """
}


workflow {    
    setup_exes()
    msconvert(design, setup_exes.out.msconvert)
    pin = comet(design, msconvert.out.mzml, setup_exes.out.comet)
}

