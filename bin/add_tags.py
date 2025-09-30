#!/usr/bin/env python3
import argparse
from sys import stdout
from random import choice
from simplesam import Reader, Writer


def rand_DNA(length):
    DNA=""
    for _ in range(length):
        DNA+=choice("CGTA")
    return DNA


def parse_qname(ss, index=1):
    substring=ss.qname.split(':')[4]
    substring='_'.join(substring.split('_')[1:5])
    cb=f"{substring}-{index}"
    return({'CB':cb, 'CR':cb})

def iterate(args):

    with Reader(args.bam) as bam, Writer(stdout, bam.header) as stdout_sam:

        bam.header.get('@HD')['VN:1.4']=['SO:coordinate']
        
        for read in bam:
            read.tags.update(parse_qname(read, index=args.index))
            stdout_sam.write(read)

def main():
    parser = argparse.ArgumentParser(prog='addTags', description="parse BAM sequence name for barcode and add as bam tags")
    parser.add_argument('bam', type=argparse.FileType('r'), help=" BAM file ")
    parser.add_argument('-i', '--index', required=True, help="index appended to barcode")
    parser.set_defaults(func=iterate)
    args = parser.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()
