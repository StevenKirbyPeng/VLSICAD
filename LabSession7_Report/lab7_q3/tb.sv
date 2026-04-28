`include "CYCLE_MAX.sv"
`timescale 1ns/1ps

`ifdef syn
`include "/usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v"
`include "drawBbox_syn.v"
`else
`include "drawBbox.v"
`endif


`ifdef p4
    `define P4
`elsif p3
    `define P3
`elsif p2
    `define P2
`else
    `define P1
`endif

module tb (
);

integer err, count;
integer file;  
integer i;

integer error_pixels;
integer j,idx,pv;
integer total_result_pixels;

reg [31:0]   ANS[0:65535];
//drawBbox
reg         clk;
reg         rst;
reg         enable;
reg [8:0]   width;
reg [8:0]   height;
//ImgROM
reg [31:0]   Img_Q;
reg          Img_CEN;
reg [15:0]   Img_A;
//UrSRAM
reg [31:0]   Ur_Q;
reg          Ur_CEN;
reg          Ur_WEN;
reg [31:0]   Ur_D;
reg [15:0]   Ur_A;
//AnsSRAM
reg [31:0]   Ans_Q;
reg          Ans_CEN;
reg          Ans_WEN;
reg [31:0]   Ans_D;
reg [15:0]   Ans_A;
reg done;

always begin #(`CYCLE_TIME/2) clk = ~clk; end

`ifdef syn
	initial begin
        $sdf_annotate("drawBbox_syn.sdf", drawBbox);
    end
`endif

