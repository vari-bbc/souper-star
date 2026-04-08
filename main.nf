nextflow.enable.dsl = 2

params.input_dir = params.input_dir ?: null
params.bam_glob = params.bam_glob ?: '*.bam'
params.out_dir = params.out_dir ?: 'souporcell_work'
params.barcode_list = params.barcode_list ?: null
params.ref_fasta = params.ref_fasta ?: null
params.k_genotypes = params.k_genotypes ?: 4
params.extract_mode = params.extract_mode ?: 'regex'
params.qname_regex = params.qname_regex ?: '([ACGTN]+(?:-[0-9]+)?)$'
params.colon_field = params.colon_field ?: 5
params.index_suffix = params.index_suffix ?: ''
params.skip_add_tags = params.skip_add_tags ?: false
params.no_umi = params.no_umi == null ? true : params.no_umi
params.skip_remap = params.skip_remap == null ? true : params.skip_remap
params.ignore = params.ignore == null ? true : params.ignore
params.min_alt = params.min_alt ?: 10
params.min_ref = params.min_ref ?: 10
params.max_loci = params.max_loci ?: 2048
params.restarts = params.restarts ?: 100
params.allow_troublet_failure = params.allow_troublet_failure ?: false
params.allow_souporcell_partial = params.allow_souporcell_partial ?: false
params.clean_souporcell_output = params.clean_souporcell_output == null ? true : params.clean_souporcell_output
params.souporcell_cmd = params.souporcell_cmd ?: 'souporcell_pipeline.py'
params.souporcell_extra_args = params.souporcell_extra_args ?: ''
params.publish_mode = params.publish_mode ?: 'copy'

if (!params.input_dir) {
    error "Missing required parameter: --input_dir"
}

if (!params.barcode_list) {
    error "Missing required parameter: --barcode_list"
}

if (!params.ref_fasta) {
    error "Missing required parameter: --ref_fasta"
}

process PREPARE_FASTA {
    tag "${ref_fasta}"
    cpus 4
    memory '16 GB'
    publishDir "${params.out_dir}/ref", mode: params.publish_mode

    input:
    path ref_fasta

    output:
    tuple path(ref_fasta), path("${ref_fasta}.fai"), emit: indexed_fasta

    script:
    """
    samtools faidx "${ref_fasta}"
    """
}

process ADD_CB_RG_TAGS {
    tag "${sample}"
    cpus 8
    memory '32 GB'
    publishDir "${params.out_dir}/tagged_bams", mode: params.publish_mode

    input:
    tuple val(sample), path(bam)

    output:
    tuple val(sample), path("${sample}.rg.bam")

    script:
    def index_arg = params.index_suffix ? "--index \"${params.index_suffix}\"" : ''
    """
    samtools view -h -@ ${task.cpus} "${bam}" \\
      | add_cb_rg_tags \\
          --sample "${sample}" \\
          --mode "${params.extract_mode}" \\
          --regex '${params.qname_regex}' \\
          --colon-field ${params.colon_field} \\
          ${index_arg} \\
      | samtools view -b -@ ${task.cpus} -o "${sample}.rg.bam" -
    """
}

process DEDUP_BAM {
    tag "${sample}"
    cpus 16
    memory '96 GB'
    publishDir "${params.out_dir}/dedup_bams", mode: params.publish_mode

    input:
    tuple val(sample), path(rg_bam)

    output:
    tuple val(sample), path("${sample}.dedup.bam"), path("${sample}.dup.out"), emit: dedup_bam

    script:
    """
    samtools sort -n -m 4G -@ ${task.cpus} "${rg_bam}" \\
      | samtools fixmate -m -@ ${task.cpus} - - \\
      | samtools sort -m 2G -@ ${task.cpus} - \\
      | samtools markdup -r -s \\
          -f "${sample}.dup.out" \\
          --barcode-tag CB \\
          -@ ${task.cpus} \\
          - "${sample}.dedup.bam"
    """
}

process MERGE_BAMS {
    cpus 16
    memory '96 GB'
    publishDir "${params.out_dir}/merged_bam", mode: params.publish_mode

    input:
    path dedup_bams

    output:
    tuple path('merged.sorted.bam'), path('merged.sorted.bam.bai'), emit: merged_bam

    script:
    """
    samtools merge -@ ${task.cpus} -f merged.bam *.dedup.bam
    samtools sort -m 4G -@ ${task.cpus} -o merged.sorted.bam merged.bam
    samtools index -@ ${task.cpus} merged.sorted.bam
    """
}

process RUN_SOUPORCELL {
    cpus 16
    memory '128 GB'
    time '24h'
    publishDir "${params.out_dir}", mode: params.publish_mode
    errorStrategy 'ignore'


    input:
    tuple path(merged_bam), path(merged_bai)
    path barcode_list
    tuple path(ref_fasta), path(ref_fai)

    output:
    path 'souporcell_output', emit: souporcell_output

    script:
    def no_umi_arg = params.no_umi.toString().toBoolean() ? 'True' : 'False'
    def skip_remap_arg = params.skip_remap.toString().toBoolean() ? '--skip_remap True' : ''
    def ignore_arg = params.ignore.toString().toBoolean() ? '--ignore True' : ''
    def allow_troublet_failure = params.allow_troublet_failure.toString().toBoolean() ? 'true' : 'false'
    def allow_souporcell_partial = params.allow_souporcell_partial.toString().toBoolean() ? 'true' : 'false'
    def clean_souporcell_output = params.clean_souporcell_output.toString().toBoolean() ? 'true' : 'false'
    """
    if [[ "${clean_souporcell_output}" == "true" ]]; then
      rm -rf souporcell_output
    fi
    mkdir -p souporcell_output
    set +e
    ${params.souporcell_cmd} \\
      -i "${merged_bam}" \\
      -b "${barcode_list}" \\
      -f "${ref_fasta}" \\
      -t ${task.cpus} \\
      -k ${params.k_genotypes} \\
      --no_umi ${no_umi_arg} \\
      ${skip_remap_arg} \\
      ${ignore_arg} \\
      --min_alt ${params.min_alt} \\
      --min_ref ${params.min_ref} \\
      --max_loci ${params.max_loci} \\
      --restarts ${params.restarts} \\
      -o souporcell_output ${params.souporcell_extra_args}
    exit 0
    """
}

workflow {
    Channel
        .fromPath("${params.input_dir}/${params.bam_glob}", checkIfExists: true)
        .map { bam -> tuple(bam.baseName, bam) }
        .set { bam_ch }

    barcode_ch = Channel.fromPath(params.barcode_list, checkIfExists: true)
    ref_ch = Channel.fromPath(params.ref_fasta, checkIfExists: true)

    PREPARE_FASTA(ref_ch)

    tagged_bams = params.skip_add_tags ? bam_ch : (bam_ch | ADD_CB_RG_TAGS)
    deduped_bams = tagged_bams | DEDUP_BAM
    deduped_bams
        .map { sample, dedup_bam, dup_metrics -> dedup_bam }
        .collect()
        .set { dedup_bams_ch }

    MERGE_BAMS(dedup_bams_ch)
    RUN_SOUPORCELL(MERGE_BAMS.out.merged_bam, barcode_ch, PREPARE_FASTA.out.indexed_fasta)

    RUN_SOUPORCELL.out.souporcell_output.view { out -> "Completed Souporcell: ${out}" }
}
