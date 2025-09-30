# souper-star
Nextflow workflow running souporcell on barcoded cell subsets

## Workflow

The analysis workflow performs the following steps:

  1. Convert SAM to BAM (if necessary)
  2. Remove duplicate reads
  3. Add unique tags for each input file
  4. Filter cells by a minimum read threshold (if specified)
  5. Extract the barcodes observed in each filtered set of alignments
  6. Merge alignments by sample
  7. Create BED files for each sample
  8. Run souporcell to classify each cell by genotype
  9. Summarize outputs with ArchR

## Input Data

To run souper-star, the user must provide a set of aligned reads in BAM (or SAM) format
as well as the nucleotide sequence of the reference genome in FASTA format.
While alignments in SAM format are supported, the following documentation will
refer to BAM when indicating a file which could be provided as either BAM or SAM.
Multiple BAM files from the same sample can be provided using a sample sheet
CSV to indicate which BAM files correspond to which sample.

### Sample Sheet

The sample sheet listing the location of all input files must have a column
listing the path to each BAM file as well as a column indicating the sample
for that BAM.

Example:

```bash
sample,path
SampleA,/path/to/batch1/SampleA.bam
SampleA,/path/to/batch2/SampleA.bam
SampleB,/path/to/batch1/SampleB.bam
SampleB,/path/to/batch2/SampleB.bam
```

## Running the Workflow

### Nextflow

The workflow can be run using the Nextflow workflow management system, which can be
set up following [their user documentation](https://nextflow.io/).

### Containers

The software used in each step of the workflow has been provided via Docker containers
which are specified in the workflow.
Those software containers can be used either via Docker ([installation instructions](https://docs.docker.com/get-docker/))
or Singularity ([installation instructions](https://docs.sylabs.io/guides/latest/user-guide/)).
Singularity is typically used on HPC systems which do not allow users the root
access needed for running Docker.

After either Docker or Singularity, Nextflow must be configured to use either
system as appropriate.
The most convenient way to set up this configuration is to create a file called
`nextflow.config` which follows [the configuration instructions for Nextflow](https://www.nextflow.io/docs/latest/config.html).
It is also possible to set up other types of job execution systems (e.g. AWS,
Google Cloud, Azure, SLURM, PBS) which can be managed directly by Nextflow.
This configuration file can be used across multiple runs of the workflow on
the same computational system.

### Parameters

For each individual run, a file with the parameters for each run should be
created [in JSON format](https://www.w3schools.com/js/js_json_intro.asp),
typically called `params.json`.
The required parameters for the workflow are:

 - `samplesheet`: Path to the sample sheet CSV [described above](#sample-sheet)
 - `genome_fasta`: Path to the genome FASTA used for alignment
 - `k`: Number of genotypes used
 - `min_reads`: Minimum threshold of reads per barcode (cell)

 ### Launching the Workflow

 Once all of the previous steps have been completed, the workflow can be
 launched with a command like:

 ```bash
 nextflow run FredHutch/souper-star -params-file params.json -c nextflow.config
 ```

 ## Quickstart (with the BASH Workbench)

 To more easily set up and launch the workflow, users may take advantage of
 a command-line utility called the [BASH Workbench](https://github.com/FredHutch/bash-workbench/wiki).
 This utility can be installed directly with the command `pip3 install bash-workbench`.
 After installation, the BASH Workbench can be launched interactively with the command
 `wb`.
 
 > Users of the Fred Hutch computing cluster can launch the workbench directly
 > via `wb` without the need for any installation.

 ### Setup

 To set up this workflow in the BASH Workbench, select:
 
 - Select `Manage Repositories`;
 - Select `Download New Repository`;
 - then enter `FredHutch/souper-star` and confirm

 After setting up the workflow, the workbench can be exited with Control+C.

 ### Launching the Workflow

 After setting up the workflow, it can be run by:

 - Navigating to the folder intended for the output files;
 - Launching the BASH Workbench (`wb`);
 - Select `Run Tool`;
 - Select `FredHutch_souper-star`;
 - Select `souper-star`;
 - Enter [the appropriate parameters](#parameters);
 - Select `Review and Run`;
 - Select `FredHutch_souper-star`;
 - Select `slurm` (if using an HPC SLURM cluster) or `docker` (for local execution);
 - Enter any needed parameters for the SLURM or Docker configuration. For example, SLURM users will need to enter the `scratch_dir` parameter using a folder on the scratch filesystem which can be used for temporary files;
 - Select `Review and Run`;
 - Select `Run Now`

 Once the workflow has been launched, a record will be saved of the parameters
 used for execution, as well as all of the logs which were produced during
 execution.

 ## Output Files

 The output files produced by the workflow include:

 ```bash
 beds/                           # Alignments in BED format for each sample
 dedup/                          # Deduplication log files for each sample
 sample_manifest.csv             # Table indicating the index used for each sample
 souporcell/                     # Results from souporcell
 souporcell.clusters.all.csv.gz  # Table listing soupercell assignments for each cell
 souporcell.clusters.all.pdf     # Summary figures with QC metrics
 ```

## Authors

Analysis code was written by Jacob Greene (jgreene3 at fredhutch dot org).
Workflow code was written by Samuel Minot (sminot at fredhutch dot org).
