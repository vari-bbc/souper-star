#!/usr/bin/env python3
import argparse
from sys import stdout
from random import choice
from simplesam import Reader, Writer
import numpy as np

def parse_qname(ss, well_barcode, index=1):
    substring=ss.qname.split(':')[4]
    substring='_'.join(substring.split('_')[1:3])

    cb=f"{substring}_{well_barcode}-{index}"
    return({'CB':cb, 'CR':cb})

def iterate(args):
    
    i5 = ""
    i7 = ""
    well_barcode = ""
    well_barcode_table = np.loadtxt(args.well_barcode, delimiter = ",", dtype=str)

    with Reader(args.bam) as bam:
        for read in bam:
            substring = read.qname.split(':')[4]
            i5 = substring.split('_')[4]
            i7 = substring.split('_')[3]
            break

    for row in well_barcode_table:
        
        if row[2] == i5 and row[1] == i7:
            well_barcode = row[3]
            break

    with Reader(args.bam) as bam, Writer(stdout, bam.header) as stdout_sam:

        bam.header.get('@HD')['VN:1.4']=['SO:coordinate']
        
        for read in bam:
            read.tags.update(parse_qname(read, well_barcode, index=args.index))
            stdout_sam.write(read)

def main():
    parser = argparse.ArgumentParser(prog='addTags', description="parse BAM sequence name for barcode and add as bam tags")
    parser.add_argument('bam', type=argparse.FileType('r'), help=" BAM file ")
    parser.add_argument('-i', '--index', required=True, help="index appended to barcode")
    parser.add_argument('-b', '--well_barcode', required = True, help = "transform the well barcode")
    parser.set_defaults(func=iterate)
    args = parser.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()
