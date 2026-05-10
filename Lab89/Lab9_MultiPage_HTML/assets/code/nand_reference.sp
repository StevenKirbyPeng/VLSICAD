* NAND schematic netlist for LVS reference
.subckt nand A B out_2 VDD GND
* PMOS pull-up network: parallel
MPA out_2 A VDD VDD p_18 W=1u L=0.18u
MPB out_2 B VDD VDD p_18 W=1u L=0.18u
* NMOS pull-down network: series
MNA out_2 A n_mid GND n_18 W=0.5u L=0.18u
MNB n_mid B GND GND n_18 W=0.5u L=0.18u
.ends nand
