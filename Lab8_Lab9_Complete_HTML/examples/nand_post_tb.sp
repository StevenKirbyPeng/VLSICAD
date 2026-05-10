*========================================================
* nand_post_tb.sp - Lab9 PEX post-simulation example
* 請依 PEX 實際產生的檔名與 subckt 腳位順序調整
*========================================================
.INC 'nand.pex.netlist'
.GLOBAL gnd
+ vdd

.protect
.lib './cic018/model/cic018.l' TT
.unprotect

.op
.options post
.temp 25
.tran 0.05n 160n

VDD vdd gnd DC 1.8v
VGND gnd 0 DC 0v
VA A gnd PULSE(0 1.8 0 0.1n 0.1n 20n 40n)
VB B gnd PULSE(0 1.8 0 0.1n 0.1n 40n 80n)

* 假設 PEX netlist 中 subckt 名稱為 nand，腳位為 A B out_2 vdd gnd
XNAND_POST A B out_2 vdd gnd nand

.end
