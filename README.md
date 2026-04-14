# Souporcell Doublet Calling Pipeline

This repository contains a Nextflow pipeline for Souporcell-based doublet calling from aligned single-cell coCUT&Tag BAM files.

The pipeline covers:

- FASTA indexing with `samtools faidx`
- `CB`/`CR` cell barcode tag insertion using a C++ stream filter (maybe CR is not needed, TODO: update in the future)
- barcode-aware PCR duplicate removal with `samtools markdup --barcode-tag CB`
- BAM merging, sorting, and indexing
- Souporcell doublet calling

To run the pipeline, it needs to provide a plain-text barcode file with one bare barcode per line, for example:

## Files

- `main.nf`: Nextflow DSL2 workflow.
- `nextflow.config`: local, Conda, Singularity, and SLURM profile settings.
- `bin/add_cb_rg_tags`: wrapper that prefers the compiled tagger and builds it if needed.
- `src/add_cb_rg_tags.cpp`: fast C++ SAM stream filter that adds `CB:Z` and `CR:Z` tags while removing any existing `RG` tag.
- `tools/build_add_cb_rg_tags.sh`: explicit build helper for the C++ tagger.
- `envs/souporcell.yml`: Conda environment definition.
- `containers/souporcell.def`: Singularity/Apptainer definition file.
- `METHODS.md`: extended workflow notes.

## Minimal Run

```bash
nextflow run main.nf \
  --input_dir /path/to/bam_files \
  --barcode_list ./tmp/cell_barcode.tsv \
  --ref_fasta ../../data/ref_genome/hg38_gencode.fa \
  --k_genotypes 4 \
  --out_dir souporcell_work \
  -profile conda
```

For SLURM with Conda:

```bash
nextflow run main.nf \
  --input_dir /path/to/bam_files \
  --barcode_list ./tmp/cell_barcode.tsv \
  --ref_fasta ../../data/ref_genome/hg38_gencode.fa \
  --k_genotypes 4 \
  --out_dir souporcell_work \
  -profile conda,slurm
```

If you are not using the Nextflow Conda profile and already have a named Conda environment, run Souporcell exactly like the original shell workflow:

```bash
--souporcell_cmd 'conda run -n souporcell souporcell_pipeline.py'
```

Use a non-default BAM filename pattern with:

```bash
--bam_glob "*.bam"
```

## Barcode Extraction

The C++ tagger reads SAM from `stdin`, writes SAM to `stdout`, removes any existing `RG` tag, and extracts a barcode from each read name.

Default mode:

```bash
--extract_mode regex --qname_regex '([ACGTN]+(?:-[0-9]+)?)$'
```

Useful alternatives:

```bash
# Use the last colon-delimited field if present, otherwise substring before underscore.
# For read names like:
# 2501692422:2:11703:1814:1543:TAGGCATG_ATCCAGGA_G11
# this extracts TAGGCATG_ATCCAGGA_G11.
--extract_mode auto

# Use a specific colon-delimited field. The field number is 1-based.
# For the read-name example above, the barcode is field 6.
--extract_mode colon --colon_field 6

# Use the last N characters of the read name.
# Example:
# 533657448:1:10102:0430:0056_AGACCAGC_AGAGATCT_G12-15
# barcode = AGACCAGC_AGAGATCT_G12-15
--extract_mode tail --tail_length 26

# Use the substring before the first underscore.
--extract_mode underscore
```

If you use `--colon_field 5` for the example above, the generated tag will be `CB:Z:1543`, which is the fifth read-name field, not the barcode suffix. The barcode list supplied to Souporcell must match the generated `CB` tags.

If you change `--extract_mode` or `--colon_field`, do not reuse an old cached `ADD_CB_RG_TAGS` result. Either run without `-resume`, use a fresh `work/` directory, or delete the old downstream output before rechecking tags.

Quick check:

```bash
samtools view results/merged_bam/merged.sorted.bam | awk '{for (i=12;i<=NF;i++) if ($i ~ /^CB:Z:/) {sub(/^CB:Z:/,"",$i); print $i; break}}' | head
head ./data/cell_barcode.tsv
```

If the barcode should be suffixed, for example `AAAC...-1`, add:

```bash
--index_suffix 1
```

