#!/bin/bash

set -e

CORES=${1}
MIN_READS=${2}
BAM_IN="${3}"
BAM_OUT="${4}"

mkdir -p tmp
export TMPDIR=tmp

# Index the BAM
samtools index "${BAM_IN}"

# Count up the number of times that each
# barcode is present, filter by the minimum
# number, and then write out the list of
# barcodes to keep
samtools view "${BAM_IN}" \
    | perl -nle '@reads=split(/\t/,$_); if (m/CB:Z:([^\t\n]+)\t/) { print $1; }' \
    | sort \
    | uniq -c \
    | awk "\$1 >= ${MIN_READS}" \
    | sed 's/^ *//' \
    | tr ' ' '\t' \
    | cut -f 2 \
    > filtered_barcodes.txt

# Filter the BAM to just include reads with those barcodes
subset-bam \
    --bam "${BAM_IN}" \
    --out-bam "${BAM_OUT}" \
    --cell-barcodes filtered_barcodes.txt \
    --cores ${CORES}