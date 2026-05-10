* NOR schematic netlist for LVS reference
.subckt nor C D out_3 VDD GND
* PMOS pull-up network: series
MPC out_3 C p_mid VDD p_18 W=1u L=0.18u
MPD p_mid D VDD VDD p_18 W=1u L=0.18u
* NMOS pull-down network: parallel
MNC out_3 C GND GND n_18 W=0.5u L=0.18u
MND out_3 D GND GND n_18 W=0.5u L=0.18u
.ends nor
