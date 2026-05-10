*========================================================
* testbench.sp - Lab8 pre-simulation testbench
*========================================================
.INC 'circuit.spi'
.GLOBAL gnd
+ vdd

.protect
.lib './cic018/model/cic018.l' TT
.unprotect

.op
.options post
.temp 25
.tran 0.05n 160n

* Power
VDD vdd gnd DC 1.8v
VGND gnd 0 DC 0v

* Input patterns
Vin in gnd PULSE(0 1.8 0 0.1n 0.1n 20n 40n)
VA A gnd PULSE(0 1.8 0 0.1n 0.1n 20n 40n)
VB B gnd PULSE(0 1.8 0 0.1n 0.1n 40n 80n)
VC C gnd PULSE(0 1.8 0 0.1n 0.1n 20n 40n)
VD D gnd PULSE(0 1.8 0 0.1n 0.1n 40n 80n)

* DUTs
XINV  in out_1 vdd gnd inv
XNAND A B out_2 vdd gnd nand
XNOR  C D out_3 vdd gnd nor

.end
