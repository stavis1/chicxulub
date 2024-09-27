#!/bin/bash

mzml=$1
xcms=$2
xcms_params=$3
merge_params=$4

singularity run --bind ./:/data/ $xcms Rscript /xcms/xcms_quantify_features.R \
      --mzml $mzml \
      --output $mzml.features \
      --xcms_params $xcms_params \
      --peakmerge_params $merge_params \
      --algorithm xcms_cw
