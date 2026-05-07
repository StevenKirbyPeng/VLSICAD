`timescale 1ns/1ps
// ============================================================================
// File        : drawBbox_report_style_clean_v1.v
// Module      : drawBbox
// Lab         : iVCAD Lab7 - Draw Bounding Box
//
// Design summary
//   This RTL keeps a single public submit file while separating the image
//   processing flow into four hardware stages.  The top module is responsible
//   only for stage scheduling and SRAM/ROM ownership selection.  The arithmetic
//   and image-processing operations stay inside their corresponding stage
//   modules so that the synthesis tool can optimize smaller logic cones.
//
// Processing flow
//   1. threshold_v21_fast : RGB-to-gray conversion, 3x3 Gaussian smoothing,
//                           histogram accumulation, and Otsu threshold search.
//   2. polarity_v21_fast  : foreground polarity decision using the number of
//                           pixels above/below the selected threshold.
//   3. ccl_v21_fast       : connected-component labeling and equivalence-table
//                           resolution.
//   4. boxing_v21_fast    : bounding-box coordinate extraction and green box
//                           overlay on the final output image.
//
// Fixed-point arithmetic notes
//   Grayscale conversion is implemented as an integer approximation of
//       Gray = 0.299R + 0.587G + 0.114B
//   using Q16 coefficients:
//       Gray = round_even((19595R + 38470G + 7471B) / 65536)
//
//   Gaussian smoothing uses the separable 3x3 kernel
//       [1 2 1; 2 4 2; 1 2 1] / 16
//   and is implemented with shifts and additions instead of multipliers.
//
//   Otsu score comparison avoids direct division in the critical comparison by
//   using cross multiplication:
//       score(T) = numerator(T) / denominator(T)
//       score(a) >= score(b)  <=>  numerator(a)*denominator(b)
//                                 >= numerator(b)*denominator(a)
//
// Interface note
//   The external top-module name and ports are intentionally unchanged so the
//   original Lab7 testbench can instantiate this design without modification.
// ============================================================================
module drawBbox (
    input      clk, // 系統時脈輸入
    input      rst, // 同步或非同步重置信號
    input      enable, // 啟動整體影像處理流程
    output     done, // 輸出完成旗標
    // ImgROM
    input      [31:0] Img_Q, // ImgROM 讀回的 32-bit RGB pixel
    output            Img_CEN, // ImgROM 低有效 chip enable
    output reg [15:0] Img_A, // ImgROM 讀取位址
    // UrSRAM
    input       [31:0] Ur_Q, // UrSRAM 讀回資料
    output             Ur_CEN, // UrSRAM 低有效 chip enable
    output             Ur_WEN, // UrSRAM 讀寫控制，0 為寫入、1 為讀取
    output      [15:0] Ur_A, // UrSRAM 存取位址
    output      [31:0] Ur_D, // UrSRAM 寫入資料
    // AnsSRAM
    input      [31:0] Ans_Q, // AnsSRAM 讀回資料
    output            Ans_CEN, // AnsSRAM 低有效 chip enable
    output            Ans_WEN, // AnsSRAM 讀寫控制，0 為寫入、1 為讀取
    output     [31:0] Ans_D, // AnsSRAM 寫入資料
    output     [15:0] Ans_A // AnsSRAM 存取位址
);
// ---------------------------------------------------------------------------
// Top-level stage controller
//   The top FSM grants memory ownership to exactly one processing stage at a
//   time.  Each stage receives a one-cycle start pulse only after the FSM has
//   entered that stage, preventing a submodule from using a stale bus owner.
// ---------------------------------------------------------------------------
localparam ST_IDLE  = 3'd0; // FSM 狀態或常數參數宣告
localparam ST_THRES = 3'd1; // FSM 狀態或常數參數宣告
localparam ST_POL   = 3'd2; // FSM 狀態或常數參數宣告
localparam ST_CCL   = 3'd3; // FSM 狀態或常數參數宣告
localparam ST_BOX   = 3'd4; // FSM 狀態或常數參數宣告
wire box_done; // bounding-box stage 完成旗標
reg [2:0] state, next_state; // 目前 top FSM 狀態
reg [2:0] state_d; // 前一拍 top FSM 狀態，用於產生 start pulse
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state   <= ST_IDLE;
        state_d <= ST_IDLE;
    end else begin
        state_d <= state;
        state   <= next_state;
    end
end
// Stage-aligned one-cycle start pulses.
// A pulse is generated on the first cycle after the top controller changes
// stage, so the memory mux and control path are already consistent.
wire start_thres = (state == ST_THRES) && (state_d != ST_THRES); // 子模組 one-cycle start pulse 控制信號
wire start_pol   = (state == ST_POL)   && (state_d != ST_POL); // 子模組 one-cycle start pulse 控制信號
wire start_ccl   = (state == ST_CCL)   && (state_d != ST_CCL); // 子模組 one-cycle start pulse 控制信號
wire start_box   = (state == ST_BOX)   && (state_d != ST_BOX); // 子模組 one-cycle start pulse 控制信號
// ---------------------------------------------------------------------------
// Stage 1: grayscale, Gaussian filter, histogram, and Otsu threshold search
// ---------------------------------------------------------------------------
wire [7:0] threshold; // Otsu 計算後的 8-bit threshold
wire thres_done; // threshold stage 完成旗標
wire thres_img_cen; // 記憶體 chip enable 控制信號
wire [15:0] thres_img_addr; // 記憶體位址匯流排信號
wire thres_ur_cen; // 記憶體 chip enable 控制信號
wire thres_ur_wen; // SRAM 讀寫控制信號
wire [15:0] thres_ur_a; // 記憶體位址匯流排信號
wire [31:0] thres_ur_d; // 資料寫入或中間資料匯流排信號
threshold_v21_fast thres(
    .clk(clk),
    .rst(rst),
    .start(start_thres), // top-state aligned 1-cycle start pulse
    .Threshold(threshold),
    .done(thres_done),
    .Img_Q(Img_Q),
    .Img_CEN(thres_img_cen),
    .Img_addr(thres_img_addr),
    .Ur_Q(Ur_Q),
    .Ur_CEN(thres_ur_cen),
    .Ur_WEN(thres_ur_wen),
    .Ur_A(thres_ur_a),
    .Ur_D(thres_ur_d)
);
// ---------------------------------------------------------------------------
// Stage 2: foreground polarity correction
// ---------------------------------------------------------------------------
wire pol_done; // 子模組完成或控制握手信號
wire pol_flag; // 組合邏輯連接信號宣告
wire pol_img_cen; // 記憶體 chip enable 控制信號
wire pol_img_wen; // SRAM 讀寫控制信號
wire [15:0] pol_img_addr; // 記憶體位址匯流排信號
polarity_v21_fast u_polarity(
    .clk(clk),
    .rst(rst),
    .valid(start_pol), // top-state aligned 1-cycle start pulse
    .threshold(threshold),
    .Img_Q(Ur_Q),
    .Img_CEN(pol_img_cen),
    .Img_A(pol_img_addr),
    .Img_WEN(pol_img_wen),
    .done(pol_done),
    .polarity(pol_flag)
);
// ---------------------------------------------------------------------------
// Stage 3: connected-component labeling
// ---------------------------------------------------------------------------
wire ccl_done; // 子模組完成或控制握手信號
wire ccl_img_cen; // 記憶體 chip enable 控制信號
wire ccl_img_wen; // SRAM 讀寫控制信號
wire [15:0] ccl_img_addr; // 記憶體位址匯流排信號
wire [9:0] total_label; // 組合邏輯連接信號宣告
wire ccl_ans_cen; // 記憶體 chip enable 控制信號
wire ccl_ans_wen; // SRAM 讀寫控制信號
wire [15:0] ccl_ans_addr; // 記憶體位址匯流排信號
wire [31:0] ccl_ans_d; // 資料寫入或中間資料匯流排信號
ccl_v21_fast u_ccl(
    .clk(clk),
    .rst(rst),
    .threshold(threshold),
    .labeler_en(start_ccl),
    .polarity(pol_flag),
    .img_cen(ccl_img_cen),
    .img_addr(ccl_img_addr),
    .img_wen(ccl_img_wen),
    .img_Q(Ur_Q),
    .ans_cen(ccl_ans_cen),
    .ans_wen(ccl_ans_wen),
    .ans_addr(ccl_ans_addr),
    .ans_D(ccl_ans_d),
    .ans_Q(Ans_Q),
    .labeler_done(ccl_done),
    .total_label(total_label)
);
// ---------------------------------------------------------------------------
// Stage 4: bounding-box extraction and final overlay
// ---------------------------------------------------------------------------
wire box_img_cen; // 記憶體 chip enable 控制信號
wire [15:0] box_img_addr; // 記憶體位址匯流排信號
wire box_ans_cen; // 記憶體 chip enable 控制信號
wire box_ans_wen; // SRAM 讀寫控制信號
wire [15:0] box_ans_addr; // 記憶體位址匯流排信號
wire [31:0] box_ans_d; // 資料寫入或中間資料匯流排信號
boxing_v21_fast u_boxing(
    .clk(clk),
    .rst(rst),
    .enable(start_box),
    .done(box_done), // Final-stage done signal returned to top controller
    .total_label(total_label),
    .Img_Q(Img_Q),
    .Img_CEN(box_img_cen),
    .Img_A(box_img_addr),
    .Ans_Q(Ans_Q),
    .Ans_CEN(box_ans_cen),
    .Ans_WEN(box_ans_wen),
    .Ans_D(box_ans_d),
    .Ans_A(box_ans_addr)
);
// ---------------------------------------------------------------------------
// Memory ownership selection
//   ImgROM is used by threshold and boxing.
//   UrSRAM stores the filtered grayscale image and is read by polarity/CCL.
//   AnsSRAM stores labels during CCL and the final RGB image during boxing.
// ---------------------------------------------------------------------------
// ImgROM owner selection
assign Img_CEN = (state == ST_THRES) ? thres_img_cen :
                 (state == ST_BOX)   ? box_img_cen   : 1'b1;
always @(*) begin
    if      (state == ST_THRES) Img_A = thres_img_addr;
    else if (state == ST_BOX)   Img_A = box_img_addr;
    else                        Img_A = 16'd0;
end
// UrSRAM owner selection
assign Ur_CEN  = (state == ST_THRES) ? thres_ur_cen :
                 (state == ST_POL)   ? pol_img_cen  :
                 (state == ST_CCL)   ? ccl_img_cen  : 1'b1;
assign Ur_WEN  = (state == ST_THRES) ? thres_ur_wen : 1'b1;
assign Ur_A    = (state == ST_THRES) ? thres_ur_a   :
                 (state == ST_POL)   ? pol_img_addr :
                 (state == ST_CCL)   ? ccl_img_addr : 16'd0;
assign Ur_D    = (state == ST_THRES) ? thres_ur_d   : 32'd0;
// AnsSRAM owner selection
assign Ans_CEN = (state == ST_CCL) ? ccl_ans_cen  :
                 (state == ST_BOX) ? box_ans_cen  : 1'b1;
assign Ans_WEN = (state == ST_CCL) ? ccl_ans_wen  :
                 (state == ST_BOX) ? box_ans_wen  : 1'b1;
assign Ans_A   = (state == ST_CCL) ? ccl_ans_addr :
                 (state == ST_BOX) ? box_ans_addr : 16'd0;
assign Ans_D   = (state == ST_CCL) ? ccl_ans_d    :
                 (state == ST_BOX) ? box_ans_d    : 32'd0;
always @(*) begin
    case (state)
        ST_IDLE:  if (enable)     next_state = ST_THRES; else next_state = ST_IDLE;
        ST_THRES: if (thres_done) next_state = ST_POL;   else next_state = ST_THRES;
        ST_POL:   if (pol_done)   next_state = ST_CCL;   else next_state = ST_POL;
        ST_CCL:   if (ccl_done)   next_state = ST_BOX;   else next_state = ST_CCL;
        ST_BOX:   if (box_done)   next_state = ST_IDLE;  else next_state = ST_BOX;
        default:  next_state = ST_IDLE;
    endcase
end
assign done = box_done; // Done is asserted when the final overlay stage finishes.
// assign done = ccl_done; // Debug-only alternative, not used for final output.
endmodule
// ============================================================================
// Stage module: threshold_v21_fast
// Function
//   1. Read original RGB pixels from ImgROM.
//   2. Convert RGB to grayscale with fixed-point round-to-nearest-even.
//   3. Apply 3x3 Gaussian smoothing with reflect-101 boundary handling.
//   4. Write filtered gray values to UrSRAM and build a 256-bin histogram.
//   5. Search Otsu threshold using integer cross-multiplied score comparison.
// ============================================================================
(* keep_hierarchy = "yes" *)
module threshold_v21_fast (
    input      clk, // 系統時脈輸入
    input      rst, // 同步或非同步重置信號
    input      start,   // One-cycle start pulse from the top controller
    output [7:0] Threshold, // Selected Otsu threshold
    output reg done,    // High after threshold stage completes
    // ImgROM
    input      [31:0] Img_Q, // ImgROM 讀回的 32-bit RGB pixel
    output            Img_CEN, // Active-low ImgROM chip enable
    output reg [15:0] Img_addr, // top/module 介面訊號宣告
    // UrSRAM
    input       [31:0] Ur_Q, // UrSRAM 讀回資料
    output             Ur_CEN, // UrSRAM 低有效 chip enable
    output             Ur_WEN, // UrSRAM 讀寫控制，0 為寫入、1 為讀取
    output      [15:0] Ur_A, // UrSRAM 存取位址
    output      [31:0] Ur_D // UrSRAM 寫入資料
);
reg [3:0] state; // 目前 top FSM 狀態
reg [15:0]  counter; // 循序計數器暫存器宣告
wire[16:0]  next_counter; // 組合邏輯連接信號宣告
assign next_counter = counter + 16'b1;
integer i; // Reset loop index
reg Img_cen; // 循序邏輯暫存器宣告
assign Img_CEN = Img_cen;
reg Ur_wen; // 循序邏輯暫存器宣告
assign Ur_WEN = Ur_wen;
reg Ur_cen; // 循序邏輯暫存器宣告
assign Ur_CEN = Ur_cen;
reg [15:0] Ur_addr; // 位址暫存器宣告
assign Ur_A = Ur_addr;
reg [31:0] Ur_d; // 循序邏輯暫存器宣告
assign Ur_D = Ur_d;
// RGB-to-gray fixed-point conversion
wire [25:0] gray_fixed_q16; // 組合邏輯連接信號宣告
wire [7:0] gray_u8;  // 8-bit rounded grayscale value
wire round_up = (gray_fixed_q16[15:0] > 16'h8000) || // 組合邏輯連接信號宣告
                  ((gray_fixed_q16[15:0] == 16'h8000) && (gray_fixed_q16[16] == 1'b1)); // Round-to-nearest-even decision
assign gray_fixed_q16 = (26'd19595 * Img_Q[23:16]) +
                                 (26'd38470 * Img_Q[15:8])  +
                                 (26'd7471  * Img_Q[7:0]); // Q16 fixed-point gray = round_even((19595R + 38470G + 7471B) >> 16).
assign gray_u8 = round_up ? (gray_fixed_q16[23:16] + 8'd1) :
                                           (gray_fixed_q16[23:16]);
// Gaussian 3x3 kernel arithmetic
reg [7:0] u1, u2, u3, m1, m2, m3, b1, b2, b3;    // 3x3 neighborhood samples
wire [15:0] gaussian_sum = (u1) + (u2<<1) + (u3) + // 組合邏輯連接信號宣告
                             (m1<<1) + (m2<<2) + (m3<<1) +
                             (b1) + (b2<<1) + (b3);   // Divide by 16 after rounding
wire gaussian_round_up = (gaussian_sum[3:0] > 4'b1000) || // 組合邏輯連接信號宣告
                         ((gaussian_sum[3:0] == 4'b1000) && (gaussian_sum[4] == 1'b1)); // Round-to-nearest-even decision
wire [7:0] gaussian_value = gaussian_round_up ? (gaussian_sum[11:4] + 8'd1) : (gaussian_sum[11:4]); // 組合邏輯連接信號宣告
wire Is_the_most_up = (counter[15:8] == 8'd0)?1'b1:1'b0; // 組合邏輯連接信號宣告
wire Is_the_most_buttom = (counter[15:8] == 8'd255)?1'b1:1'b0; // 組合邏輯連接信號宣告
wire Is_the_most_left = (counter[7:0] == 8'd0)?1'b1:1'b0; // 組合邏輯連接信號宣告
wire Is_the_most_right = (counter[7:0] == 8'd255)?1'b1:1'b0; // 組合邏輯連接信號宣告
// Gaussian window address/control signals
reg [3:0]get_data_state; // FSM 狀態暫存器宣告
wire [4:0]next_get_data_state = (get_data_state == 4'd11)? 4'b0 : (get_data_state + 4'b1); // 資料寫入或中間資料匯流排信號
wire[15:0]up_index = counter - 16'd256; // 組合邏輯連接信號宣告
wire[15:0]buttom_index = counter + 16'd256; // 組合邏輯連接信號宣告
// Histogram and Otsu scan registers
reg [1:0] otsu_scan_state ; // FSM 狀態暫存器宣告
reg [15:0] hist_bin[255:0];  // 256-bin grayscale histogram
wire [16:0] next_hist_bin_count = hist_bin[gaussian_value] + 16'b1; // 組合邏輯連接信號宣告
reg [23:0] bg_gray_sum;    // Maximum gray sum fits in 24 bits for 65536 pixels
wire [24:0] next_bg_gray_sum; // 組合邏輯連接信號宣告
assign next_bg_gray_sum = bg_gray_sum + (hist_bin[counter]*counter);
reg [23:0] fg_gray_sum; // 整數運算累加或比較暫存器宣告
wire [24:0] next_fg_gray_sum; // 組合邏輯連接信號宣告
assign next_fg_gray_sum = fg_gray_sum + (hist_bin[counter]*counter);
// Otsu class statistics
reg [15:0] fg_pixel_count; // 循序邏輯暫存器宣告
wire [16:0] next_fg_pixel_count = fg_pixel_count + hist_bin[counter]; // 組合邏輯連接信號宣告
reg [15:0] bg_pixel_count; // 循序邏輯暫存器宣告
wire [16:0] next_bg_pixel_count = bg_pixel_count + hist_bin[counter]; // 組合邏輯連接信號宣告
reg [7:0] threshold_scan_value; // 循序邏輯暫存器宣告
wire [8:0] next_threshold_scan_value = (threshold_scan_value == 0)? 8'b0 : threshold_scan_value - 8'b1; // 組合邏輯連接信號宣告
wire [40:0] term_f = fg_gray_sum * bg_pixel_count; // 24bit*17bit=41bit
wire [40:0] term_b = bg_gray_sum * fg_pixel_count; // 24bit*17bit=41bit
// Otsu numerator: squared difference term
wire [40:0] diff_term = (term_f > term_b) ? (term_f - term_b) : (term_b - term_f); // 組合邏輯連接信號宣告
wire [81:0] num_curr  = diff_term * diff_term; // 41-bit * 41-bit = 82-bit
// Otsu denominator: foreground_count * background_count
wire [33:0] den_curr  = fg_pixel_count * bg_pixel_count; // 17-bit * 17-bit = 34-bit
// Division-free score comparison by cross multiplication
reg [81:0] num_max; // 循序邏輯暫存器宣告
reg [33:0] den_max; // 循序邏輯暫存器宣告
reg [7:0]  best_threshold_reg; // Best threshold found so far
assign Threshold = best_threshold_reg; // Export selected threshold to later stages
// Division-free score comparison by cross multiplication
wire [115:0] cross_left  = num_curr * den_max; // 組合邏輯連接信號宣告
wire [115:0] cross_right = num_max * den_curr; // 組合邏輯連接信號宣告
always@(posedge rst or posedge clk) begin
    if(rst) begin   // Asynchronous reset values
	done <= 1'd0;
        counter <= 16'd0;
        state <= 2'd0;
        Img_cen <= 1'd0;    // Enable ImgROM read by default in this stage
	    Img_addr <= 16'd0;
        Ur_cen <= 1'b0;
        Ur_addr <= 16'd0;
        Ur_d <= 32'd0;
        // Clear Gaussian window registers
        get_data_state <= 4'd0;
        u1 <= 8'd0;
        u2 <= 8'd0;
        u3 <= 8'd0;
        m1 <= 8'd0;
        m2 <= 8'd0;
        m3 <= 8'd0;
        b1 <= 8'd0;
        b2 <= 8'd0;
        b3 <= 8'd0;
        // Clear histogram and Otsu scan registers
        otsu_scan_state <= 2'd0;
        for(i = 0; i < 256; i = i + 1) begin
		    hist_bin[i] <= 16'b0;
        end
        threshold_scan_value <= 8'b0;
        bg_gray_sum <= 24'd0;
        fg_gray_sum <= 24'd0;
        fg_pixel_count <= 16'd0;
        bg_pixel_count <= 16'd0;
        best_threshold_reg <= 8'd0;
	num_max <= 82'd0;
        den_max <= 34'd0;
    end else if (start && state == 2'd0) begin // Stage start: enable scan and initialize nonzero denominator
        state <= 2'd1;
        Ur_wen <= 1'b1;
	den_max <= 34'd1; // Avoid zero denominator during first comparison
    end else if(state == 2'd1) begin   // Collect the 3x3 neighborhood window
	    if(get_data_state == 0)begin
            	Ur_wen <= 1'b1;	// Disable UrSRAM write while reading the source pixel
		Img_addr <= up_index - 16'd1;
	    end else if (get_data_state == 1)begin
		Img_addr <= up_index;
	    end else if(get_data_state == 2)begin   // Two-cycle ROM latency alignment
		    Img_addr <= up_index + 16'd1;
            	u1 <= gray_u8;
	    end else if(get_data_state == 3)begin
            	Img_addr <= counter - 16'd1;
            u2 <= gray_u8;
	    end else if (get_data_state == 4)begin
			Img_addr <= counter;
            u3 <= gray_u8;
	    end else if(get_data_state == 5)begin   // Two-cycle ROM latency alignment
		    Img_addr <= counter + 16'd1;
            m1 <= gray_u8;
	    end else if(get_data_state == 6)begin
            Img_addr <= buttom_index - 16'd1;
            m2 <= gray_u8;
	    end else if (get_data_state == 7)begin
			Img_addr <= buttom_index;
            m3 <= gray_u8;
	    end else if(get_data_state == 8)begin   // Two-cycle ROM latency alignment
		    Img_addr <= buttom_index + 16'd1;
            b1 <= gray_u8;
	    end else if(get_data_state == 9)begin
            b2 <= gray_u8;
	    end else if(get_data_state == 10)begin
            b3 <= gray_u8; // Last sample of the 3x3 window
	    end else if(get_data_state == 11)begin      // Apply reflect-101 boundary remapping before Gaussian calculation
		if(Is_the_most_up && Is_the_most_left) begin    // Reflect-101 padding
                u1 <= b3;  // Corner reflection
                u3 <= b3;
                b1 <= b3;
                u2 <= b2;   // Edge reflection
                m1 <= m3;
            end else if(Is_the_most_up && Is_the_most_right) begin
                u1 <= b1;  // Corner reflection
                u3 <= b1;
                b3 <= b1;
                u2 <= b2;   // Edge reflection
                m3 <= m1;
            end else if(Is_the_most_buttom && Is_the_most_left) begin
                u1 <= u3;  // Corner reflection
                b1 <= u3;
                b3 <= u3;
                b2 <= u2;   // Edge reflection
                m1 <= m3;
            end else if(Is_the_most_buttom && Is_the_most_right) begin
                u3 <= u1;  // Corner reflection
                b1 <= u1;
                b3 <= u1;
                b2 <= u2;   // Edge reflection
                m3 <= m1;
            end else if(Is_the_most_up) begin
                u1 <= b1;
                u2 <= b2;
                u3 <= b3;
            end else if(Is_the_most_buttom) begin
                b1 <= u1;
                b2 <= u2;
                b3 <= u3;
            end else if(Is_the_most_left) begin
                u1 <= u3;
                m1 <= m3;
                b1 <= b3;
            end else if(Is_the_most_right) begin
                u3 <= u1;
                m3 <= m1;
                b3 <= b1;
            end
		    state <= 2'd2; // Gaussian value is now ready for SRAM write
        end
		get_data_state <= next_get_data_state[3:0];
    end else if(state == 2'd2) begin   // Write Gaussian result and update histogram
        Ur_wen <= 0;	// Active-low write enable
	Ur_addr <= counter;
        Ur_d <= {24'b0, gaussian_value}; // Store Gaussian-filtered gray value in UrSRAM
        hist_bin[gaussian_value] <= next_hist_bin_count[15:0]; // Accumulate histogram bin for Otsu thresholding
	    if(counter == 16'd65535)begin   // All pixels have been filtered
		counter <= 16'b0;   // Reset address counter for threshold scan
        	state <= 2'd3; // Enter Otsu threshold scan
		threshold_scan_value <= 255;
	    end else begin
		counter <= next_counter[15:0];
        	state <= 2'd1;  // Continue with next pixel window
	    end
    end else if(state == 2'd3) begin   // Sweep all threshold candidates
        if(otsu_scan_state == 2'd0)begin  // Initialize one threshold-candidate scan
	    Ur_wen <= 1;
            threshold_scan_value <= next_threshold_scan_value[7:0]; // Skip degenerate endpoint threshold and start from 254
            bg_gray_sum <= 24'b0;
            fg_gray_sum <= 24'b0;
            fg_pixel_count <= 16'd0;
            bg_pixel_count <= 16'd0;
            otsu_scan_state <= 2'd1;
        end else if(otsu_scan_state == 2'd1)begin // Accumulate foreground/background statistics for one candidate
            if(counter[7:0] > threshold_scan_value) begin // Foreground side of candidate threshold
                fg_gray_sum <= next_fg_gray_sum[23:0]; // Sum of gray values in foreground class
                fg_pixel_count <= next_fg_pixel_count[15:0]; // Pixel count of foreground class
            end else begin // Background side of candidate threshold
		bg_gray_sum <= next_bg_gray_sum[23:0]; // Sum of gray values in background class
                bg_pixel_count <= next_bg_pixel_count[15:0]; // Pixel count of background class
            end
	        if(counter == 16'd255)begin
        	    otsu_scan_state <= 2'd2;
		        counter <= 16'd0;
	        end else begin
		        counter <= next_counter[15:0];
	        end
        end else if(otsu_scan_state == 2'd2)begin
		if (cross_left >= cross_right && cross_left) begin
            		num_max <= num_curr; // Store numerator of the best score
            		den_max <= den_curr; // Store denominator of the best score
            		best_threshold_reg   <= threshold_scan_value; // Store threshold that gives the best score
        	end
		if(threshold_scan_value == 8'd0)begin // Otsu scan finished
                    state <= 2'd0; // Return to idle after completion
		    counter <= 0;
		    done <= 1'b1;
                end else begin
                    otsu_scan_state <= 2'd0; // Continue with the next threshold candidate
                end
        end
    end
end
endmodule
// ============================================================================
// Stage module: polarity_v21_fast
// Function
//   Count the thresholded pixels and determine whether the foreground is the
//   high-gray side or the low-gray side.  This prevents the binary mask from
//   being inverted when the object/background intensity relation changes.
// ============================================================================
(* keep_hierarchy = "yes" *)
module polarity_v21_fast(
    input clk,rst, // 系統時脈輸入
    input valid, // top/module 介面訊號宣告
    input [7:0] threshold, // Otsu 計算後的 8-bit threshold
    // ImgROM
    input [31:0] Img_Q, // ImgROM 讀回的 32-bit RGB pixel
    output reg Img_CEN, // ImgROM 低有效 chip enable
    output reg [15:0] Img_A, // ImgROM 讀取位址
    output Img_WEN, // top/module 介面訊號宣告
    output reg done, // 輸出完成旗標
    output reg polarity // Polarity decision output
);
    assign Img_WEN = 1'b1;
    reg [7:0] counter; // 循序計數器暫存器宣告
    reg [1:0] cs,ns; // 循序邏輯暫存器宣告
    reg proc_done; // 循序邏輯暫存器宣告
    localparam IDLE = 2'b00; // FSM 狀態或常數參數宣告
    localparam PROCESS = 2'b01; // FSM 狀態或常數參數宣告
    localparam DONE = 2'b10; // FSM 狀態或常數參數宣告
    always@(posedge clk or  posedge rst)begin
        if(rst)begin
            cs <= IDLE;
        end else begin
            cs <= ns;
        end
    end
    always@(*)begin
        case(cs)
            IDLE:begin
                if(valid) ns = PROCESS;
                else ns = IDLE;
            end
            PROCESS:begin
                if(proc_done) ns = DONE;
                else ns = PROCESS;
            end
            DONE:begin
                ns = DONE;
            end
            default: ns = IDLE;
        endcase
    end
    reg process_start,process_start_d; // 循序邏輯暫存器宣告
    always@(posedge clk or posedge rst)begin
        if(rst)begin
            process_start_d <= 1'b0;
        end else begin
            process_start_d <= process_start;
        end
    end
    always@(posedge clk or posedge rst)begin
        if(rst)begin
            counter <= 8'd0;
            Img_CEN <= 1'b0;
            Img_A <= 16'd0;
            process_start <= 1'b0;
            polarity <= 1'b0;
            proc_done <= 1'b0;
        end else begin
            case(cs)
                IDLE:begin
                    counter <= 8'd0;
                    Img_CEN <= 1'b1;
                    Img_A <= 16'd0;
                    process_start <= 1'b0;
                    polarity <= 1'b0;
                    proc_done <= 1'b0;
                    done <= 1'b0;
                end
                PROCESS:begin
                    process_start <= 1'b1;
                    if(process_start_d)begin
                        if((Img_Q >= threshold) && (counter < 8'd255)) counter <= counter + 8'd1;
                    end
                    if(!Img_A[8])begin
                        Img_CEN <= 1'b0;
                        Img_A <= Img_A + 16'd1;
                    end else begin
                        proc_done <= 1'b1;
                    end
                end
                DONE:begin
                    if(counter >= 8'd128) polarity <= 1'b0;
                    else polarity <= 1'b1;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule
// ============================================================================
// Stage module: ccl_v21_fast
// Function
//   Read the binary foreground decision from UrSRAM, assign provisional labels,
//   record label equivalences, flatten the equivalence table, and write the
//   resolved labels to AnsSRAM.
// ============================================================================
(* keep_hierarchy = "yes" *)
module ccl_v21_fast(
    input clk, // 系統時脈輸入
    input rst, // 同步或非同步重置信號
    input [7:0] threshold, // Otsu 計算後的 8-bit threshold
    input labeler_en, // One-cycle start pulse for CCL stage
    input polarity, // top/module 介面訊號宣告
    // ImgRom (Read)
    output reg img_cen, // Active-low ImgROM/UrSRAM read enable
    output reg [15:0] img_addr, // top/module 介面訊號宣告
    output  img_wen, // top/module 介面訊號宣告
    input [31:0] img_Q, // top/module 介面訊號宣告
    // AnsSRAM (Read & Write)
    output reg ans_cen, // Active-low AnsSRAM chip enable
    output reg ans_wen, // AnsSRAM write enable, active low
    output reg [15:0] ans_addr, // top/module 介面訊號宣告
    output reg [31:0] ans_D, // top/module 介面訊號宣告
    input [31:0] ans_Q, // top/module 介面訊號宣告
    output reg labeler_done, // top/module 介面訊號宣告
    output [9:0] total_label // top/module 介面訊號宣告
);
reg [9:0] consecutive_label; // 循序邏輯暫存器宣告
assign total_label = consecutive_label - 10'd1;
assign img_wen = 1'b1;
// 0: amount less than thres is foreground
// 1: amount more than thres is foreground
reg pol; // 循序邏輯暫存器宣告
// polarity
always@(posedge clk or posedge rst)begin
    if(rst)begin
        pol<= 1'b0;
    end else if(labeler_en)begin
        pol <= polarity;
    end
end
wire [31:0] bin_img_Q_light,bin_img_Q_dark,bin_img_Q; // 資料寫入或中間資料匯流排信號
assign bin_img_Q_light = (img_Q[7:0] <= threshold)? 32'd1: 32'd0;
assign bin_img_Q_dark = (img_Q[7:0] > threshold)? 32'd1: 32'd0;
assign bin_img_Q = (pol)? bin_img_Q_dark:bin_img_Q_light;
reg [2:0] state, next_state; // 目前 top FSM 狀態
localparam IDLE = 3'b000; // FSM 狀態或常數參數宣告
localparam READ_PASS_1 = 3'b001; // FSM 狀態或常數參數宣告
localparam WRITE_PASS_1 = 3'b010; // FSM 狀態或常數參數宣告
localparam FLATTEN_TABLE = 3'b011; // FSM 狀態或常數參數宣告
localparam READ_PASS_2 = 3'b100; // FSM 狀態或常數參數宣告
localparam WRITE_PASS_2 = 3'b101; // FSM 狀態或常數參數宣告
localparam DONE = 3'b110; // FSM 狀態或常數參數宣告
always@(posedge clk or posedge rst)begin
    if(rst)begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end
reg buffer_done; // 循序邏輯暫存器宣告
reg READ_PASS_1_done; // 循序邏輯暫存器宣告
reg flatten_done; // 循序邏輯暫存器宣告
wire WRITE_PASS_1_read, WRITE_PASS_1_finish; // 組合邏輯連接信號宣告
reg write_pass_2_finish; // 循序邏輯暫存器宣告
reg write_pass_2_done; // 循序邏輯暫存器宣告
reg read_pass_2_done,read_pass_2_done_d; // 循序邏輯暫存器宣告
always@(*)begin
    case(state)
        IDLE:begin
            if(labeler_en) next_state = READ_PASS_1;
            else next_state = IDLE;
        end
        READ_PASS_1:begin
            if(READ_PASS_1_done) next_state = WRITE_PASS_1;
            else next_state = READ_PASS_1;
        end
        WRITE_PASS_1:begin
            if(WRITE_PASS_1_finish) next_state = FLATTEN_TABLE;
            else if(WRITE_PASS_1_read) next_state = READ_PASS_1;
            else next_state = WRITE_PASS_1;
        end
        FLATTEN_TABLE:begin
            if(flatten_done) next_state = READ_PASS_2;
            else next_state = FLATTEN_TABLE;
        end
        READ_PASS_2:begin
            next_state = WRITE_PASS_2;
        end
        WRITE_PASS_2:begin
            if(write_pass_2_finish) next_state = DONE;
            else if(write_pass_2_done) next_state = READ_PASS_2;
            else next_state = WRITE_PASS_2;
        end
        DONE:begin
            next_state = DONE;
        end
        default: next_state = IDLE;
    endcase
end
reg write_done,write_finish; // 循序邏輯暫存器宣告
reg img_cen_d; // 循序邏輯暫存器宣告
reg img_cen_dd; // 循序邏輯暫存器宣告
reg write_done_d; // 循序邏輯暫存器宣告
always@(posedge clk or posedge rst)begin
    if(rst)begin
        write_done_d <= 1'b0;
        img_cen_d <= 1'b0;
img_cen_dd <= 1'b0;
        read_pass_2_done_d <= 1'b0;
    end else begin
        write_done_d <= write_done;
        img_cen_d <= img_cen;
img_cen_dd <= img_cen_d;
        read_pass_2_done_d <= read_pass_2_done;
    end
end
reg [9:0] line_buffer [511:0]; // 循序邏輯暫存器宣告
reg [7:0] buffer_count; // 循序邏輯暫存器宣告
reg [9:0] new_label; // 循序邏輯暫存器宣告
reg [15:0] pixel_idx_write; // 循序邏輯暫存器宣告
integer i; // for-loop 或計數用途的整數變數宣告
integer j; // for-loop 或計數用途的整數變數宣告
integer k; // for-loop 或計數用途的整數變數宣告
reg [9:0] label_buffer[255:0]; // 循序邏輯暫存器宣告
wire [9:0] neighbor_W = (buffer_count == 8'd0) ? 10'd0 : label_buffer[buffer_count - 8'd1]; // 組合邏輯連接信號宣告
// Optional debug reference for west-neighbor lookup.
wire [9:0] neighbor_NW = (buffer_count == 8'd0)   ? 10'd0 : line_buffer[{1'b0, buffer_count - 8'd1}]; // 組合邏輯連接信號宣告
wire [9:0] neighbor_N  =                                   line_buffer[{1'b0, buffer_count}]; // 組合邏輯連接信號宣告
wire [9:0] neighbor_NE = (buffer_count == 8'd255) ? 10'd0 : line_buffer[{1'b0, buffer_count + 8'd1}]; // 組合邏輯連接信號宣告
wire [9:0] min_NW_N = (neighbor_NW == 0) ? neighbor_N : // 組合邏輯連接信號宣告
                      (neighbor_N == 0)  ? neighbor_NW :
                      (neighbor_NW < neighbor_N) ? neighbor_NW : neighbor_N;
wire [9:0] min_NE_W = (neighbor_NE == 0) ? neighbor_W : // 組合邏輯連接信號宣告
                      (neighbor_W == 0)  ? neighbor_NE :
                      (neighbor_NE < neighbor_W) ? neighbor_NE : neighbor_W;
wire [9:0] min_neighbor = (min_NW_N == 0) ? min_NE_W : // 組合邏輯連接信號宣告
                          (min_NE_W == 0) ? min_NW_N :
                          (min_NW_N < min_NE_W) ? min_NW_N : min_NE_W;
reg [9:0] eq_table [1023:0]; // 循序邏輯暫存器宣告
reg [9:0] flatten_idx; // 循序邏輯暫存器宣告
//assign WRITE_PASS_1_read = (pixel_idx_write[7:0] == 8'd255 && state == WRITE_PASS_1_read)? 1'b1 : 1'b0;
assign WRITE_PASS_1_read = (write_done)? 1'b1 : 1'b0;
assign WRITE_PASS_1_finish = (write_finish)? 1'b1 : 1'b0;
reg [15:0] pass2_addr; // 位址暫存器宣告
reg [15:0] read_1_pixel; // 循序邏輯暫存器宣告
reg [7:0] buffer_count_read; // 循序邏輯暫存器宣告
always@(posedge clk or posedge rst)begin
    if(rst)begin
        for(i = 0;i<512;i = i+1)begin
            line_buffer[i] <= 10'd0;
        end
        for(j = 0; j<1024; j = j+1)begin
            eq_table[j] <= 0;
        end
        img_cen <= 1'b0;
        img_addr <= 16'b0;
        buffer_count <= 8'd0;
        new_label <= 10'd0;
        pixel_idx_write <= 16'd0;
        write_done <= 1'b0;
        write_finish <= 1'b0;
        flatten_idx <= 10'd0;
        ans_addr <= 16'd0;
        write_pass_2_done <= 1'b0;
        write_pass_2_finish <= 1'b0;
        consecutive_label <= 10'd0;
        ans_wen <= 1'b0;
        ans_cen <= 1'b0;
        ans_D <= 32'd0;
        labeler_done <= 1'b0;
        buffer_done <= 1'b0;
        flatten_done <= 1'b0;
        READ_PASS_1_done <= 1'b0;
        read_pass_2_done <= 1'b0;
        pass2_addr <= 16'd0;
read_1_pixel <= 16'd0;
buffer_count_read <= 8'd0;
 for(k = 0; k<256; k = k+1)begin
                    label_buffer[k] <= 10'd0;
                end
    end else begin
        case(state)
            IDLE:begin
                for(i = 0;i<512;i = i+1)begin
                    line_buffer[i] <= 10'd0;
                end
                for(j = 0; j<1024; j = j+1)begin
                    eq_table[j] <= j;
                end
                for(k = 0; k<256; k = k+1)begin
                    label_buffer[k] <= 10'd0;
                end
                img_cen <= 1'b1;
                img_addr <= 16'd0;
                new_label <= 10'd1;
                buffer_count <= 8'd0;
                pixel_idx_write <= 16'd0;
                write_done <= 1'b0;
                write_finish <= 1'b0;
                flatten_idx <= 10'd1;
                ans_addr <= 16'd0;
                write_pass_2_done <= 1'b0;
                write_pass_2_finish <= 1'b0;
                consecutive_label <= 10'd1;
                ans_wen <= 1'b1;
                ans_cen <= 1'b1;
                ans_D <= 32'd0;
                labeler_done <= 1'b0;
                buffer_done <= 1'b0;
                flatten_done <= 1'b0;
                READ_PASS_1_done <= 1'b0;
                read_pass_2_done <= 1'b0;
                pass2_addr <= 16'd0;
read_1_pixel <= 16'd0;
buffer_count_read <= 8'd0;
            end
            READ_PASS_1:begin
                if(write_done_d) begin
                    pixel_idx_write <= pixel_idx_write + 16'd1;
                    for(j = 0;j < 256; j = j+1)begin
                        line_buffer[j] <= label_buffer[j];
                        // Shift the row buffer after finishing one row.
                    end
                end else begin
                    img_cen <= 1'b0;
                    img_addr <= read_1_pixel;
                    if(read_1_pixel[7:0] < 8'd255)read_1_pixel <= read_1_pixel + 16'd1;
                    //if(img_addr[7:0] < 8'd255)img_addr <= img_addr + 16'd1;
                    // Read filtered gray value with SRAM latency alignment.
                    // The first row is initialized as background padding for neighbor lookup.
                    if(!img_cen_d)begin
                        if(buffer_count_read < 8'd255)begin
                            line_buffer[{1'b1,buffer_count_read}] <= bin_img_Q;
                            buffer_count_read <= buffer_count_read + 8'd1;
                            READ_PASS_1_done <= 1'b0;
                        end else begin
                            line_buffer[{1'b1,8'd255}] <= bin_img_Q;
                            READ_PASS_1_done <= 1'b1;
                            buffer_count <= 8'd0;
                        end
                    end
                end
            end
            WRITE_PASS_1:begin
                if(READ_PASS_1_done)begin
                    buffer_count_read <= 8'd0;
                    READ_PASS_1_done <= 1'b0;
                    img_cen <= 1'b1;
                end else begin
                    if(buffer_done)begin
                        buffer_count <= 8'd0;
                        ans_wen <= 1'b0;
                        ans_cen <= 1'b0;
                        ans_addr <= pixel_idx_write;
                        ans_D <= {22'd0, label_buffer[pixel_idx_write[7:0]]};
                        // Optional debug write of the current line-buffer label.
                        if(pixel_idx_write[7:0] < 8'd255)begin
                            pixel_idx_write <= pixel_idx_write + 16'd1;
                        end else begin
                            write_done <= 1'b1;
                            buffer_done <= 1'b0;
                            read_1_pixel <= read_1_pixel + 16'd1;
                            //buffer_count <= 8'd0;
                        end
                        if(ans_addr == 16'd65535)begin
                            write_finish<= 1'b1;
                            ans_wen <= 1'b1;
                        end
                    end else if (write_done) begin
                        // Guard cycle between write and read phases.
                        // No label-equivalence update is performed here; this protects
                        // the equivalence table from a stale pipeline value.
                        write_done <= 1'b0;
                    end else if (!write_finish) begin
                        ans_wen <= 1'b1;
                        ans_cen <= 1'b1;
                        write_done <= 1'b0;
                        // No connected labeled neighbor: allocate a new provisional label
                        if(line_buffer[{1'b1,buffer_count}])begin
                            if(!neighbor_N && !neighbor_NE && !neighbor_NW && !neighbor_W)begin
                                label_buffer[buffer_count] <= new_label;
                                //line_buffer[buffer_count] <= new_label; // -------------
                                //line_buffer[{1'b1,buffer_count}] <= new_label;
                                new_label <= new_label + 10'd1;
                            // At least one labeled neighbor exists: use the minimum label and record equivalences
                            end else begin
                                //line_buffer[{1'b1, buffer_count}] <= min_neighbor;
                                label_buffer[buffer_count] <= min_neighbor;
                                //line_buffer[buffer_count] <= min_neighbor; // ---------------------
                                /*if (neighbor_W  != 0 && neighbor_W  != min_neighbor) eq_table[neighbor_W]  <= min_neighbor;
                                if (neighbor_NW != 0 && neighbor_NW != min_neighbor) eq_table[neighbor_NW] <= min_neighbor;
                                if (neighbor_N  != 0 && neighbor_N  != min_neighbor) eq_table[neighbor_N]  <= min_neighbor;
                                if (neighbor_NE != 0 && neighbor_NE != min_neighbor) eq_table[neighbor_NE] <= min_neighbor;*/
                                // Union heuristic: attach non-root labels to the selected root label
                                if (neighbor_W  != 0 && neighbor_W  != min_neighbor) eq_table[eq_table[neighbor_W]]  <= min_neighbor;
                                if (neighbor_NW != 0 && neighbor_NW != min_neighbor) eq_table[eq_table[neighbor_NW]] <= min_neighbor;
                                if (neighbor_N  != 0 && neighbor_N  != min_neighbor) eq_table[eq_table[neighbor_N]]  <= min_neighbor;
                                if (neighbor_NE != 0 && neighbor_NE != min_neighbor) eq_table[eq_table[neighbor_NE]] <= min_neighbor;
                            end
                        end else begin
                            //line_buffer[buffer_count] <= 10'd0; // ------------------------
                            label_buffer[buffer_count] <= 10'd0;
                        end
                        if(buffer_count < 8'd255)begin
                            //buffer_done <= 1'b0;
                            buffer_count <= buffer_count + 8'd1;
                        end else begin
                            buffer_done <= 1'b1;
                        end
                    end
                end
            end
            FLATTEN_TABLE:begin
            ans_cen <= 1'b1;
            ans_wen <= 1'b1;
                img_addr <= 16'd0;
                if(flatten_idx < new_label)begin
                    // Case A: current label is already a root
                    if (eq_table[flatten_idx] == flatten_idx) begin
                        eq_table[flatten_idx] <= consecutive_label;
                        consecutive_label <= consecutive_label + 16'd1;
                    // Case B: current label points to an earlier parent
                    end else begin
                        eq_table[flatten_idx] <= eq_table[eq_table[flatten_idx]];
                    end
                    flatten_idx <= flatten_idx + 10'd1;
                end else begin
                    flatten_done <= 1'b1;
                end
                ans_addr <= 16'd0;
            end
            READ_PASS_2:begin
                ans_cen <= 1'b0;
                ans_wen <= 1'b1;
                ans_addr <= pass2_addr;
                write_pass_2_done <= 1'b0;
                read_pass_2_done <= 1'b1;
            end
            WRITE_PASS_2:begin
                read_pass_2_done <= 1'b0;
                if(read_pass_2_done_d)begin
                    if(pass2_addr == 16'd65535)begin
                        ans_wen <= 1'b0;
                        ans_cen <= 1'b0;
                        ans_D <= {16'd0, eq_table[ans_Q[15:0]]};
                        write_pass_2_finish <= 1'b1;
                    end else begin
                        ans_wen <= 1'b0;
                        ans_cen <= 1'b0;
                        pass2_addr <= pass2_addr + 16'd1;
                        ans_D <= {16'd0, eq_table[ans_Q[15:0]]};
                        write_pass_2_done <= 1'b1;
                    end
                end
            end
            DONE:begin
                ans_cen <= 1'b1;
                ans_wen <= 1'b1;
                labeler_done<= 1'b1;
            end
        endcase
    end
end
endmodule
// ============================================================================
// Stage module: boxing_v21_fast
// Function
//   Scan the resolved labels in AnsSRAM, compute xmin/xmax/ymin/ymax for each
//   connected component, copy the original RGB image into AnsSRAM, then draw a
//   one-pixel green bounding box around every valid non-border component.
// ============================================================================
(* keep_hierarchy = "yes" *)
module boxing_v21_fast(
    input      clk, // 系統時脈輸入
    input      rst, // 同步或非同步重置信號
    input      enable, // 啟動整體影像處理流程
    output reg    done, // 輸出完成旗標
    input [9:0] total_label, // top/module 介面訊號宣告
    // ImgROM
    input      [31:0] Img_Q, // ImgROM 讀回的 32-bit RGB pixel
    output reg           Img_CEN, // ImgROM 低有效 chip enable
    output reg [15:0] Img_A, // ImgROM 讀取位址
    // AnsSRAM
    input      [31:0] Ans_Q, // AnsSRAM 讀回資料
    output reg           Ans_CEN, // AnsSRAM 低有效 chip enable
    output reg           Ans_WEN, // AnsSRAM 讀寫控制，0 為寫入、1 為讀取
    output reg    [31:0] Ans_D, // AnsSRAM 寫入資料
    output reg    [15:0] Ans_A // AnsSRAM 存取位址
);
reg [15:0] pixel; // 循序邏輯暫存器宣告
reg [7:0] min_x[364:0]; // 循序邏輯暫存器宣告
reg [7:0] max_x[364:0]; // 循序邏輯暫存器宣告
reg [7:0] min_y[364:0]; // 循序邏輯暫存器宣告
reg [7:0] max_y[364:0]; // 循序邏輯暫存器宣告
reg scan_done; // 循序邏輯暫存器宣告
reg copy_done,copy_done_d; // 循序邏輯暫存器宣告
reg [8:0] box_count; // 循序邏輯暫存器宣告
reg [2:0] state, next_state; // 目前 top FSM 狀態
localparam IDLE = 3'd0; // FSM 狀態或常數參數宣告
localparam SCAN = 3'd1; // FSM 狀態或常數參數宣告
localparam COPY = 3'd2; // FSM 狀態或常數參數宣告
localparam BOXING = 3'd3; // FSM 狀態或常數參數宣告
localparam DONE = 3'd4; // FSM 狀態或常數參數宣告
// Final-pixel tail states keep the last ROM address, data, and write strobes
// stable long enough for the SRAM model to capture Ans[65535].
localparam COPY_LAST_READ  = 3'd5; // FSM 狀態或常數參數宣告
localparam COPY_LAST_WRITE = 3'd6; // FSM 狀態或常數參數宣告
localparam COPY_LAST_HOLD  = 3'd7; // FSM 狀態或常數參數宣告
reg Img_CEN_d; // 循序邏輯暫存器宣告
reg Ans_CEN_d; // 循序邏輯暫存器宣告
reg [7:0] cur_x ; // 循序邏輯暫存器宣告
reg [7:0] cur_y ; // 循序邏輯暫存器宣告
always@(posedge clk or posedge rst)begin
    if(rst)begin
        Img_CEN_d <= 1'b0;
        Ans_CEN_d <= 1'b0;
    end else begin
        Img_CEN_d <= Img_CEN;
        Ans_CEN_d <= Ans_CEN;
    end
end
reg [2:0] box_state,box_next_state; // FSM 狀態暫存器宣告
localparam BOX_IDLE = 3'd0; // FSM 狀態或常數參數宣告
localparam BOX_INITIAL = 3'd1; // FSM 狀態或常數參數宣告
localparam BOX_WRITE_1 = 3'd2; // FSM 狀態或常數參數宣告
localparam BOX_WRITE_2 = 3'd3; // FSM 狀態或常數參數宣告
localparam BOX_WRITE_3 = 3'd4; // FSM 狀態或常數參數宣告
localparam BOX_WRITE_4 = 3'd5; // FSM 狀態或常數參數宣告
localparam BOX_DONE = 3'd6; // FSM 狀態或常數參數宣告
reg [7:0] pixel_x, pixel_y; // 循序邏輯暫存器宣告
reg box_write_1_done,box_write_3_done,box_write_4_done; // 循序邏輯暫存器宣告
reg boxing_done; // 循序邏輯暫存器宣告
reg [15:0] read_pixel; // 循序邏輯暫存器宣告
integer i; // for-loop 或計數用途的整數變數宣告
integer j; // for-loop 或計數用途的整數變數宣告
always@(posedge clk or posedge rst)begin
    if(rst)begin
        Img_CEN <= 1'b0;
        Img_A <= 16'd0;
        Ans_CEN <= 1'b0;
        Ans_WEN <= 1'b0;
        Ans_D <= 32'd0;
        Ans_A <= 16'd0;
        pixel <= 16'd0;
        for(i = 0; i < 365; i = i+1)begin
            min_x[i] <= 8'd0;
            max_x[i] <= 8'd0;
            min_y[i] <= 8'd0;
            max_y[i] <= 8'd0;
        end
        cur_x <= 8'd0;
        cur_y <= 8'd0;
        scan_done <= 1'b0;
        copy_done <= 1'b0;
        copy_done_d <= 1'b0;
        box_count <= 10'd0;
        pixel_x <= 8'd0;
        pixel_y <= 8'd0;
        box_write_1_done <= 1'b0;
        //box_write_2_done <= 1'b0;
        box_write_3_done <= 1'b0;
        box_write_4_done <= 1'b0;
        done <= 1'b0;
        boxing_done <= 1'b0;
        read_pixel <= 16'd0;
    end else begin
        case(state)
            IDLE:begin
                Img_CEN <= 1'b1;
                Img_A <= 16'd0;
                Ans_CEN <= 1'b1;
                Ans_WEN <= 1'b1;
                Ans_D <= 32'd0;
                Ans_A <= 16'd0;
                pixel <= 16'd0;
                for(j = 0; j < 365; j = j+1)begin
                    min_x[j] <= 8'd255;
                    max_x[j] <= 8'd0;
                    min_y[j] <= 8'd255;
                    max_y[j] <= 8'd0;
                end
                scan_done <= 1'b0;
                copy_done <= 1'b0;
                copy_done_d <= 1'b0;
                box_count <= 10'd1;
                pixel_x <= 8'd0;
                pixel_y <= 8'd0;
                box_write_1_done <= 1'b0;
                //box_write_2_done <= 1'b0;
                box_write_3_done <= 1'b0;
                box_write_4_done <= 1'b0;
                done <= 1'b0;
                boxing_done <= 1'b0;
                read_pixel <= 16'd0;
                cur_x <= 8'd0;
        cur_y <= 8'd0;
            end
            SCAN:begin
                // Read resolved label image from AnsSRAM
                Ans_CEN <= 1'b0;
                Ans_A <= read_pixel;
                if(read_pixel < 16'd65535)begin
                    read_pixel <= read_pixel + 16'd1;
                end
                if(!Ans_CEN_d)begin
                    // Compare the current pixel coordinate against the stored bounding box range
                    if(Ans_Q != 32'd0)begin
                        if(cur_x > max_x[Ans_Q[8:0]]) max_x[Ans_Q[8:0]] <= cur_x;
                        if(cur_x < min_x[Ans_Q[8:0]]) min_x[Ans_Q[8:0]] <= cur_x;
                        if(cur_y > max_y[Ans_Q[8:0]]) max_y[Ans_Q[8:0]] <= cur_y;
                        if(cur_y < min_y[Ans_Q[8:0]]) min_y[Ans_Q[8:0]] <= cur_y;
                    end
                    // Advance the scan address and 2D coordinate counters
                    if(pixel == 16'd65535)begin
                        scan_done <= 1'b1;
                        Ans_CEN <= 1'b1;
                        Ans_A <= 16'd0;
                        pixel <= 16'd0;
                        read_pixel <= 16'd0;
                        cur_x <= 8'd0; // Reset X after scan is complete
                        cur_y <= 8'd0; // Reset Y after scan is complete
                    end else begin
                        pixel <= pixel + 16'd1;
                        // Row-major 2D coordinate update
                        if(cur_x == 8'd255) begin
                            cur_x <= 8'd0;         // End of row: reset X
                            cur_y <= cur_y + 8'd1; // End of row: advance Y
                        end else begin
                            cur_x <= cur_x + 8'd1; // Same row: advance X
                        end
                    end
                end
            end
            COPY:begin
                // Copy original RGB image from ImgROM to AnsSRAM before drawing boxes.
                // Pixels 0..65534 are handled by the normal streaming path.
                // Pixel 65535 is handled by explicit tail states so that the
                // memory model observes a complete and stable final write cycle.
                Img_CEN <= 1'b0;
                Img_A   <= read_pixel;
                if(read_pixel < 16'd65535)begin
                    read_pixel <= read_pixel + 16'd1;
                end
                if(!Img_CEN_d)begin
                    if(pixel < 16'd65535)begin
                        Ans_CEN <= 1'b0;
                        Ans_WEN <= 1'b0;
                        Ans_A   <= pixel;
                        Ans_D   <= Img_Q;
                        pixel   <= pixel + 16'd1;
                    end else begin
                        // Stop the normal stream at the last address and let the COPY_LAST_*
                        // states perform a clean final read/write handshake.
                        Ans_CEN <= 1'b1;
                        Ans_WEN <= 1'b1;
                        Ans_A   <= 16'd65535;
                        Img_CEN <= 1'b0;
                        Img_A   <= 16'd65535;
                    end
                end
            end
            COPY_LAST_READ:begin
                // Present final ROM address for one complete cycle.
                Img_CEN <= 1'b0;
                Img_A   <= 16'd65535;
                Ans_CEN <= 1'b1;
                Ans_WEN <= 1'b1;
                Ans_A   <= 16'd65535;
            end
            COPY_LAST_WRITE:begin
                // Set up the final AnsSRAM write using the stable Img_Q value.
                Img_CEN <= 1'b0;
                Img_A   <= 16'd65535;
                Ans_CEN <= 1'b0;
                Ans_WEN <= 1'b0;
                Ans_A   <= 16'd65535;
                Ans_D   <= Img_Q;
            end
            COPY_LAST_HOLD:begin
                // Hold final write signals for one more clock so the SRAM model can
                // capture address 65535 before the BOXING state disables the bus.
                Img_CEN <= 1'b1;
                Img_A   <= 16'd65535;
                Ans_CEN <= 1'b0;
                Ans_WEN <= 1'b0;
                Ans_A   <= 16'd65535;
                Ans_D   <= Img_Q;
                copy_done <= 1'b1;
                pixel <= 16'd0;
                read_pixel <= 16'd0;
            end
            BOXING:begin
                if(box_count <= total_label)begin
                    // Draw the selected component bounding box
                    case(box_state)
                        BOX_IDLE:begin
                            pixel_x <= 8'd0;
                            pixel_y <= 8'd0;
                            Ans_CEN <= 1'b1;
                            Ans_WEN <= 1'b1;
                            Ans_A <= 16'd0;
                            box_write_1_done <= 1'b0;
                            //box_write_2_done <= 1'b0;
                            box_write_3_done <= 1'b0;
                            box_write_4_done <= 1'b0;
                        end
                        BOX_INITIAL:begin
                            pixel_x <= min_x[box_count];
                            pixel_y <= min_y[box_count];
                        end
                        // Draw top horizontal edge
                        BOX_WRITE_1:begin
                            Ans_CEN <= 1'b0;
                            Ans_WEN <= 1'b0;
                            Ans_A <= {pixel_y,pixel_x};
                            Ans_D <= 32'h0000_FF00;
                            if(pixel_x < max_x[box_count])begin
                                pixel_x <= pixel_x + 8'd1;
                            end else begin
                                box_write_1_done <= 1'b1;
                                pixel_x <= min_x[box_count];
                                pixel_y <= max_y[box_count];
                            end
                        end
                        // Draw bottom horizontal edge
                        BOX_WRITE_2:begin
                            Ans_A <= {pixel_y,pixel_x};
                            Ans_D <= 32'h0000_FF00;
                            if(pixel_x < max_x[box_count])begin
                                pixel_x <= pixel_x + 8'd1;
                            end else begin
                                //box_write_2_done <= 1'b1;
                                pixel_x <= min_x[box_count];
                                pixel_y <= min_y[box_count] + 8'd1;
                            end
                        end
                        // Draw left vertical edge
                        BOX_WRITE_3:begin
                            Ans_A <= {pixel_y,pixel_x};
                            Ans_D <= 32'h0000_FF00;
                            if(pixel_y < (max_y[box_count] - 8'd1))begin
                                pixel_y <= pixel_y + 8'd1;
                            end else begin
                                box_write_3_done <= 1'b1;
                                pixel_x <= max_x[box_count];
                                pixel_y <= min_y[box_count] + 8'd1;
                            end
                        end
                        // Draw right vertical edge
                        BOX_WRITE_4:begin
                            Ans_A <= {pixel_y,pixel_x};
                            Ans_D <= 32'h0000_FF00;
                            if(pixel_y < (max_y[box_count] - 8'd1))begin
                                pixel_y <= pixel_y + 8'd1;
                            end else begin
                                box_write_4_done <= 1'b1;
                            end
                        end
                        BOX_DONE:begin
                            Ans_CEN <= 1'b1;
                            Ans_WEN <= 1'b1;
                            Ans_A <= 16'd0;
                            box_count <= box_count + 10'd1;
                        end
                    endcase
                end else begin
                    boxing_done <= 1'b1;
                end
            end
            DONE:begin
                done <= 1'b1;
            end
        endcase
    end
end
always@(posedge clk or posedge rst)begin
    if(rst)begin
        copy_done_d <= 1'b0;
    end else begin
        copy_done_d <= copy_done;
    end
end
always@(posedge clk or posedge rst)begin
    if(rst)begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end
always@(posedge clk or posedge rst)begin
    if(rst)begin
        box_state <= BOX_IDLE;
    end else begin
        box_state <= box_next_state;
    end
end
always@(*)begin
    case(box_state)
        BOX_IDLE:begin
            // Two safety conditions before drawing:
            // 1. Main FSM must be in BOXING so no early overlay write occurs.
            // 2. min <= max must hold, meaning this label belongs to a real object.
            if(state == BOXING) begin
                if(min_x[box_count] <= max_x[box_count] &&
                   min_y[box_count] <= max_y[box_count] &&
                   min_x[box_count] > 8'd0 &&
                   min_y[box_count] > 8'd0 &&
                   max_x[box_count] < 8'd255 &&
                   max_y[box_count] < 8'd255 &&
                   ((max_x[box_count] - min_x[box_count]) >10)&&
                   ((max_y[box_count] - min_y[box_count]) >10))  begin
                    box_next_state = BOX_INITIAL;
                end else begin
                    box_next_state = BOX_DONE; // Skip border objects and empty labels
                end
            end else begin
                box_next_state = BOX_IDLE; // Wait until the main boxing stage is active
            end
        end
        BOX_INITIAL:begin
            box_next_state = BOX_WRITE_1;
        end
        BOX_WRITE_1:begin
            if(box_write_1_done)box_next_state = BOX_WRITE_2;
            else box_next_state = BOX_WRITE_1;
        end
        /*BOX_WRITE_2:begin
            if(box_write_2_done)box_next_state = BOX_WRITE_3;
            else box_next_state = BOX_WRITE_2;
        end*/
BOX_WRITE_2:begin
            if(pixel_x == max_x[box_count]) box_next_state = BOX_WRITE_3;
            else box_next_state = BOX_WRITE_2;
        end
        BOX_WRITE_3:begin
            if(box_write_3_done)box_next_state = BOX_WRITE_4;
            else box_next_state = BOX_WRITE_3;
        end
        BOX_WRITE_4:begin
            if(box_write_4_done)box_next_state = BOX_DONE;
            else box_next_state = BOX_WRITE_4;
        end
        BOX_DONE:begin
            box_next_state = BOX_IDLE;
        end
        default:begin
            box_next_state = BOX_IDLE; // Default transition prevents latch inference
        end
    endcase
end
always@(*)begin
    case(state)
        IDLE:begin
            if(enable) next_state = SCAN;
            else next_state = IDLE;
        end
        SCAN:begin
            if(pixel == 16'd65535) next_state = COPY;
            else next_state = SCAN;
        end
        COPY:begin
            if(pixel == 16'd65535) next_state = COPY_LAST_READ;
            else next_state = COPY;
        end
        COPY_LAST_READ:begin
            next_state = COPY_LAST_WRITE;
        end
        COPY_LAST_WRITE:begin
            next_state = COPY_LAST_HOLD;
        end
        COPY_LAST_HOLD:begin
            next_state = BOXING;
        end
        BOXING:begin
            if(boxing_done) next_state = DONE;
            else next_state = BOXING;
        end
        DONE:begin
            next_state = IDLE;
        end
    endcase
end
endmodule
