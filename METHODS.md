# Methods: Souporcell Doublet Calling

This workflow identifies doublets from aligned single-cell CUT&Tag / ATAC-like BAM files using Souporcell.

The pipeline performs these steps:

- indexes the reference FASTA with `samtools faidx`
- adds `CB` and `CR` tags to each BAM using a compiled C++ SAM stream filter while removing any `RG` tag
- removes PCR duplicates per BAM with `samtools fixmate` and barcode-aware `samtools markdup --barcode-tag CB`
- merges deduplicated BAMs into `merged.sorted.bam`
- runs `souporcell_pipeline.py` with `--no_umi`, `--skip_remap`, and `--ignore` enabled by default

The workflow intentionally does not run ArchR. The barcode list is a required input and should contain one bare cell barcode per line.

Default barcode extraction uses a regex against each read name:

```text
([ACGTN]+(?:-[0-9]+)?)$
```

If read names encode barcodes differently, use `--extract_mode colon`, `--extract_mode underscore`, `--extract_mode auto`, `--extract_mode tail`, or override `--qname_regex`. For read names like `2501692422:2:11703:1814:1543:TAGGCATG_ATCCAGGA_G11`, use `--extract_mode auto` or `--extract_mode colon --colon_field 6`; `--colon_field 5` would extract `1543`, not the barcode suffix. For read names like `533657448:1:10102:0430:0056_AGACCAGC_AGAGATCT_G12-15`, `--extract_mode tail --tail_length 26` captures `AGACCAGC_AGAGATCT_G12-15`.

For sparse CUT&Tag / ATAC-like data, the default Souporcell thresholds `--min_alt 10 --min_ref 10` may be too strict. The workflow exposes these as `--min_alt` and `--min_ref`.

If Souporcell clustering completes but `troublet` fails during doublet detection, `--allow_troublet_failure true` can be used to keep `clusters_tmp.tsv` as a clustering-only `clusters.tsv`. This fallback does not provide reliable doublet status calls.

If `clusters.tsv` exists but Souporcell exits nonzero in a later consensus or ambient-RNA stage, `--allow_souporcell_partial true` can be used to accept `clusters.tsv` as the final result while marking the output with `souporcell.partial.allowed`.

`RUN_SOUPORCELL` removes an existing `souporcell_output` directory by default so retries start from a clean state and Nextflow controls resume semantics. Set `--clean_souporcell_output false` only when you intentionally want Souporcell's internal partial-output restart behavior.
