*==========================================================
* Lab8 testbench.sp
* Run: hspice testbench.sp -o Lab8_result.lis
* Open waveform: wv &  -> open Lab8_result.tr0
*==========================================================

.INC 'circuit.spi'

.GLOBAL gnd
+ vdd

.protect
* If your cic018.l path is different, modify this line.
.lib 'cic018.l' TT
.unprotect

.op
.options post
.tran 0.05n 160n
.temp 25

******** Power ********
VDD_src VDD gnd DC 1.8v
VGND_src GND gnd DC 0v

******** Input PULSE signals ********
Vin in gnd PULSE(0 1.8 0 0.1n 0.1n 20n 40n)
VA A gnd PULSE(0 1.8 0 0.1n 0.1n 20n 40n)
VB B gnd PULSE(0 1.8 0 0.1n 0.1n 40n 80n)
VC C gnd PULSE(0 1.8 0 0.1n 0.1n 20n 40n)
VD D gnd PULSE(0 1.8 0 0.1n 0.1n 40n 80n)

******** Circuit under test ********
Xinv in out_1 VDD GND inv
Xnand A B out_2 VDD GND nand
Xnor C D out_3 VDD GND nor

.end