If BAMs already have correct `CB` tags, skip tag insertion:

```bash
--skip_add_tags true
```

## Sparse CUT&Tag / ATAC Runs

For sparse test data or low-depth CUT&Tag / ATAC-like data, Souporcell's default locus thresholds can be too strict. Try lower thresholds:

```bash
--min_alt 2 --min_ref 2
```

If Souporcell finishes clustering but `troublet` fails during doublet detection, rerun with:

```bash
--allow_troublet_failure true
```

This keeps `souporcell_output/clusters_tmp.tsv` as `souporcell_output/clusters.tsv` and writes `souporcell_output/troublet.failed.allowed`. Use this only as a clustering-only fallback; it does not produce validated doublet calls.

If Souporcell writes `souporcell_output/clusters.tsv` but exits nonzero during a later consensus or ambient-RNA step, accept that partial output with:

```bash
--allow_souporcell_partial true
```

This writes `souporcell_output/souporcell.partial.allowed`. Use this only when `clusters.tsv` is the output you need and you accept that later files such as `ambient_rna.txt` or `cluster_genotypes.vcf` may be incomplete or missing.

By default, each `RUN_SOUPORCELL` task removes any pre-existing `souporcell_output` directory inside the Nextflow work directory before starting. This avoids Souporcell's own partial-output restart mode producing different behavior from Nextflow `-resume`. To preserve Souporcell's internal restart behavior instead:

```bash
--clean_souporcell_output false
```

## Outputs

Outputs are published under `--out_dir`:

- `bin/add_cb_rg_tags`: compiled C++ tagger.
- `ref/`: FASTA index generated by `samtools faidx`.
- `tagged_bams/*.rg.bam`: BAMs with `CB` and `CR` tags and without `RG` tags.
- `dedup_bams/*.dedup.bam`: barcode-aware duplicate-removed BAMs.
- `dedup_bams/*.dup.out`: `samtools markdup` duplicate metrics.
- `merged_bam/merged.sorted.bam`: merged, sorted BAM.
- `merged_bam/merged.sorted.bam.bai`: BAM index.
- `souporcell_output/`: Souporcell results, including `clusters.tsv`.

## Dependencies

Use `-profile conda` or provide these tools on `PATH`:

- Nextflow
- `g++` with C++17 support
- `samtools`
- `souporcell_pipeline.py`

Build the C++ tagger manually if desired:

```bash
./tools/build_add_cb_rg_tags.sh
```

## Notes

The barcode list must match the `CB` tags generated from the BAM read names.

Default barcode extraction uses a regex against each read name (TODO: make default using tail length instead)
```text
([ACGTN]+(?:-[0-9]+)?)$
```

If read names encode barcodes differently, use `--extract_mode colon`, `--extract_mode underscore`, `--extract_mode auto`, `--extract_mode tail`, or override `--qname_regex`. For read names like `2501692422:2:11703:1814:1543:TAGGCATG_ATCCAGGA_G11`, use `--extract_mode auto` or `--extract_mode colon --colon_field 6`; `--colon_field 5` would extract `1543`, not the barcode suffix. For read names like `533657448:1:10102:0430:0056_AGACCAGC_AGAGATCT_G12-15`, `--extract_mode tail --tail_length 26` captures `AGACCAGC_AGAGATCT_G12-15`.

For sparse CUT&Tag data, the default Souporcell thresholds `--min_alt 10 --min_ref 10` may be too strict. The workflow exposes these as `--min_alt` and `--min_ref`.

If Souporcell clustering completes but `troublet` fails during doublet detection, `--allow_troublet_failure true` can be used to keep `clusters_tmp.tsv` as a clustering-only `clusters.tsv`. This fallback does not provide reliable doublet status calls.

If `clusters.tsv` exists but Souporcell exits nonzero in a later consensus or ambient-RNA stage, `--allow_souporcell_partial true` can be used to accept `clusters.tsv` as the final result while marking the output with `souporcell.partial.allowed`.

`RUN_SOUPORCELL` removes an existing `souporcell_output` directory by default so retries start from a clean state and Nextflow controls resume semantics. Set `--clean_souporcell_output false` only when you intentionally want Souporcell's internal partial-output restart behavior.
