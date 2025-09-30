#! /usr/bin/Rscript
#load packages
Sys.unsetenv("DISPLAY")
library(ArchR)
library(parallel)
set.seed(1)


#source beds
beds=list.files('beds/', pattern = '\\.bed.gz$')
bedpaths=paste0('../beds/', beds)

#name beds
samples=strsplit(beds, ".bed.gz")
samples=unlist(samples)
samples

#prepare inputs
inputFiles <- structure(
    bedpaths,
    .Names = samples)

#set outdir
dir.create('ArchR', recursive=TRUE, showWarnings=FALSE)
setwd('ArchR')

#set threads & genome (should make input param)
addArchRThreads(threads = detectCores())
addArchRGenome('hg38')

# Create Arrow files
ArrowFiles <- createArrowFiles(
    inputFiles = inputFiles,
    sampleNames = names(inputFiles),
    minFrags = 0,
    maxFrags = Inf,
    addTileMat = FALSE,
    addGeneScoreMat = FALSE,
    excludeChr = c('chrM'),
    force = TRUE
    #TileMatParams = tilematparams,
    # minTSS = 0,
)

# Create project --> output metadata
proj <- ArchRProject(
  ArrowFiles = ArrowFiles,
  outputDirectory = "souper-star_out",
  copyArrows = FALSE
)
write.csv(getCellColData(proj), 'ArchR_metadata.csv', quote=FALSE)