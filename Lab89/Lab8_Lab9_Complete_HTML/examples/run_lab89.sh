#!/bin/bash
# Lab8 / Lab9 simulation helper
set -e

# Lab8 pre-sim
hspice testbench.sp -o lab8_pre.lis

# Lab9 post-sim examples
# hspice -i nand_post_tb.sp -o nand_post.lis
# hspice -i nor_post_tb.sp  -o nor_post.lis

# Open WaveView
wv &