initial begin
    //initial 
    rst = 0;
    clk = 0;
    enable = 0;
    #(1*`CYCLE_TIME);
    rst = 1;
    #(5*`CYCLE_TIME);
    rst = 0;

    `ifdef P4
    $readmemh("./test_fig/result/bbox_golden4.txt", ANS);
    $readmemh("./test_fig/original/input_rgb4.txt", ImgROM.memory);
    `elsif P3
    $readmemh("./test_fig/result/bbox_golden3.txt", ANS);
    $readmemh("./test_fig/original/input_rgb3.txt", ImgROM.memory);
    `elsif P2
    $readmemh("./test_fig/result/bbox_golden2.txt", ANS);
    $readmemh("./test_fig/original/input_rgb2.txt", ImgROM.memory);
    `else // P1
    $readmemh("./test_fig/result/bbox_golden1.txt", ANS);
    $readmemh("./test_fig/original/input_rgb1.txt", ImgROM.memory);
    `endif
    //program start
    enable = 1;

    width  = 256;
    height = 256;
    total_result_pixels = width * height; 
    
    wait(done);
    $display("Simulation finish \n");
    terminal_result;
    dump_terminal_result_log;
    plot_result_bmp;

    $finish;
end

initial begin
    #(`MAX_CYCLE*`CYCLE_TIME)
    $display("-------------------------------------------------------------");
    $display("-- Reach Max cycle!!!!!!");
    $display("-- You can modify MAX_CYCLE in tb.sv if needed.");
    $display("-- Please raise DONE signal after completion");
    $display("-- Simulation terminated");
    $display("-------------------------------------------------------------");
    $finish;
end

initial begin
 //   $fsdbDumpfile("drawBbox.fsdb");
 //   $fsdbDumpvars();
//	$fsdbDumpvars("+struct", "+mda", tb);
end

RGBMEM #(.depth(65536)) ImgROM(
  .clk(clk),
  .rst(rst), 
  .A (Img_A), 
  .WEN(1'd1), 
  .CEN(Img_CEN), 
  .D (24'd0 ), 
  .Q (Img_Q )
);

RGBMEM #(.depth(65536)) AnsSRAM(
  .clk(clk), 
  .rst(rst), 
  .A (Ans_A ), 
  .WEN(Ans_WEN), 
  .CEN(Ans_CEN), 
  .D (Ans_D), 
  .Q (Ans_Q)
);

RGBMEM #(.depth(65536)) UrSRAM(
  .clk(clk), 
  .rst(rst), 
  .A (Ur_A ), 
  .WEN(Ur_WEN), 
  .CEN(Ur_CEN), 
  .D (Ur_D), 
  .Q (Ur_Q)
);

drawBbox drawBbox (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .done(done),

    //ImgROM
    .Img_Q(Img_Q),
    .Img_CEN(Img_CEN),
    .Img_A(Img_A),

    //UrSRAM
    .Ur_Q(Ur_Q),
    .Ur_CEN(Ur_CEN),
    .Ur_WEN(Ur_WEN),
    .Ur_D(Ur_D),
    .Ur_A(Ur_A),

    //AnsSRAM
    .Ans_Q(Ans_Q),
    .Ans_CEN(Ans_CEN),
    .Ans_WEN(Ans_WEN),
    .Ans_D(Ans_D),
    .Ans_A(Ans_A)
);

task terminal_result;
    begin
    err =0;
    for(i=0;i<total_result_pixels;i=i+1)begin
        if(ANS[i] !== AnsSRAM.memory[i] )begin
            err++ ;
            $write("Result[%0d][%0d], your answer:%08h, correct answer:%08h\n", i/width,i%width, AnsSRAM.memory[i], ANS[i]);
        end
    end

    error_pixels=0;

    if(err == 0)begin
     
        $display("\n");
        $display("\n");
        $display("        ****************************               ");
        $display("        **                        **       |\__||  ");
        $display("        **  Congratulations !!    **      / O.O  | ");
        $display("        **                        **    /_____   | ");
        $display("        **  Simulation PASS!!     **   /^ ^ ^ \\  |");
        $display("        **                        **  |^ ^ ^ ^ |w| ");
        $display("        ****************************   \\m___m__|_|");
        $display("\n");
        `ifdef p4
        $display("\n");
        $display("\n");
        $display("\n");
        $display("                FINALLY TIME TO SLEEP!!!!!!!!!!!!!!!!");
        $display("             _____|~~\_____      _____________");
        $display("        _-~               \\    |    \\");
        $display("        _-    | )     \\    |__/   \\   \\");
        $display("        _-         )   |   |  |     \\  \\");
        $display("        _-    | )     /    |--|      |  |");
        $display("        __-_______________ /__/_______|  |_________");
        $display("        (                |----         |  |");
        $display("        `---------------'--\\\\       .`--'");
        $display("                                      `||||");
        `endif


        $display("\n");
        $display("-------------------------------------------------------------");
  
    
    end
    else begin
        $display("-------------------------------------------------------------");
        $display("\n");
        $display("        ****************************               ");
        $display("        **                        **       |\__||  ");
        $display("        **  OOPS!!                **      / X,X  | ");
        $display("        **                        **    /_____   | ");
        $display("        **  Simulation Failed!!   **   /^ ^ ^ \\  |");
        $display("        **                        **  |^ ^ ^ ^ |w| ");
        $display("        ****************************   \\m___m__|_|");
        $display("         Totally has %d errors                     ", err); 
        $display("\n");
        $display("-------------------------------------------------------------");
    end
    end
endtask

task dump_terminal_result_log;
    integer f_out;
    begin
        f_out = $fopen("terminal_result.log", "w");
        
        if (f_out == 0) begin
            $display("Error: Failed to open terminal_result.log for writing!");
        end else begin
            $display("Writing terminal_result output to terminal_result.log...");
            
            err = 0;
            for(i=0; i<total_result_pixels; i=i+1) begin
                if(ANS[i] !== AnsSRAM.memory[i]) begin
                    err = err + 1;
                    $fwrite(f_out, "Result[%0d][%0d], your answer:%08h, correct answer:%08h\n", i/width, i%width, AnsSRAM.memory[i], ANS[i]);
                end
            end

            if(err == 0) begin
                $fwrite(f_out, "\n");
                $fwrite(f_out, "\n");
                $fwrite(f_out, "        ****************************               \n");
                $fwrite(f_out, "        **                        **       |\__||  \n");
                $fwrite(f_out, "        **  Congratulations !!    **      / O.O  | \n");
                $fwrite(f_out, "        **                        **    /_____   | \n");
                $fwrite(f_out, "        **  Simulation PASS!!     **   /^ ^ ^ \\  |\n");
                $fwrite(f_out, "        **                        **  |^ ^ ^ ^ |w| \n");
                $fwrite(f_out, "        ****************************   \\m___m__|_|\n");
                $fwrite(f_out, "\n");
                `ifdef p4
                $fwrite(f_out, "                FINALLY TIME TO SLEEP!!!!!!!!!!!!!!!!\n");
                $fwrite(f_out, "             _____|~~\\_____      _____________\n");
                $fwrite(f_out, "        _-~               \\\\    |    \\\n");
                $fwrite(f_out, "        _-    | )     \\\\    |__/   \\   \\\n");
                $fwrite(f_out, "        _-         )   |   |  |     \\  \\\n");
                $fwrite(f_out, "        _-    | )     /    |--|      |  |\n");
                $fwrite(f_out, "        __-_______________ /__/_______|  |_________\n");
                $fwrite(f_out, "        (                |----         |  |\n");
                $fwrite(f_out, "        `---------------'--\\\\       .`--'\n");
                $fwrite(f_out, "                                      `||||\n");
                `endif
                $fwrite(f_out, "\n-------------------------------------------------------------\n");
            end else begin
                $fwrite(f_out, "-------------------------------------------------------------\n");
                $fwrite(f_out, "\n");
                $fwrite(f_out, "        ****************************               \n");
                $fwrite(f_out, "        **                        **       |\__||  \n");
                $fwrite(f_out, "        **  OOPS!!                **      / X,X  | \n");
                $fwrite(f_out, "        **                        **    /_____   | \n");
                $fwrite(f_out, "        **  Simulation Failed!!   **   /^ ^ ^ \\  |\n");
                $fwrite(f_out, "        **                        **  |^ ^ ^ ^ |w| \n");
                $fwrite(f_out, "        ****************************   \\m___m__|_|\n");
                $fwrite(f_out, "         Totally has %d errors                     ", err); 
                $fwrite(f_out, "\n");
                $fwrite(f_out, "-------------------------------------------------------------\n");
            end

            $fclose(f_out);
            $display("Done! Log successfully saved to terminal_result.log");
        end
    end
endtask

task plot_result_bmp;
    integer obmp, i, j;
    reg [31:0] pix;

    `ifdef P4
    begin
        $display("Plotting 256x256 32-bit BMP result...");

        obmp = $fopen("drawBbox_result_p4.bmp", "wb");
        if (obmp == 0) begin
            $display("Error: Failed to open drawBbox_result_p4.bmp for writing!");
            $finish;
        end

        $fwrite(obmp, "%c%c", 8'h42, 8'h4D);                  
        $fwrite(obmp, "%c%c%c%c", 8'h36, 8'h00, 8'h04, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h36, 8'h00, 8'h00, 8'h00);

        $fwrite(obmp, "%c%c%c%c", 8'h28, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h01, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h01, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c",      8'h01, 8'h00);             
        $fwrite(obmp, "%c%c",      8'h20, 8'h00);             
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h04, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);

        for (i = 255; i >= 0; i = i - 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                pix = tb.AnsSRAM.memory[i * 256 + j];  // 00RRGGBB

                // write B, G, R, 00
                $fwrite(obmp, "%c%c%c%c",
                        pix[7:0],    // BB
                        pix[15:8],   // GG
                        pix[23:16],  // RR
                        pix[31:24]); // 00
            end
        end

        $fflush(obmp);
        $fclose(obmp);
        $display("32-bit BMP plotted to drawBbox_result_p4.bmp");
    end
    `elsif P3
    begin
        $display("Plotting 256x256 32-bit BMP result...");

        obmp = $fopen("drawBbox_result_p3.bmp", "wb");
        if (obmp == 0) begin
            $display("Error: Failed to open drawBbox_result_p3.bmp for writing!");
            $finish;
        end

        $fwrite(obmp, "%c%c", 8'h42, 8'h4D);                  
        $fwrite(obmp, "%c%c%c%c", 8'h36, 8'h00, 8'h04, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h36, 8'h00, 8'h00, 8'h00);

        $fwrite(obmp, "%c%c%c%c", 8'h28, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h01, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h01, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c",      8'h01, 8'h00);             
        $fwrite(obmp, "%c%c",      8'h20, 8'h00);             
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h04, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);

        for (i = 255; i >= 0; i = i - 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                pix = tb.AnsSRAM.memory[i * 256 + j];  // 00RRGGBB

                // write B, G, R, 00
                $fwrite(obmp, "%c%c%c%c",
                        pix[7:0],    // BB
                        pix[15:8],   // GG
                        pix[23:16],  // RR
                        pix[31:24]); // 00
            end
        end

        $fflush(obmp);
        $fclose(obmp);
        $display("32-bit BMP plotted to drawBbox_result_p3.bmp");
    end
    `elsif P2
    begin
        $display("Plotting 256x256 32-bit BMP result...");

        obmp = $fopen("drawBbox_result_p2.bmp", "wb");
        if (obmp == 0) begin
            $display("Error: Failed to open drawBbox_result_p2.bmp for writing!");
            $finish;
        end

        $fwrite(obmp, "%c%c", 8'h42, 8'h4D);                  
        $fwrite(obmp, "%c%c%c%c", 8'h36, 8'h00, 8'h04, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h36, 8'h00, 8'h00, 8'h00);

        $fwrite(obmp, "%c%c%c%c", 8'h28, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h01, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h01, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c",      8'h01, 8'h00);             
        $fwrite(obmp, "%c%c",      8'h20, 8'h00);             
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h04, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);

        for (i = 255; i >= 0; i = i - 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                pix = tb.AnsSRAM.memory[i * 256 + j];  // 00RRGGBB

                // write B, G, R, 00
                $fwrite(obmp, "%c%c%c%c",
                        pix[7:0],    // BB
                        pix[15:8],   // GG
                        pix[23:16],  // RR
                        pix[31:24]); // 00
            end
        end

        $fflush(obmp);
        $fclose(obmp);
        $display("32-bit BMP plotted to drawBbox_result_p2.bmp");
    end
    `else // P1
    begin
        $display("Plotting 256x256 32-bit BMP result...");

        obmp = $fopen("drawBbox_result_p1.bmp", "wb");
        if (obmp == 0) begin
            $display("Error: Failed to open drawBbox_result_p1.bmp for writing!");
            $finish;
        end

        $fwrite(obmp, "%c%c", 8'h42, 8'h4D);                  
        $fwrite(obmp, "%c%c%c%c", 8'h36, 8'h00, 8'h04, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h36, 8'h00, 8'h00, 8'h00);

        $fwrite(obmp, "%c%c%c%c", 8'h28, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h01, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h01, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c",      8'h01, 8'h00);             
        $fwrite(obmp, "%c%c",      8'h20, 8'h00);             
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h04, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
        $fwrite(obmp, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);

        for (i = 255; i >= 0; i = i - 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                pix = tb.AnsSRAM.memory[i * 256 + j];  // 00RRGGBB

                // write B, G, R, 00
                $fwrite(obmp, "%c%c%c%c",
                        pix[7:0],    // BB
                        pix[15:8],   // GG
                        pix[23:16],  // RR
                        pix[31:24]); // 00
            end
        end

        $fflush(obmp);
        $fclose(obmp);
        $display("32-bit BMP plotted to drawBbox_result_p1.bmp");
    end
    `endif
endtask

endmodule

module RGBMEM #(parameter depth=16384)(clk, rst, A, CEN, WEN, D, Q);

  input                                 clk;
  input                                 rst;
  input  [$clog2(depth)-1:0]              A;
  input                                 CEN;
  input                                 WEN;
  input  [31:0]                            D;
  output [31:0]                            Q;

  reg    [31:0]                            Q;
  reg    [$clog2(depth)-1:0]      latched_A;
  reg    [$clog2(depth)-1:0]  latched_A_neg;
  reg    [31:0] memory           [0:depth-1];
  integer                                 j;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
        for ( j=0 ; j<depth; j=j+1) begin
            memory[j] <= 32'b0;
        end
    end
    else begin
        if (~WEN && ~CEN ) begin
            memory[A] <= D;
        end
        if (~CEN) begin
           latched_A <= A;
        end
            
    end
  end
  
  always@(negedge clk) begin
    if (~CEN) latched_A_neg <= latched_A;
  end
  
  always @(*) begin
    if (~CEN) begin
      Q = memory[latched_A_neg];
    end
    else begin
      Q = 32'hzzzz_zzzz;
    end
  end

endmodule