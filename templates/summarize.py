#!/usr/bin/env python3

import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import numpy as np
import pandas as pd
import seaborn as sns
from sklearn.decomposition import PCA

clusters = pd.read_csv("souporcell/clusters.tsv", sep="\\t")
print(f"Read in {clusters.shape[0]:,} cluster assignments")

barcode_counts = pd.read_csv("barcodes.tsv.gz", header=None, delim_whitespace=True, names=["reads", "barcode"])
print(f"Read in {barcode_counts.shape[0]:,} barcode readcounts")

# Make sure that all of the counts are unique
# assert barcode_counts.shape[0] == barcode_counts['barcode'].drop_duplicates().shape[0], "Duplicated barcodes found"
barcode_counts = barcode_counts.groupby('barcode').head(1)

sample_assignments = pd.read_csv("sample_manifest.csv", header=None, names=["sample", "index"])
print(f"Read in {sample_assignments.shape[0]:,} sample assignments")

# Assign the source sample from each cluster
# Also assign the number of reads per barcode
clusters = clusters.assign(
    sample_ix=lambda d: d["barcode"].apply(lambda s: int(s.rsplit("-", 1)[1])),
    sample=lambda d: d["sample_ix"].apply(sample_assignments.set_index("index")["sample"].get),
    n_reads=lambda d: d["barcode"].apply(barcode_counts.set_index("barcode")["reads"].get),
    log10_read_count=lambda d: d["n_reads"].apply(np.log10)
)

# Run PCA on the clusters and write out to a file
def run_pca_and_save(df, output_prefix):

    # Run PCA
    pca = PCA(n_components=2)
    pca_coords = pd.DataFrame(
        pca.fit_transform(
            df.reindex(columns=[
                cname for cname in df.columns.values if cname.startswith("cluster")
            ]).applymap(
                lambda x: np.log10(-x)
            ).values
        ),
        index=df.index,
        columns=["PC1", "PC2"]
    )

    output_df = pd.concat([df, pca_coords], axis=1)

    # Write out to PDF
    print(f"Writing out to {output_prefix}.pdf")
    with PdfPages(f"{output_prefix}.pdf") as pdf:

        for kwargs in [
            dict(),
            dict(hue="assignment"),
            dict(hue="log10_read_count"),
            dict(hue="sample")
        ]:
            sns.scatterplot(
                data=output_df,
                x="PC1",
                y="PC2",
                linewidth=0,
                alpha=0.2,
                **kwargs
            )
            if 'hue' in kwargs:
                plt.legend(bbox_to_anchor=[1, 1], loc="upper left", title=kwargs['hue'].replace("_", " ").title())
            pdf.savefig(bbox_inches="tight")
            plt.close()

    # Write out to CSV
    print(f"Writing out to {output_prefix}.csv.gz")
    output_df.to_csv(f"{output_prefix}.csv.gz", index=None)

run_pca_and_save(clusters, "souporcell.clusters.all")
