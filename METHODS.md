# Methods: Souporcell Doublet Calling

This workflow identifies doublets from aligned single-cell CUT&Tag / ATAC-like BAM files using Souporcell.

The pipeline performs these steps:

- indexes the reference FASTA with `samtools faidx`
- adds `CB`, `CR`, and `RG` tags to each BAM using a compiled C++ SAM stream filter
- removes PCR duplicates per BAM with `samtools fixmate` and barcode-aware `samtools markdup --barcode-tag CB`
- merges deduplicated BAMs into `merged.sorted.bam`
- runs `souporcell_pipeline.py` with `--no_umi`, `--skip_remap`, and `--ignore` enabled by default

The workflow intentionally does not run ArchR. The barcode list is a required input and should contain one bare cell barcode per line.

Default barcode extraction uses a regex against each read name:

```text
([ACGTN]+(?:-[0-9]+)?)$
```

If read names encode barcodes differently, use `--extract_mode colon`, `--extract_mode underscore`, `--extract_mode auto`, or override `--qname_regex`.
