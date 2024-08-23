params.design = "$launchDir/design.tsv"
design = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)

process setup_exes {
    output:
    val true

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
    val wait_for_setup

    output:
    path '*.mzML', emit: mzml

    script:
    """
    $launchDir/wrap_docker.sh $launchDir $row.spectra
    """

    stub:
    """
    touch ${row.spectra}.mzML
    """
}

process comet {
    input:
    val row
    val mzml

    output:
    path '*.pin', emit: pin

    script:
    """
    $launchDir/comet.linux.exe -P$launchDir/$row.params -D$launchDir/$row.sequences $mzml
    """

    stub:
    """
    touch test.pin
    """
}

workflow {
    setup_exes()
    msconvert(design, setup_exes)
    pin = comet(design, msconvert.out.mzml)
}

