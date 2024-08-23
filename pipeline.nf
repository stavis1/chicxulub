params.design = "$launchDir/design.tsv"
design = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)

process setup_exes {
    output:
    val 'search_env' emit: env
    path "$projectDir/exes/comet.linux.exe" emit: comet
    path "$projectDir/exes/msconvert.sif" emit: msconvert
    path "$projectDir/exes/percolator.sif" emit: percolator

    """
    if [ ! -d ~/.conda/envs/search_env ]; then
        conda env create -n search_env -f $projectDir/env/search_env.yml
    fi

    cd $projectDir/exes/
    if [ ! -f comet.linux.exe ]; then
            wget https://github.com/UWPR/Comet/releases/download/v2024.01.1/comet.linux.exe
        chmod +x comet.linux.exe
    fi

    if [ ! -f msconvert.sif ]; then
        singularity build --fakeroot msconvert.sif docker://proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:latest
    fi

    if [ ! -f percolator.sif ]; then
        wget https://github.com/percolator/percolator/releases/download/rel-3-06-05/percolator-noxml-v3-06-linux-amd64.deb
            singularity build --fakeroot percolator.sif percolator.def
    fi
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
    msconvert(design, setup_exes.msconvert)
    pin = comet(design, msconvert.out.mzml, setup_exes.comet)
}

