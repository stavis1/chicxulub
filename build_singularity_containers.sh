#!/bin/bash
containers=("params_parser" "comet_for_pipeline" "percolator_for_pipeline" "dinosaur_for_pipeline"
 "feature_mapper" "eggnog_for_pipeline" "quantify_annotations" "msconvert")

for container in $containers
do
    singularity build cache/stavisvols-$container-latest.img docker://stavisvols/$container:latest
done
