* Example post-sim testbench. Modify include file and subckt pin order according to PEX output.
.INC 'NAND.pex.netlist'
.GLOBAL gnd
+ vdd
.protect
.lib 'cic018.l' TT
.unprotect
.op
.options post
.tran 0.05n 160n
.temp 25

VDD vdd gnd DC 1.8v
VGND gnd gnd DC 0v
VA A gnd PULSE(0 1.8 0 0.1n 0.1n 20n 40n)
VB B gnd PULSE(0 1.8 0 0.1n 0.1n 40n 80n)

* The final name and pin order must match the PEX subckt declaration.
XNAND A B out_2 vdd gnd nand
.end
