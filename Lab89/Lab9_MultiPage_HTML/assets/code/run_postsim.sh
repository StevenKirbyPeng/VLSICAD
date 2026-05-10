#!/bin/bash
# Lab9 HSPICE run example
# Usage: bash run_postsim.sh test_nand_post.sp nand_post.lis
IN=${1:-test_nand_post.sp}
OUT=${2:-nand_post.lis}
hspice -i "$IN" -o "$OUT"
wv &
