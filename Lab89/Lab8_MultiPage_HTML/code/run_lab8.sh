#!/bin/bash
set -e

echo "[1] Running HSPICE..."
hspice testbench.sp -o Lab8_result.lis

echo "[2] Check terminal: it should show job concluded."
echo "[3] Open waveform viewer with: wv &"
echo "[4] In WaveView, open Lab8_result.tr0 and select in, A, B, C, D, out_1, out_2, out_3."
