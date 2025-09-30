// Enable DSL 2 syntax
nextflow.enable.dsl = 2

log.info """\
S O U P E R - S T A R
==========================================
samplesheet      : $params.samplesheet
samplesheet_sep  : $params.samplesheet_sep
umi_len          : $params.umi_len
min_reads        : $params.min_reads
genome_fasta     : $params.genome_fasta
k                : $params.k
flags            : $params.flags
results          : $params.results

CONTAINERS
=========================================
samtools         : $params.container__samtools
souporcell       : $params.container__souporcell
misc             : $params.container__misc
archr            : $params.container__archr

"""

// Import processes
include { 
    sam_to_bam;
    add_tags;
    filter_reads;
    merge_sample;
    dedup;
    index;
    make_bed;
    merge_all;
    get_barcodes;
    join_barcodes;
    souporcell;
    summarize;
    archr;
} from './processes.nf'

workflow {

    if ( "${params.results}" == "false" ){error "Must provide parameter: results"}
    if ( "${params.samplesheet}" == "false" ){error "Must provide parameter: samplesheet"}
    if ( "${params.genome_fasta}" == "false" ){error "Must provide parameter: genome_fasta"}

    // Get the input BAM/SAM files from the samplesheet
    Channel
        .fromPath(
            "${params.samplesheet}",
            checkIfExists: true
        )
        .splitCsv(
            header: true,
            sep: params.samplesheet_sep,
            strip: true
        )
        .map {
            it -> [
                "${it[params.sample_col]}",
                file(
                    "${it[params.path_col]}",
                    checkIfExists: true
                )
            ]
        }
        .toSortedList()
        .map { it -> [it, (1..it.size).toList()] }
        .transpose()
        .map { it -> [it[0][0], it[0][1], it[1]]}
        .branch {
            bam: it[1].name.endsWith(".bam")
            sam: true
        }
        .set { input }

    // SAM -> BAM
    sam_to_bam(input.sam)

    // Define channel of BAM inputs
    sam_to_bam
        .out
        .mix(input.bam)
        .set { bam_ch }

    // Remove duplicates
    dedup(bam_ch)

    // Add unique tags for each input file
    add_tags(dedup.out[0])

    // If the user specified a minimum number of reads per barcode
    if ( "${params.min_reads}" != "0" ){
        filter_reads(add_tags.out)
        
        filter_reads.out.set { to_be_merged }

    } else {
        add_tags.out.set { to_be_merged }
    }

    // Get the barcodes used for each BAM
    get_barcodes(to_be_merged)
    
    // Merge together all of those barcode lists
    join_barcodes(get_barcodes.out.toSortedList())

    // Merge
    merge_sample(
        to_be_merged
            .groupTuple(
                sort: true
            )
    )

    // Index the BAM
    index(merge_sample.out)

    // Make a channel containing:
    //    tuple val(sample), path(bam), path(bai)
    merge_sample.out.join(index.out).set { indexed_bam }

    // Make a BED file from the BAM with its index
    make_bed(indexed_bam)

    // Merge the sample-level BAMs together
    merge_all(
        indexed_bam
            .map { it -> [it[1], it[2]] }
            .flatten()
            .toSortedList()
    )

    // Make sure that the genome FASTA exists
    genome = file(
        "${params.genome_fasta}",
        checkIfExists: true
    )

    // Make sure that the genome index exists
    genome_index = file(
        "${params.genome_fasta}.fai",
        checkIfExists: true
    )

    // Run souporcell
    souporcell(
        merge_all.out,
        join_barcodes.out,
        genome,
        genome_index
    )

     // Run archR
    archr(
        make_bed
            .out
            .map { it -> it[1] }
            .toSortedList(),
        souporcell.out
    )

   // Post-process the souporcell outputs
    summarize(
        souporcell.out,
        join_barcodes.out,
        bam_ch
            .map { it -> "${it[0]},${it[2]}" }
            .collectFile(
                name: "sample_manifest.csv",
                newLine: true
            )
    )

}