`timescale 1ns/1ps
// [L001 中文說明] 設定 Verilog 模擬時間單位與精度。

// [L002 中文說明] 空白行，用來分隔段落，提升可讀性。
// ============================================================
// [L003 中文說明] 原始註解，用來說明此段設計目的或注意事項。
// Module Name : drawBbox
// [L004 中文說明] 原始註解，用來說明此段設計目的或注意事項。
// 
// [L005 中文說明] 原始註解，用來說明此段設計目的或注意事項。
// ============================================================
// [L006 中文說明] 原始註解，用來說明此段設計目的或注意事項。

// [L007 中文說明] 空白行，用來分隔段落，提升可讀性。
module drawBbox (
// [L008 中文說明] 宣告 drawBbox top module，這是整個 Lab7 RTL 的入口。
    input              clk,
    // [L009 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
    input              rst,
    // [L010 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
    input              enable,
    // [L011 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
    output             done,
    // [L012 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。

// [L013 中文說明] 空白行，用來分隔段落，提升可讀性。
    input      [31:0]  Img_Q,
    // [L014 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
    output reg         Img_CEN,
    // [L015 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。
    output reg [15:0]  Img_A,
    // [L016 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。

// [L017 中文說明] 空白行，用來分隔段落，提升可讀性。
    input      [31:0]  Ur_Q,
    // [L018 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
    output reg         Ur_CEN,
    // [L019 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。
    output reg         Ur_WEN,
    // [L020 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。
    output reg [31:0]  Ur_D,
    // [L021 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。
    output reg [15:0]  Ur_A,
    // [L022 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。

// [L023 中文說明] 空白行，用來分隔段落，提升可讀性。
    input      [31:0]  Ans_Q,
    // [L024 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
    output reg         Ans_CEN,
    // [L025 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。
    output reg         Ans_WEN,
    // [L026 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。
    output reg [31:0]  Ans_D,
    // [L027 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。
    output reg [15:0]  Ans_A
    // [L028 中文說明] 宣告輸出埠，提供 done 或控制 ImgROM / SRAM 介面訊號。
);
// [L029 中文說明] 此行屬於 二、常數與 FSM State 定義，用來完成 drawBbox 的控制或資料路徑。

// [L030 中文說明] 空白行，用來分隔段落，提升可讀性。
    localparam [31:0] GREEN       = 32'h0000_FF00;
    // [L031 中文說明] 宣告 GREEN 常數，最後畫框時會把對應 pixel 寫成綠色。
    localparam [16:0] NPIX        = 17'd65536;
    // [L032 中文說明] 宣告常數參數，供 FSM 或資料路徑共用。
    localparam [15:0] NPIX_LAST   = 16'hFFFF;
    // [L033 中文說明] 宣告常數參數，供 FSM 或資料路徑共用。
    localparam [9:0]  MAX_LABELS  = 10'd512;
    // [L034 中文說明] 宣告常數參數，供 FSM 或資料路徑共用。
    localparam [8:0]  MAX_LABEL_IDX = 9'd511;
    // [L035 中文說明] 宣告常數參數，供 FSM 或資料路徑共用。

// [L036 中文說明] 空白行，用來分隔段落，提升可讀性。
    localparam [5:0]
    // [L037 中文說明] 宣告常數參數，供 FSM 或資料路徑共用。
        S_IDLE         = 6'd0,
        // [L038 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_LOAD         = 6'd1,
        // [L039 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_GRAY         = 6'd2,
        // [L040 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_HIST_CLEAR   = 6'd3,
        // [L041 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_LB_INIT      = 6'd4,   // 載入初始 line buffer（3 行）
        // [L042 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_LB_ROW       = 6'd5,   // 載入單一 row → linebuf_next
        // [L043 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_GAUSS_HIST   = 6'd6,
        // [L044 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_OTSU_INIT    = 6'd7,
        // [L045 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_OTSU_SCAN    = 6'd8,
        // [L046 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_COUNT_HI     = 6'd9,
        // [L047 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_POLARITY     = 6'd10,
        // [L048 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_MASK_WRITE   = 6'd11,
        // [L049 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_PARENT_INIT  = 6'd12,  // V16: clear parent/bbox arrays before CCL
        // [L050 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_LB_INIT2     = 6'd13,  // CCL 前重新載入 line buffer
        // [L051 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_CCL_SCAN     = 6'd14,
        // [L052 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_LB_ROW2      = 6'd15,  // CCL 跨列 line buffer 更新
        // [L053 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_BBOX_INIT    = 6'd16,
        // [L054 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_BBOX_SCAN    = 6'd17,
        // [L055 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_BOXMAP_CLEAR = 6'd18,
        // [L056 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_BOXMAP_GEN   = 6'd19,
        // [L057 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_DRAW_WRITE   = 6'd20,
        // [L058 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_DONE         = 6'd21,
        // [L059 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        // V19: split Otsu into multi-cycle states so DC sees one shared multiplier instead of many huge multipliers
        // [L060 中文說明] 原始註解，用來說明此段設計目的或注意事項。
        S_OTSU_LHS     = 6'd22,
        // [L061 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_OTSU_DENOM   = 6'd23,
        // [L062 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_OTSU_SQUARE  = 6'd24,
        // [L063 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_OTSU_CMP1    = 6'd25,
        // [L064 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。
        S_OTSU_CMP2    = 6'd26;
        // [L065 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 二、常數與 FSM State 定義。

// [L066 中文說明] 空白行，用來分隔段落，提升可讀性。
    reg [5:0] state;
    // [L067 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg done_r;
    // [L068 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    assign done = done_r;
    // [L069 中文說明] 把內部 done_r 連接到輸出 done。

// [L070 中文說明] 空白行，用來分隔段落，提升可讀性。
    wire [31:0] unused_zero = (Ans_Q ^ Ans_Q);
    // [L071 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L072 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L073 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // 3-Row Line Buffer（取代 gray_mem[65535:0]）
    // [L074 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L075 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // V21: 3-bank line buffer.
    // [L076 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // Instead of physically rotating 256 columns (prev<=curr, curr<=next),
    // [L077 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // we keep three physical banks and rotate only 2-bit selectors.
    // [L078 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // This preserves RTL alignment but is much easier for Design Compiler.
    // [L079 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    reg [7:0] linebuf_bank0 [0:255];
    // [L080 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0] linebuf_bank1 [0:255];
    // [L081 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0] linebuf_bank2 [0:255];
    // [L082 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [1:0] lb_prev_sel, lb_curr_sel, lb_next_sel;
    // [L083 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L084 中文說明] 空白行，用來分隔段落，提升可讀性。
    reg [31:0] hist [255:0];
    // [L085 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L086 中文說明] 空白行，用來分隔段落，提升可讀性。
    reg [8:0]  row_label    [0:255];
    // [L087 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [8:0]  left_label;
    // [L088 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [8:0]  nw_label_hold;
    // [L089 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [8:0]  cur_label_comb;
    // [L090 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L091 中文說明] 空白行，用來分隔段落，提升可讀性。
    reg [8:0]  parent      [MAX_LABELS-1:0];
    // [L092 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg        bbox_valid  [MAX_LABELS-1:0];
    // [L093 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg        bbox_border [MAX_LABELS-1:0];
    // [L094 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0]  bbox_xmin   [MAX_LABELS-1:0];
    // [L095 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0]  bbox_xmax   [MAX_LABELS-1:0];
    // [L096 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0]  bbox_ymin   [MAX_LABELS-1:0];
    // [L097 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0]  bbox_ymax   [MAX_LABELS-1:0];
    // [L098 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L099 中文說明] 空白行，用來分隔段落，提升可讀性。
    reg [15:0] addr_cnt;
    // [L100 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [16:0] req_cnt;
    // [L101 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [8:0]  next_label;
    // [L102 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [8:0]  label_idx;
    // [L103 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0]  edge_ctr;
    // [L104 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [1:0]  edge_stage;
    // [L105 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L106 中文說明] 空白行，用來分隔段落，提升可讀性。
    // Line buffer loader
    // [L107 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    reg [7:0]  lb_col;    // 目前載入的欄
    // [L108 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0]  lb_row;    // 要從 UrSRAM 讀的列（供 S_LB_ROW 用）
    // [L109 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [1:0]  lb_phase;  // 0=送addr, 1=等latency, 2=存資料
    // [L110 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [1:0]  lb_seq;    // S_LB_INIT 階段序號 (0=prev, 1=curr, 2=next)
    // [L111 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L112 中文說明] 空白行，用來分隔段落，提升可讀性。
    // lb_row_w：S_LB_INIT 階段根據 lb_seq 選擇要讀的 row
    // [L113 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // 用 wire 避免 nonblocking timing 問題
    // [L114 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    wire [7:0] lb_init_row = (lb_seq == 2'd1) ? 8'd0 : 8'd1;
    // [L115 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    //   seq=0: 讀 row1 (reflect of y=-1) → prev
    // [L116 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    //   seq=1: 讀 row0                   → curr
    // [L117 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    //   seq=2: 讀 row1                   → next
    // [L118 中文說明] 原始註解，用來說明此段設計目的或注意事項。

// [L119 中文說明] 空白行，用來分隔段落，提升可讀性。
    reg [7:0]  otsu_t;
    // [L120 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg        invert_sel;
    // [L121 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [16:0] count_hi;
    // [L122 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [31:0] wb_acc, sum_b_acc;
    // [L123 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0]  otsu_idx;
    // [L124 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [63:0] lhs48, rhs48;
    // [L125 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [64:0] diff48;
    // [L126 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [63:0] denom32;
    // [L127 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [31:0] sum_total, wb_next, sum_b_next, otsu_idx32;
    // [L128 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [129:0] square96, best_num;
    // [L129 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [63:0]  best_den;
    // [L130 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [193:0] cmp_lhs, cmp_rhs;
    // [L131 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L132 中文說明] 空白行，用來分隔段落，提升可讀性。
    // V19 synthesis-fast shared multiplier for Otsu.
    // [L133 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // The original V18 S_OTSU_SCAN described several large multipliers in one cycle
    // [L134 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // (32x32, 65x65, 130x64, 130x64). DC may spend a very long time optimizing them.
    // [L135 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // Here all Otsu products go through one 130x64 combinational multiplier across
    // [L136 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // several FSM states. RTL cycles increase by only ~5*256, but synthesis becomes much lighter.
    // [L137 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    reg  [129:0] otsu_mul_a;
    // [L138 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg  [63:0]  otsu_mul_b;
    // [L139 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    wire [193:0] otsu_mul_y = otsu_mul_a * otsu_mul_b;
    // [L140 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L141 中文說明] 空白行，用來分隔段落，提升可讀性。
    reg [7:0]  ccl_x, ccl_y, ccl_base;
    // [L142 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg        ccl_fg;
    // [L143 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [8:0]  ccl_n_w, ccl_n_nw, ccl_n_n, ccl_n_ne;
    // [L144 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [8:0]  ccl_chosen_label;
    // [L145 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg        ccl_new_label;
    // [L146 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [8:0]  root_label;
    // [L147 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0]  draw_ymax;
    // [L148 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L149 中文說明] 空白行，用來分隔段落，提升可讀性。
    reg [31:0] first_pixel;
    // [L150 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [1:0]  special_box_idx;
    // [L151 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
    reg [7:0]  x_i, y_i, base_i;
    // [L152 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。

// [L153 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L154 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // function: refl101
    // [L155 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L156 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    function [7:0] refl101;
    // [L157 中文說明] 開始定義函式 refl101，用來封裝可重複使用的組合邏輯。
        input signed [31:0] v;
        // [L158 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        reg signed [31:0] t;
        // [L159 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        reg [31:0] tu;
        // [L160 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        begin
        // [L161 中文說明] begin 區塊開始，表示接下來有多行程式屬於同一控制區塊。
            t = 32'sd0; tu = 32'd0;
            // [L162 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            if (v < 32'sd0)        t = -v;
            // [L163 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
            else if (v > 32'sd255) t = 32'sd510 - v;
            // [L164 中文說明] 補充條件分支，處理 四、輔助函式與 Task 的其他情況。
            else                   t = v;
            // [L165 中文說明] 補充條件分支，處理 四、輔助函式與 Task 的其他情況。
            tu = $unsigned(t);
            // [L166 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            refl101 = tu[7:0];
            // [L167 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
        end
        // [L168 中文說明] 結束目前 begin-end 區塊。
    endfunction
    // [L169 中文說明] 結束函式 refl101。

// [L170 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L171 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // function: gray_round_rgb
    // [L172 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L173 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    function [7:0] gray_round_rgb;
    // [L174 中文說明] 開始定義函式 gray_round_rgb，用來封裝可重複使用的組合邏輯。
        input [31:0] pix;
        // [L175 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        reg [17:0] gs;
        // [L176 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        reg [9:0]  gq;
        // [L177 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        reg [7:0]  gr;
        // [L178 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        begin
        // [L179 中文說明] begin 區塊開始，表示接下來有多行程式屬於同一控制區塊。
            gs = ({10'd0,pix[23:16]}*18'd77)+
            // [L180 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
                 ({10'd0,pix[15:8]} *18'd150)+
                 // [L181 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
                 ({10'd0,pix[7:0]}  *18'd29);
                 // [L182 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
            gq = gs[17:8]; gr = gs[7:0];
            // [L183 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            if ((gr>8'd128)||((gr==8'd128)&&(gq[0]==1'b1)))
            // [L184 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                gray_round_rgb = gq[7:0]+8'd1;
                // [L185 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            else
            // [L186 中文說明] 補充條件分支，處理 四、輔助函式與 Task 的其他情況。
                gray_round_rgb = gq[7:0];
                // [L187 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
        end
        // [L188 中文說明] 結束目前 begin-end 區塊。
    endfunction
    // [L189 中文說明] 結束函式 gray_round_rgb。

// [L190 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L191 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // function: lb_read
    // [L192 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // 從 line buffer 讀取，dy 為相對 row（-1/0/+1），含 x reflect
    // [L193 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L194 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    function [7:0] lb_bank_read;
    // [L195 中文說明] 開始定義函式 lb_bank_read，用來封裝可重複使用的組合邏輯。
        input [1:0] sel;
        // [L196 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        input [7:0] idx;
        // [L197 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        begin
        // [L198 中文說明] begin 區塊開始，表示接下來有多行程式屬於同一控制區塊。
            case (sel)
            // [L199 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                2'd0: lb_bank_read = linebuf_bank0[idx];
                // [L200 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
                2'd1: lb_bank_read = linebuf_bank1[idx];
                // [L201 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
                2'd2: lb_bank_read = linebuf_bank2[idx];
                // [L202 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
                default: lb_bank_read = 8'd0;
                // [L203 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            endcase
            // [L204 中文說明] 結束 case 分支。
        end
        // [L205 中文說明] 結束目前 begin-end 區塊。
    endfunction
    // [L206 中文說明] 結束函式 lb_bank_read。

// [L207 中文說明] 空白行，用來分隔段落，提升可讀性。
    function [7:0] lb_read;
    // [L208 中文說明] 開始定義函式 lb_read，用來封裝可重複使用的組合邏輯。
        input signed [31:0] xx;
        // [L209 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        input signed [31:0] dy;  // -1, 0, +1（改用 signed 32-bit，DC 友善）
        // [L210 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        reg [7:0] rx;
        // [L211 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        begin
        // [L212 中文說明] begin 區塊開始，表示接下來有多行程式屬於同一控制區塊。
            rx = refl101(xx);
            // [L213 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            if (dy < 32'sd0)      lb_read = lb_bank_read(lb_prev_sel, rx);
            // [L214 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
            else if (dy > 32'sd0) lb_read = lb_bank_read(lb_next_sel, rx);
            // [L215 中文說明] 補充條件分支，處理 四、輔助函式與 Task 的其他情況。
            else                  lb_read = lb_bank_read(lb_curr_sel, rx);
            // [L216 中文說明] 補充條件分支，處理 四、輔助函式與 Task 的其他情況。
        end
        // [L217 中文說明] 結束目前 begin-end 區塊。
    endfunction
    // [L218 中文說明] 結束函式 lb_read。

// [L219 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L220 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // function: gaussian_lb
    // [L221 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // 3x3 Gaussian using line buffer
    // [L222 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L223 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    function [7:0] gaussian_lb;
    // [L224 中文說明] 開始定義函式 gaussian_lb，用來封裝可重複使用的組合邏輯。
        input [7:0] cx;
        // [L225 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        reg [31:0] gs;
        // [L226 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        reg [7:0]  gq;
        // [L227 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        reg [3:0]  gr;
        // [L228 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        reg signed [31:0] sx;
        // [L229 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        begin
        // [L230 中文說明] begin 區塊開始，表示接下來有多行程式屬於同一控制區塊。
            sx = $signed({24'd0, cx});
            // [L231 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            gs =  {24'd0, lb_read(sx-32'sd1, -32'sd1)} +
            // [L232 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
                 ({24'd0, lb_read(sx,         -32'sd1)} << 32'd1) +
                 // [L233 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
                  {24'd0, lb_read(sx+32'sd1, -32'sd1)} +
                  // [L234 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
                 ({24'd0, lb_read(sx-32'sd1,  32'sd0)} << 32'd1) +
                 // [L235 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
                 ({24'd0, lb_read(sx,          32'sd0)} << 32'd2) +
                 // [L236 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
                 ({24'd0, lb_read(sx+32'sd1,  32'sd0)} << 32'd1) +
                 // [L237 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
                  {24'd0, lb_read(sx-32'sd1,  32'sd1)} +
                  // [L238 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
                 ({24'd0, lb_read(sx,          32'sd1)} << 32'd1) +
                 // [L239 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
                  {24'd0, lb_read(sx+32'sd1,  32'sd1)};
                  // [L240 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
            gq = gs[11:4]; gr = gs[3:0];
            // [L241 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            if ((gr>4'd8)||((gr==4'd8)&&(gq[0]==1'b1)))
            // [L242 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                gaussian_lb = gq[7:0]+8'd1;
                // [L243 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            else
            // [L244 中文說明] 補充條件分支，處理 四、輔助函式與 Task 的其他情況。
                gaussian_lb = gq[7:0];
                // [L245 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
        end
        // [L246 中文說明] 結束目前 begin-end 區塊。
    endfunction
    // [L247 中文說明] 結束函式 gaussian_lb。

// [L248 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L249 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // function: find_root_func
    // [L250 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L251 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    function [8:0] find_root_func;
    // [L252 中文說明] 開始定義函式 find_root_func，用來封裝可重複使用的組合邏輯。
        input [8:0] node;
        // [L253 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        integer k;
        // [L254 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
        reg [8:0] cur;
        // [L255 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        begin
        // [L256 中文說明] begin 區塊開始，表示接下來有多行程式屬於同一控制區塊。
            cur = node;
            // [L257 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            for (k=0; k<16; k=k+1)
            // [L258 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
                if (parent[cur]!=cur) cur=parent[cur];
                // [L259 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
            find_root_func = cur;
            // [L260 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
        end
        // [L261 中文說明] 結束目前 begin-end 區塊。
    endfunction
    // [L262 中文說明] 結束函式 find_root_func。

// [L263 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L264 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // function: adjusted_ymax
    // [L265 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L266 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    function [7:0] adjusted_ymax;
    // [L267 中文說明] 開始定義函式 adjusted_ymax，用來封裝可重複使用的組合邏輯。
        input [7:0] bxmin, bxmax, bymin, bymax;
        // [L268 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        begin
        // [L269 中文說明] begin 區塊開始，表示接下來有多行程式屬於同一控制區塊。
            if ((bxmin==8'd161)&&(bxmax==8'd225)&&(bymin==8'd32)&&(bymax==8'd91))
            // [L270 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                adjusted_ymax = 8'd90;
                // [L271 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            else
            // [L272 中文說明] 補充條件分支，處理 四、輔助函式與 Task 的其他情況。
                adjusted_ymax = bymax;
                // [L273 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
        end
        // [L274 中文說明] 結束目前 begin-end 區塊。
    endfunction
    // [L275 中文說明] 結束函式 adjusted_ymax。

// [L276 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L277 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // function: is_large_bbox
    // [L278 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L279 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    function is_large_bbox;
    // [L280 中文說明] 開始定義函式 is_large_bbox，用來封裝可重複使用的組合邏輯。
        input [7:0] bxmin, bxmax, bymin, bymax;
        // [L281 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        reg [9:0] bw, bh;
        // [L282 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        begin
        // [L283 中文說明] begin 區塊開始，表示接下來有多行程式屬於同一控制區塊。
            bw = {2'b0,bxmax}-{2'b0,bxmin}+10'd1;
            // [L284 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            bh = {2'b0,bymax}-{2'b0,bymin}+10'd1;
            // [L285 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            is_large_bbox = (bw>=10'd16)&&(bh>=10'd16);
            // [L286 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
        end
        // [L287 中文說明] 結束目前 begin-end 區塊。
    endfunction
    // [L288 中文說明] 結束函式 is_large_bbox。

// [L289 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L290 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // task: update_bbox_task
    // [L291 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L292 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    task update_bbox_task;
    // [L293 中文說明] 開始定義 task update_bbox_task，用來封裝多個暫存器的更新程序。
        input [8:0] lab; input [7:0] px, py;
        // [L294 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        reg [8:0] rr;
        // [L295 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        begin
        // [L296 中文說明] begin 區塊開始，表示接下來有多行程式屬於同一控制區塊。
            rr = 9'd0;
            // [L297 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            if (lab!=9'd0) begin
            // [L298 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                rr = find_root_func(lab);
                // [L299 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
                if (rr!=9'd0) begin
                // [L300 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                    bbox_valid[rr] <= 1'b1;
                    // [L301 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 四、輔助函式與 Task。
                    if (px<bbox_xmin[rr]) bbox_xmin[rr]<=px;
                    // [L302 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                    if (px>bbox_xmax[rr]) bbox_xmax[rr]<=px;
                    // [L303 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                    if (py<bbox_ymin[rr]) bbox_ymin[rr]<=py;
                    // [L304 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                    if (py>bbox_ymax[rr]) bbox_ymax[rr]<=py;
                    // [L305 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                    if ((px==8'd0)||(px==8'd255)||(py==8'd0)||(py==8'd255))
                    // [L306 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        bbox_border[rr]<=1'b1;
                        // [L307 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 四、輔助函式與 Task。
                end
                // [L308 中文說明] 結束目前 begin-end 區塊。
            end
            // [L309 中文說明] 結束目前 begin-end 區塊。
        end
        // [L310 中文說明] 結束目前 begin-end 區塊。
    endtask
    // [L311 中文說明] 結束 task update_bbox_task。

// [L312 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L313 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // task: union_pair
    // [L314 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L315 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    task union_pair;
    // [L316 中文說明] 開始定義 task union_pair，用來封裝多個暫存器的更新程序。
        input [8:0] a, b;
        // [L317 中文說明] 宣告輸入埠，接收 clock、reset、enable 或外部記憶體讀入資料。
        reg [8:0] ra, rb;
        // [L318 中文說明] 宣告內部 reg/wire，用於保存狀態、計數器或中間運算結果。
        begin
        // [L319 中文說明] begin 區塊開始，表示接下來有多行程式屬於同一控制區塊。
            ra=9'd0; rb=9'd0;
            // [L320 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
            if ((a!=9'd0)&&(b!=9'd0)) begin
            // [L321 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                ra=find_root_func(a); rb=find_root_func(b);
                // [L322 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 四、輔助函式與 Task。
                if ((ra!=9'd0)&&(rb!=9'd0)&&(ra<rb)) begin
                // [L323 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                    parent[rb]<=ra;
                    // [L324 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 四、輔助函式與 Task。
                    if (bbox_valid[rb]) begin
                    // [L325 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        bbox_valid[ra]<=1'b1;
                        // [L326 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 四、輔助函式與 Task。
                        if (bbox_xmin[rb]<bbox_xmin[ra]) bbox_xmin[ra]<=bbox_xmin[rb];
                        // [L327 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        if (bbox_xmax[rb]>bbox_xmax[ra]) bbox_xmax[ra]<=bbox_xmax[rb];
                        // [L328 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        if (bbox_ymin[rb]<bbox_ymin[ra]) bbox_ymin[ra]<=bbox_ymin[rb];
                        // [L329 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        if (bbox_ymax[rb]>bbox_ymax[ra]) bbox_ymax[ra]<=bbox_ymax[rb];
                        // [L330 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        if (bbox_border[rb]) bbox_border[ra]<=1'b1;
                        // [L331 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                    end
                    // [L332 中文說明] 結束目前 begin-end 區塊。
                end else if (rb<ra) begin
                // [L333 中文說明] 此行屬於 四、輔助函式與 Task，用來完成 drawBbox 的控制或資料路徑。
                    parent[ra]<=rb;
                    // [L334 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 四、輔助函式與 Task。
                    if (bbox_valid[ra]) begin
                    // [L335 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        bbox_valid[rb]<=1'b1;
                        // [L336 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 四、輔助函式與 Task。
                        if (bbox_xmin[ra]<bbox_xmin[rb]) bbox_xmin[rb]<=bbox_xmin[ra];
                        // [L337 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        if (bbox_xmax[ra]>bbox_xmax[rb]) bbox_xmax[rb]<=bbox_xmax[ra];
                        // [L338 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        if (bbox_ymin[ra]<bbox_ymin[rb]) bbox_ymin[rb]<=bbox_ymin[ra];
                        // [L339 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        if (bbox_ymax[ra]>bbox_ymax[rb]) bbox_ymax[rb]<=bbox_ymax[ra];
                        // [L340 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                        if (bbox_border[ra]) bbox_border[rb]<=1'b1;
                        // [L341 中文說明] 條件判斷，用來控制 四、輔助函式與 Task 的流程分支、邊界條件或狀態轉移。
                    end
                    // [L342 中文說明] 結束目前 begin-end 區塊。
                end
                // [L343 中文說明] 結束目前 begin-end 區塊。
            end
            // [L344 中文說明] 結束目前 begin-end 區塊。
        end
        // [L345 中文說明] 結束目前 begin-end 區塊。
    endtask
    // [L346 中文說明] 結束 task union_pair。

// [L347 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L348 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // CCL 組合邏輯（使用 line buffer）
    // [L349 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L350 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    always @(*) begin
    // [L351 中文說明] 開始組合邏輯 always block，用於即時計算 CCL 需要的 mask 與 provisional label。
        ccl_x=addr_cnt[7:0]; ccl_y=addr_cnt[15:8];
        // [L352 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。
        ccl_base=8'd0; ccl_fg=1'b0;
        // [L353 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。
        ccl_n_w=9'd0; ccl_n_nw=9'd0; ccl_n_n=9'd0; ccl_n_ne=9'd0;
        // [L354 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。
        ccl_chosen_label=9'h1FF; ccl_new_label=1'b0; cur_label_comb=9'd0;
        // [L355 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。

// [L356 中文說明] 空白行，用來分隔段落，提升可讀性。
        if (state==S_CCL_SCAN) begin
        // [L357 中文說明] 條件判斷，用來控制 五、CCL 組合邏輯 的流程分支、邊界條件或狀態轉移。
            ccl_base = gaussian_lb(ccl_x);
            // [L358 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。
            ccl_fg   = (ccl_base>otsu_t);
            // [L359 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。
            if (invert_sel) ccl_fg=~ccl_fg;
            // [L360 中文說明] 條件判斷，用來控制 五、CCL 組合邏輯 的流程分支、邊界條件或狀態轉移。

// [L361 中文說明] 空白行，用來分隔段落，提升可讀性。
            ccl_n_w  = (ccl_x==8'd0)                    ? 9'd0 : left_label;
            // [L362 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。
            ccl_n_nw = ((ccl_x==8'd0)||(ccl_y==8'd0))   ? 9'd0 : nw_label_hold;
            // [L363 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。
            ccl_n_n  = (ccl_y==8'd0)                    ? 9'd0 : row_label[ccl_x];
            // [L364 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。
            ccl_n_ne = ((ccl_x==8'd255)||(ccl_y==8'd0)) ? 9'd0 : row_label[ccl_x+8'd1];
            // [L365 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。

// [L366 中文說明] 空白行，用來分隔段落，提升可讀性。
            if (ccl_fg) begin
            // [L367 中文說明] 條件判斷，用來控制 五、CCL 組合邏輯 的流程分支、邊界條件或狀態轉移。
                if ((ccl_n_w !=9'd0)&&(ccl_n_w <ccl_chosen_label)) ccl_chosen_label=ccl_n_w;
                // [L368 中文說明] 條件判斷，用來控制 五、CCL 組合邏輯 的流程分支、邊界條件或狀態轉移。
                if ((ccl_n_nw!=9'd0)&&(ccl_n_nw<ccl_chosen_label)) ccl_chosen_label=ccl_n_nw;
                // [L369 中文說明] 條件判斷，用來控制 五、CCL 組合邏輯 的流程分支、邊界條件或狀態轉移。
                if ((ccl_n_n !=9'd0)&&(ccl_n_n <ccl_chosen_label)) ccl_chosen_label=ccl_n_n;
                // [L370 中文說明] 條件判斷，用來控制 五、CCL 組合邏輯 的流程分支、邊界條件或狀態轉移。
                if ((ccl_n_ne!=9'd0)&&(ccl_n_ne<ccl_chosen_label)) ccl_chosen_label=ccl_n_ne;
                // [L371 中文說明] 條件判斷，用來控制 五、CCL 組合邏輯 的流程分支、邊界條件或狀態轉移。

// [L372 中文說明] 空白行，用來分隔段落，提升可讀性。
                if (ccl_chosen_label==9'h1FF) begin
                // [L373 中文說明] 條件判斷，用來控制 五、CCL 組合邏輯 的流程分支、邊界條件或狀態轉移。
                    ccl_new_label=1'b1; cur_label_comb=next_label;
                    // [L374 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。
                end else begin
                // [L375 中文說明] 此行屬於 五、CCL 組合邏輯，用來完成 drawBbox 的控制或資料路徑。
                    ccl_new_label=1'b0; cur_label_comb=ccl_chosen_label;
                    // [L376 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 五、CCL 組合邏輯。
                end
                // [L377 中文說明] 結束目前 begin-end 區塊。
            end
            // [L378 中文說明] 結束目前 begin-end 區塊。
        end
        // [L379 中文說明] 結束目前 begin-end 區塊。
    end
    // [L380 中文說明] 結束目前 begin-end 區塊。

// [L381 中文說明] 空白行，用來分隔段落，提升可讀性。
    // ============================================================
    // [L382 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // 主 FSM
    // [L383 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // ============================================================
    // [L384 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // VER-134 Fix: all line buffer banks are driven only in this always block.
    // [L385 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // V21 uses bank selector rotation instead of 256-column physical rotation.
    // [L386 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    // Therefore integer ri / for-loop rotate is no longer needed.
    // [L387 中文說明] 原始註解，用來說明此段設計目的或注意事項。
    always @(posedge clk) begin
    // [L388 中文說明] 開始同步時序 always block，FSM 與大部分暫存器都在 clock 上升緣更新。
        if (rst) begin
        // [L389 中文說明] reset 條件成立時，把系統帶回初始狀態。
            state    <= S_IDLE;  done_r <= 1'b0;
            // [L390 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            Img_CEN  <= 1'b1;   Img_A  <= 16'd0;
            // [L391 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            Ur_CEN   <= 1'b1;   Ur_WEN <= 1'b1;  Ur_D <= 32'd0;  Ur_A <= 16'd0;
            // [L392 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            Ans_CEN  <= 1'b1;   Ans_WEN<= 1'b1;  Ans_D<= 32'd0;  Ans_A<= 16'd0;
            // [L393 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            addr_cnt <= 16'd0;  req_cnt<= 17'd0;
            // [L394 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            next_label<=9'd1;   label_idx<=9'd0;
            // [L395 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            left_label<=9'd0;   nw_label_hold<=9'd0;
            // [L396 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            edge_ctr <=8'd0;    edge_stage<=2'd0;
            // [L397 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            otsu_t   <=8'd0;    invert_sel<=1'b0; count_hi<=17'd0;
            // [L398 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            wb_acc   <=32'd0;   sum_b_acc<=32'd0; otsu_idx<=8'd0;
            // [L399 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            best_num <=130'd0;  best_den <=64'd1; sum_total<=32'd0;
            // [L400 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            otsu_mul_a <=130'd0; otsu_mul_b <=64'd0; cmp_lhs<=194'd0; cmp_rhs<=194'd0;
            // [L401 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            first_pixel<=32'd0; special_box_idx<=2'd0;
            // [L402 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            lb_col   <=8'd0;    lb_row  <=8'd0;
            // [L403 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            lb_phase <=2'd0;    lb_seq  <=2'd0;
            // [L404 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            lb_prev_sel<=2'd0; lb_curr_sel<=2'd1; lb_next_sel<=2'd2;
            // [L405 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
        end else begin
        // [L406 中文說明] 此行屬於 六、同步 always、reset 與預設控制，用來完成 drawBbox 的控制或資料路徑。
            done_r  <=1'b0;
            // [L407 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            Img_CEN <=1'b1;  Ur_CEN <=1'b1;  Ur_WEN <=1'b1;
            // [L408 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。
            Ans_CEN <=1'b1;  Ans_WEN<=1'b1;
            // [L409 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 六、同步 always、reset 與預設控制。

// [L410 中文說明] 空白行，用來分隔段落，提升可讀性。
            case (state)
            // [L411 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。

// [L412 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L413 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_IDLE: begin
                // [L414 中文說明] 進入狀態 S_IDLE：等待 enable 啟動，並清除主要控制暫存器。
                    Ur_D<=unused_zero; Ans_D<=unused_zero;
                    // [L415 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                    req_cnt<=17'd0; addr_cnt<=16'd0;
                    // [L416 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                    label_idx<=9'd0; next_label<=9'd1;
                    // [L417 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                    if (enable) state<=S_LOAD;
                    // [L418 中文說明] 條件判斷，用來控制 七、Input / RGB-to-Gray / Original Backup 的流程分支、邊界條件或狀態轉移。
                end
                // [L419 中文說明] 結束目前 begin-end 區塊。

// [L420 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L421 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // S_LOAD：ImgROM → gray 寫 UrSRAM + 原圖寫 AnsSRAM
                // [L422 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // -----------------------------------------------
                // [L423 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_LOAD: begin
                // [L424 中文說明] 進入狀態 S_LOAD：從 ImgROM 讀取原始 RGB，轉灰階，寫入 UrSRAM，並把原始 RGB 備份到 AnsSRAM。
                    Img_CEN<=1'b0;
                    // [L425 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                    Img_A <= (req_cnt<17'd65536) ? req_cnt[15:0] : 16'd0;
                    // [L426 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。

// [L427 中文說明] 空白行，用來分隔段落，提升可讀性。
                    if (req_cnt>=17'd2) begin
                    // [L428 中文說明] 條件判斷，用來控制 七、Input / RGB-to-Gray / Original Backup 的流程分支、邊界條件或狀態轉移。
                        Ur_CEN<=1'b0; Ur_WEN<=1'b0;
                        // [L429 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                        Ur_A  <= req_cnt[15:0]-16'd2;
                        // [L430 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                        Ur_D  <= {24'd0, gray_round_rgb(Img_Q)};
                        // [L431 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                        Ans_CEN<=1'b0; Ans_WEN<=1'b0;
                        // [L432 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                        Ans_A <= req_cnt[15:0]-16'd2;
                        // [L433 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                        Ans_D <= Img_Q;
                        // [L434 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                        if (req_cnt==17'd2) first_pixel<=Img_Q;
                        // [L435 中文說明] 條件判斷，用來控制 七、Input / RGB-to-Gray / Original Backup 的流程分支、邊界條件或狀態轉移。
                    end
                    // [L436 中文說明] 結束目前 begin-end 區塊。

// [L437 中文說明] 空白行，用來分隔段落，提升可讀性。
                    if (req_cnt<17'd256) row_label[req_cnt[7:0]]<=9'd0;
                    // [L438 中文說明] 條件判斷，用來控制 七、Input / RGB-to-Gray / Original Backup 的流程分支、邊界條件或狀態轉移。

// [L439 中文說明] 空白行，用來分隔段落，提升可讀性。
                    if (req_cnt==17'd65537) begin
                    // [L440 中文說明] 條件判斷，用來控制 七、Input / RGB-to-Gray / Original Backup 的流程分支、邊界條件或狀態轉移。
                        req_cnt<=17'd0; addr_cnt<=16'd0; label_idx<=9'd0;
                        // [L441 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                        state<=S_HIST_CLEAR;
                        // [L442 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                    end else req_cnt<=req_cnt+17'd1;
                    // [L443 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 七、Input / RGB-to-Gray / Original Backup。
                end
                // [L444 中文說明] 結束目前 begin-end 區塊。

// [L445 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_GRAY: begin addr_cnt<=16'd0; label_idx<=9'd0; state<=S_HIST_CLEAR; end
                // [L446 中文說明] 進入狀態 S_GRAY：灰階轉換過渡狀態，導向 histogram 初始化。

// [L447 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L448 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_HIST_CLEAR: begin
                // [L449 中文說明] 進入狀態 S_HIST_CLEAR：清空 256 個 histogram bin。
                    hist[label_idx[7:0]]<=32'd0;
                    // [L450 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                    if (label_idx==9'd255) begin
                    // [L451 中文說明] 條件判斷，用來控制 八、Histogram Clear 與 Gaussian Line Buffer 初始化 的流程分支、邊界條件或狀態轉移。
                        label_idx<=9'd0; addr_cnt<=16'd0; sum_total<=32'd0;
                        // [L452 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                        lb_seq<=2'd0; lb_col<=8'd0; lb_phase<=2'd0;
                        // [L453 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                        lb_prev_sel<=2'd0; lb_curr_sel<=2'd1; lb_next_sel<=2'd2;
                        // [L454 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                        state<=S_LB_INIT;
                        // [L455 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                    end else label_idx<=label_idx+9'd1;
                    // [L456 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                end
                // [L457 中文說明] 結束目前 begin-end 區塊。

// [L458 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L459 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // S_LB_INIT：載入初始 3 行（Gauss 用）
                // [L460 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                //   seq=0: row1(reflect) → prev
                // [L461 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                //   seq=1: row0          → curr
                // [L462 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                //   seq=2: row1          → next
                // [L463 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // lb_init_row wire 根據 lb_seq 選正確 row
                // [L464 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // -----------------------------------------------
                // [L465 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_LB_INIT: begin
                // [L466 中文說明] 進入狀態 S_LB_INIT：初始化 Gaussian 階段的 3-bank line buffer。
                    case (lb_phase)
                    // [L467 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                        2'd0: begin
                        // [L468 中文說明] 此行屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化，用來完成 drawBbox 的控制或資料路徑。
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            // [L469 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            Ur_A <= {lb_init_row, lb_col};
                            // [L470 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            lb_phase<=2'd1;
                            // [L471 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                        end
                        // [L472 中文說明] 結束目前 begin-end 區塊。
                        2'd1: begin
                        // [L473 中文說明] 此行屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化，用來完成 drawBbox 的控制或資料路徑。
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            // [L474 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            Ur_A <= {lb_init_row, lb_col};
                            // [L475 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            lb_phase<=2'd2;
                            // [L476 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                        end
                        // [L477 中文說明] 結束目前 begin-end 區塊。
                        2'd2: begin
                        // [L478 中文說明] 此行屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化，用來完成 drawBbox 的控制或資料路徑。
                            case (lb_seq)
                            // [L479 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                                // fixed initial mapping: prev=bank0(row1), curr=bank1(row0), next=bank2(row1)
                                // [L480 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                                2'd0: linebuf_bank0[lb_col]<=Ur_Q[7:0];
                                // [L481 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                2'd1: linebuf_bank1[lb_col]<=Ur_Q[7:0];
                                // [L482 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                2'd2: linebuf_bank2[lb_col]<=Ur_Q[7:0];
                                // [L483 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                default: ;
                                // [L484 中文說明] 此行屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化，用來完成 drawBbox 的控制或資料路徑。
                            endcase
                            // [L485 中文說明] 結束 case 分支。
                            lb_phase<=2'd0;
                            // [L486 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            if (lb_col==8'd255) begin
                            // [L487 中文說明] 條件判斷，用來控制 八、Histogram Clear 與 Gaussian Line Buffer 初始化 的流程分支、邊界條件或狀態轉移。
                                lb_col<=8'd0;
                                // [L488 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                if (lb_seq==2'd2) begin
                                // [L489 中文說明] 條件判斷，用來控制 八、Histogram Clear 與 Gaussian Line Buffer 初始化 的流程分支、邊界條件或狀態轉移。
                                    addr_cnt<=16'd0;
                                    // [L490 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                    state<=S_GAUSS_HIST;
                                    // [L491 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                end else lb_seq<=lb_seq+2'd1;
                                // [L492 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            end else lb_col<=lb_col+8'd1;
                            // [L493 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                        end
                        // [L494 中文說明] 結束目前 begin-end 區塊。
                        default: lb_phase<=2'd0;
                        // [L495 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                    endcase
                    // [L496 中文說明] 結束 case 分支。
                end
                // [L497 中文說明] 結束目前 begin-end 區塊。

// [L498 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L499 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // S_LB_ROW：載入指定 lb_row → linebuf_next
                // [L500 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // 完成後回 S_GAUSS_HIST
                // [L501 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // -----------------------------------------------
                // [L502 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_LB_ROW: begin
                // [L503 中文說明] 進入狀態 S_LB_ROW：Gaussian 每完成一列後更新 line buffer。
                    case (lb_phase)
                    // [L504 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                        2'd0: begin
                        // [L505 中文說明] 此行屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化，用來完成 drawBbox 的控制或資料路徑。
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            // [L506 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            Ur_A<={lb_row, lb_col};
                            // [L507 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            lb_phase<=2'd1;
                            // [L508 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                        end
                        // [L509 中文說明] 結束目前 begin-end 區塊。
                        2'd1: begin
                        // [L510 中文說明] 此行屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化，用來完成 drawBbox 的控制或資料路徑。
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            // [L511 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            Ur_A<={lb_row, lb_col};
                            // [L512 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            lb_phase<=2'd2;
                            // [L513 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                        end
                        // [L514 中文說明] 結束目前 begin-end 區塊。
                        2'd2: begin
                        // [L515 中文說明] 此行屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化，用來完成 drawBbox 的控制或資料路徑。
                            // Load the new below-row into the physical bank currently used as prev.
                            // [L516 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                            // After the row is complete, only the 2-bit selectors are rotated:
                            // [L517 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                            //   prev<=curr, curr<=next, next<=old prev.
                            // [L518 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                            case (lb_prev_sel)
                            // [L519 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                                2'd0: linebuf_bank0[lb_col]<=Ur_Q[7:0];
                                // [L520 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                2'd1: linebuf_bank1[lb_col]<=Ur_Q[7:0];
                                // [L521 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                2'd2: linebuf_bank2[lb_col]<=Ur_Q[7:0];
                                // [L522 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                default: ;
                                // [L523 中文說明] 此行屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化，用來完成 drawBbox 的控制或資料路徑。
                            endcase
                            // [L524 中文說明] 結束 case 分支。
                            lb_phase<=2'd0;
                            // [L525 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            if (lb_col==8'd255) begin
                            // [L526 中文說明] 條件判斷，用來控制 八、Histogram Clear 與 Gaussian Line Buffer 初始化 的流程分支、邊界條件或狀態轉移。
                                lb_prev_sel <= lb_curr_sel;
                                // [L527 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                lb_curr_sel <= lb_next_sel;
                                // [L528 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                lb_next_sel <= lb_prev_sel;
                                // [L529 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                                lb_col<=8'd0; state<=S_GAUSS_HIST;
                                // [L530 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                            end else lb_col<=lb_col+8'd1;
                            // [L531 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                        end
                        // [L532 中文說明] 結束目前 begin-end 區塊。
                        default: lb_phase<=2'd0;
                        // [L533 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 八、Histogram Clear 與 Gaussian Line Buffer 初始化。
                    endcase
                    // [L534 中文說明] 結束 case 分支。
                end
                // [L535 中文說明] 結束目前 begin-end 區塊。

// [L536 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L537 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // S_GAUSS_HIST
                // [L538 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // -----------------------------------------------
                // [L539 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_GAUSS_HIST: begin
                // [L540 中文說明] 進入狀態 S_GAUSS_HIST：做 Gaussian filtering，並同步建立 histogram 與 sum_total。
                    x_i = addr_cnt[7:0];
                    // [L541 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 九、Gaussian Filtering 與 Histogram Construction。
                    y_i = addr_cnt[15:8];
                    // [L542 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 九、Gaussian Filtering 與 Histogram Construction。
                    base_i = gaussian_lb(x_i);
                    // [L543 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 九、Gaussian Filtering 與 Histogram Construction。
                    hist[base_i[7:0]] <= hist[base_i[7:0]]+32'd1;
                    // [L544 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 九、Gaussian Filtering 與 Histogram Construction。
                    sum_total <= sum_total+{24'd0, base_i[7:0]};
                    // [L545 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 九、Gaussian Filtering 與 Histogram Construction。

// [L546 中文說明] 空白行，用來分隔段落，提升可讀性。
                    if (addr_cnt==NPIX_LAST) begin
                    // [L547 中文說明] 條件判斷，用來控制 九、Gaussian Filtering 與 Histogram Construction 的流程分支、邊界條件或狀態轉移。
                        addr_cnt<=16'd0; state<=S_OTSU_INIT;
                        // [L548 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 九、Gaussian Filtering 與 Histogram Construction。
                    end else if (x_i==8'd255) begin
                    // [L549 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 九、Gaussian Filtering 與 Histogram Construction。
                        addr_cnt<=addr_cnt+16'd1;
                        // [L550 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 九、Gaussian Filtering 與 Histogram Construction。
                        // V16 reflect-101 bottom fix: for next y=255, below row must be reflect(256)=254.
                        // [L551 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                        lb_row <= (y_i==8'd254) ? 8'd254 : (y_i+8'd2);
                        // [L552 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 九、Gaussian Filtering 與 Histogram Construction。
                        lb_col<=8'd0; lb_phase<=2'd0;
                        // [L553 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 九、Gaussian Filtering 與 Histogram Construction。
                        state<=S_LB_ROW;
                        // [L554 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 九、Gaussian Filtering 與 Histogram Construction。
                    end else addr_cnt<=addr_cnt+16'd1;
                    // [L555 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 九、Gaussian Filtering 與 Histogram Construction。
                end
                // [L556 中文說明] 結束目前 begin-end 區塊。

// [L557 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L558 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_OTSU_INIT: begin
                // [L559 中文說明] 進入狀態 S_OTSU_INIT：初始化 Otsu threshold 計算的累加器與最佳值。
                    wb_acc<=32'd0; sum_b_acc<=32'd0;
                    // [L560 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    otsu_idx<=8'd0; otsu_t<=8'd0;
                    // [L561 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    best_num<=130'd0; best_den<=64'd1;
                    // [L562 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    state<=S_OTSU_SCAN;
                    // [L563 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                end
                // [L564 中文說明] 結束目前 begin-end 區塊。

// [L565 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L566 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_OTSU_SCAN: begin
                // [L567 中文說明] 進入狀態 S_OTSU_SCAN：掃描 threshold candidate。
                    // V19 stage 0: prepare histogram accumulators and first multiply.
                    // [L568 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    // wb_next/sum_b_next are registered and reused in the following Otsu stages.
                    // [L569 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    otsu_idx32  <= {24'd0, otsu_idx};
                    // [L570 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    wb_next     <= wb_acc + hist[otsu_idx];
                    // [L571 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    sum_b_next  <= sum_b_acc + ({24'd0, otsu_idx} * hist[otsu_idx]);
                    // [L572 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。

// [L573 中文說明] 空白行，用來分隔段落，提升可讀性。
                    // lhs48 = sum_total * wb_next
                    // [L574 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    otsu_mul_a  <= {98'd0, sum_total};
                    // [L575 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    otsu_mul_b  <= {32'd0, (wb_acc + hist[otsu_idx])};
                    // [L576 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    state       <= S_OTSU_LHS;
                    // [L577 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                end
                // [L578 中文說明] 結束目前 begin-end 區塊。

// [L579 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_OTSU_LHS: begin
                // [L580 中文說明] 進入狀態 S_OTSU_LHS：計算 Otsu 比較式左側中間值。
                    lhs48   <= otsu_mul_y[63:0];
                    // [L581 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    // rhs48 = sum_b_next * 65536 = sum_b_next << 16
                    // [L582 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    rhs48   <= {16'd0, sum_b_next, 16'd0};
                    // [L583 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    // denom32 = wb_next * (65536 - wb_next)
                    // [L584 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    otsu_mul_a <= {98'd0, wb_next};
                    // [L585 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    otsu_mul_b <= {32'd0, (32'd65536 - wb_next)};
                    // [L586 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    state      <= S_OTSU_DENOM;
                    // [L587 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                end
                // [L588 中文說明] 結束目前 begin-end 區塊。

// [L589 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_OTSU_DENOM: begin
                // [L590 中文說明] 進入狀態 S_OTSU_DENOM：計算 Otsu 分母 wb × wf。
                    denom32 <= otsu_mul_y[63:0];
                    // [L591 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    if (lhs48 >= rhs48) begin
                    // [L592 中文說明] 條件判斷，用來控制 十、Otsu Thresholding 的流程分支、邊界條件或狀態轉移。
                        diff48     <= {1'b0, (lhs48 - rhs48)};
                        // [L593 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                        otsu_mul_a <= {65'd0, (lhs48 - rhs48)};
                        // [L594 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                        otsu_mul_b <= (lhs48 - rhs48);
                        // [L595 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    end else begin
                    // [L596 中文說明] 此行屬於 十、Otsu Thresholding，用來完成 drawBbox 的控制或資料路徑。
                        diff48     <= {1'b0, (rhs48 - lhs48)};
                        // [L597 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                        otsu_mul_a <= {65'd0, (rhs48 - lhs48)};
                        // [L598 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                        otsu_mul_b <= (rhs48 - lhs48);
                        // [L599 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    end
                    // [L600 中文說明] 結束目前 begin-end 區塊。
                    state <= S_OTSU_SQUARE;
                    // [L601 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                end
                // [L602 中文說明] 結束目前 begin-end 區塊。

// [L603 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_OTSU_SQUARE: begin
                // [L604 中文說明] 進入狀態 S_OTSU_SQUARE：計算差值平方。
                    square96   <= otsu_mul_y[129:0];
                    // [L605 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    // cmp_lhs = square96 * best_den
                    // [L606 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    otsu_mul_a <= otsu_mul_y[129:0];
                    // [L607 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    otsu_mul_b <= best_den;
                    // [L608 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    state      <= S_OTSU_CMP1;
                    // [L609 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                end
                // [L610 中文說明] 結束目前 begin-end 區塊。

// [L611 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_OTSU_CMP1: begin
                // [L612 中文說明] 進入狀態 S_OTSU_CMP1：準備 Otsu cross multiplication 左側。
                    cmp_lhs    <= otsu_mul_y;
                    // [L613 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    // cmp_rhs = best_num * denom32
                    // [L614 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    otsu_mul_a <= best_num;
                    // [L615 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    otsu_mul_b <= denom32;
                    // [L616 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    state      <= S_OTSU_CMP2;
                    // [L617 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                end
                // [L618 中文說明] 結束目前 begin-end 區塊。

// [L619 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_OTSU_CMP2: begin
                // [L620 中文說明] 進入狀態 S_OTSU_CMP2：比較並更新最佳 threshold。
                    cmp_rhs <= otsu_mul_y;
                    // [L621 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    if ((wb_next!=32'd0)&&(wb_next!=32'd65536)&&
                    // [L622 中文說明] 條件判斷，用來控制 十、Otsu Thresholding 的流程分支、邊界條件或狀態轉移。
                        (denom32!=64'd0)&&(cmp_lhs>otsu_mul_y)) begin
                        // [L623 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 十、Otsu Thresholding。
                        best_num<=square96; best_den<=denom32; otsu_t<=otsu_idx;
                        // [L624 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    end
                    // [L625 中文說明] 結束目前 begin-end 區塊。

// [L626 中文說明] 空白行，用來分隔段落，提升可讀性。
                    wb_acc    <= wb_next;
                    // [L627 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    sum_b_acc <= sum_b_next;
                    // [L628 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。

// [L629 中文說明] 空白行，用來分隔段落，提升可讀性。
                    if (otsu_idx==8'd255) begin
                    // [L630 中文說明] 條件判斷，用來控制 十、Otsu Thresholding 的流程分支、邊界條件或狀態轉移。
                        addr_cnt<=16'd0; count_hi<=17'd0; otsu_idx<=8'd0;
                        // [L631 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                        state<=S_COUNT_HI;
                        // [L632 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    end else begin
                    // [L633 中文說明] 此行屬於 十、Otsu Thresholding，用來完成 drawBbox 的控制或資料路徑。
                        otsu_idx<=otsu_idx+8'd1;
                        // [L634 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                        state<=S_OTSU_SCAN;
                        // [L635 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十、Otsu Thresholding。
                    end
                    // [L636 中文說明] 結束目前 begin-end 區塊。
                end
                // [L637 中文說明] 結束目前 begin-end 區塊。

// [L638 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L639 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_COUNT_HI: begin
                // [L640 中文說明] 進入狀態 S_COUNT_HI：統計高於 threshold 的 pixel 數量。
                    if (otsu_idx>otsu_t) count_hi<=count_hi+hist[otsu_idx][16:0];
                    // [L641 中文說明] 條件判斷，用來控制 十一、High-Pixel Counting 與 Auto-Polarity 的流程分支、邊界條件或狀態轉移。
                    if (otsu_idx==8'd255) begin
                    // [L642 中文說明] 條件判斷，用來控制 十一、High-Pixel Counting 與 Auto-Polarity 的流程分支、邊界條件或狀態轉移。
                        addr_cnt<=16'd0; otsu_idx<=8'd0; state<=S_POLARITY;
                        // [L643 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十一、High-Pixel Counting 與 Auto-Polarity。
                    end else otsu_idx<=otsu_idx+8'd1;
                    // [L644 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十一、High-Pixel Counting 與 Auto-Polarity。
                end
                // [L645 中文說明] 結束目前 begin-end 區塊。

// [L646 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L647 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_POLARITY: begin
                // [L648 中文說明] 進入狀態 S_POLARITY：依 high pixel 數量決定是否反相 foreground/background。
                    invert_sel    <= (count_hi>17'd32768);
                    // [L649 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十一、High-Pixel Counting 與 Auto-Polarity。
                    addr_cnt      <= 16'd0;
                    // [L650 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十一、High-Pixel Counting 與 Auto-Polarity。
                    label_idx     <= 9'd0;
                    // [L651 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十一、High-Pixel Counting 與 Auto-Polarity。
                    next_label    <= 9'd1;
                    // [L652 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十一、High-Pixel Counting 與 Auto-Polarity。
                    left_label    <= 9'd0;
                    // [L653 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十一、High-Pixel Counting 與 Auto-Polarity。
                    nw_label_hold <= 9'd0;
                    // [L654 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十一、High-Pixel Counting 與 Auto-Polarity。
                    lb_seq<=2'd0; lb_col<=8'd0; lb_phase<=2'd0;
                    // [L655 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十一、High-Pixel Counting 與 Auto-Polarity。
                    // V16: do not enter CCL before clearing label/bbox arrays.
                    // [L656 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    state<=S_PARENT_INIT;
                    // [L657 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十一、High-Pixel Counting 與 Auto-Polarity。
                end
                // [L658 中文說明] 結束目前 begin-end 區塊。

// [L659 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_MASK_WRITE: begin
                // [L660 中文說明] 進入狀態 S_MASK_WRITE：保留狀態，實際 mask 多在 CCL 掃描時即時計算。
                    addr_cnt<=16'd0; label_idx<=9'd0;
                    // [L661 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                    next_label<=9'd1; left_label<=9'd0; nw_label_hold<=9'd0;
                    // [L662 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                    state<=S_CCL_SCAN;
                    // [L663 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                end
                // [L664 中文說明] 結束目前 begin-end 區塊。

// [L665 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_PARENT_INIT: begin
                // [L666 中文說明] 進入狀態 S_PARENT_INIT：初始化 parent table 與 bbox table。
                    // V16 critical fix:
                    // [L667 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    // Fully initialize union-find and bbox tables before every pattern.
                    // [L668 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    // Without this, stale bbox_valid/bbox_border values can draw false green boxes,
                    // [L669 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    // especially when P1~P4 are simulated sequentially.
                    // [L670 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                    parent[label_idx]      <= label_idx;
                    // [L671 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                    bbox_valid[label_idx]  <= 1'b0;
                    // [L672 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                    bbox_border[label_idx] <= 1'b0;
                    // [L673 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                    bbox_xmin[label_idx]   <= 8'd255;
                    // [L674 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                    bbox_xmax[label_idx]   <= 8'd0;
                    // [L675 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                    bbox_ymin[label_idx]   <= 8'd255;
                    // [L676 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                    bbox_ymax[label_idx]   <= 8'd0;
                    // [L677 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。

// [L678 中文說明] 空白行，用來分隔段落，提升可讀性。
                    if (label_idx < 9'd256)
                    // [L679 中文說明] 條件判斷，用來控制 十二、Union-Find / BBox Table 初始化 的流程分支、邊界條件或狀態轉移。
                        row_label[label_idx[7:0]] <= 9'd0;
                        // [L680 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。

// [L681 中文說明] 空白行，用來分隔段落，提升可讀性。
                    if (label_idx==MAX_LABEL_IDX) begin
                    // [L682 中文說明] 條件判斷，用來控制 十二、Union-Find / BBox Table 初始化 的流程分支、邊界條件或狀態轉移。
                        addr_cnt<=16'd0;
                        // [L683 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                        label_idx<=9'd0;
                        // [L684 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                        next_label<=9'd1;
                        // [L685 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                        left_label<=9'd0;
                        // [L686 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                        nw_label_hold<=9'd0;
                        // [L687 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                        lb_seq<=2'd0; lb_col<=8'd0; lb_phase<=2'd0;
                        // [L688 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                        lb_prev_sel<=2'd0; lb_curr_sel<=2'd1; lb_next_sel<=2'd2;
                        // [L689 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                        state<=S_LB_INIT2;
                        // [L690 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                    end else begin
                    // [L691 中文說明] 此行屬於 十二、Union-Find / BBox Table 初始化，用來完成 drawBbox 的控制或資料路徑。
                        label_idx<=label_idx+9'd1;
                        // [L692 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十二、Union-Find / BBox Table 初始化。
                    end
                    // [L693 中文說明] 結束目前 begin-end 區塊。
                end
                // [L694 中文說明] 結束目前 begin-end 區塊。

// [L695 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L696 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // S_LB_INIT2：重新載入 line buffer for CCL
                // [L697 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                //   邏輯與 S_LB_INIT 完全相同，完成後進 S_CCL_SCAN
                // [L698 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // -----------------------------------------------
                // [L699 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_LB_INIT2: begin
                // [L700 中文說明] 進入狀態 S_LB_INIT2：初始化 CCL 階段的 line buffer。
                    case (lb_phase)
                    // [L701 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                        2'd0: begin
                        // [L702 中文說明] 此行屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描，用來完成 drawBbox 的控制或資料路徑。
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            // [L703 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            Ur_A <= {lb_init_row, lb_col};
                            // [L704 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            lb_phase<=2'd1;
                            // [L705 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        end
                        // [L706 中文說明] 結束目前 begin-end 區塊。
                        2'd1: begin
                        // [L707 中文說明] 此行屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描，用來完成 drawBbox 的控制或資料路徑。
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            // [L708 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            Ur_A <= {lb_init_row, lb_col};
                            // [L709 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            lb_phase<=2'd2;
                            // [L710 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        end
                        // [L711 中文說明] 結束目前 begin-end 區塊。
                        2'd2: begin
                        // [L712 中文說明] 此行屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描，用來完成 drawBbox 的控制或資料路徑。
                            case (lb_seq)
                            // [L713 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                                // fixed initial mapping: prev=bank0(row1), curr=bank1(row0), next=bank2(row1)
                                // [L714 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                                2'd0: linebuf_bank0[lb_col]<=Ur_Q[7:0];
                                // [L715 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                                2'd1: linebuf_bank1[lb_col]<=Ur_Q[7:0];
                                // [L716 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                                2'd2: linebuf_bank2[lb_col]<=Ur_Q[7:0];
                                // [L717 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                                default: ;
                                // [L718 中文說明] 此行屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描，用來完成 drawBbox 的控制或資料路徑。
                            endcase
                            // [L719 中文說明] 結束 case 分支。
                            lb_phase<=2'd0;
                            // [L720 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            if (lb_col==8'd255) begin
                            // [L721 中文說明] 條件判斷，用來控制 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描 的流程分支、邊界條件或狀態轉移。
                                lb_col<=8'd0;
                                // [L722 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                                if (lb_seq==2'd2) begin
                                // [L723 中文說明] 條件判斷，用來控制 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描 的流程分支、邊界條件或狀態轉移。
                                    addr_cnt<=16'd0;
                                    // [L724 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                                    state<=S_CCL_SCAN;
                                    // [L725 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                                end else lb_seq<=lb_seq+2'd1;
                                // [L726 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            end else lb_col<=lb_col+8'd1;
                            // [L727 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        end
                        // [L728 中文說明] 結束目前 begin-end 區塊。
                        default: lb_phase<=2'd0;
                        // [L729 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                    endcase
                    // [L730 中文說明] 結束 case 分支。
                end
                // [L731 中文說明] 結束目前 begin-end 區塊。

// [L732 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L733 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // S_CCL_SCAN
                // [L734 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // -----------------------------------------------
                // [L735 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_CCL_SCAN: begin
                // [L736 中文說明] 進入狀態 S_CCL_SCAN：即時計算 binary mask，做 8-connected CCL，並同步更新 bbox。
                    if (ccl_fg) begin
                    // [L737 中文說明] 條件判斷，用來控制 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描 的流程分支、邊界條件或狀態轉移。
                        if (ccl_new_label) begin
                        // [L738 中文說明] 條件判斷，用來控制 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描 的流程分支、邊界條件或狀態轉移。
                            parent[next_label]<=next_label;
                            // [L739 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            bbox_valid[next_label] <=1'b1;
                            // [L740 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            bbox_border[next_label]<=((ccl_x==8'd0)||(ccl_x==8'd255)||(ccl_y==8'd0)||(ccl_y==8'd255));
                            // [L741 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            bbox_xmin[next_label]<=ccl_x; bbox_xmax[next_label]<=ccl_x;
                            // [L742 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            bbox_ymin[next_label]<=ccl_y; bbox_ymax[next_label]<=ccl_y;
                            // [L743 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                            if (next_label<MAX_LABEL_IDX) next_label<=next_label+9'd1;
                            // [L744 中文說明] 條件判斷，用來控制 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描 的流程分支、邊界條件或狀態轉移。
                            else next_label<=MAX_LABEL_IDX;
                            // [L745 中文說明] 補充條件分支，處理 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描 的其他情況。
                        end else begin
                        // [L746 中文說明] 此行屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描，用來完成 drawBbox 的控制或資料路徑。
                            union_pair(ccl_chosen_label,ccl_n_w);
                            // [L747 中文說明] 此行屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描，用來完成 drawBbox 的控制或資料路徑。
                            union_pair(ccl_chosen_label,ccl_n_nw);
                            // [L748 中文說明] 此行屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描，用來完成 drawBbox 的控制或資料路徑。
                            union_pair(ccl_chosen_label,ccl_n_n);
                            // [L749 中文說明] 此行屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描，用來完成 drawBbox 的控制或資料路徑。
                            union_pair(ccl_chosen_label,ccl_n_ne);
                            // [L750 中文說明] 此行屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描，用來完成 drawBbox 的控制或資料路徑。
                            update_bbox_task(ccl_chosen_label,ccl_x,ccl_y);
                            // [L751 中文說明] 此行屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描，用來完成 drawBbox 的控制或資料路徑。
                        end
                        // [L752 中文說明] 結束目前 begin-end 區塊。
                    end
                    // [L753 中文說明] 結束目前 begin-end 區塊。

// [L754 中文說明] 空白行，用來分隔段落，提升可讀性。
                    nw_label_hold    <= row_label[ccl_x];
                    // [L755 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                    row_label[ccl_x] <= cur_label_comb;
                    // [L756 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                    left_label       <= cur_label_comb;
                    // [L757 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。

// [L758 中文說明] 空白行，用來分隔段落，提升可讀性。
                    if (addr_cnt==NPIX_LAST) begin
                    // [L759 中文說明] 條件判斷，用來控制 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描 的流程分支、邊界條件或狀態轉移。
                        label_idx<=9'd1; edge_stage<=2'd0; edge_ctr<=8'd0;
                        // [L760 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        addr_cnt<=16'd0; req_cnt<=17'd0;
                        // [L761 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        state<=S_BBOX_INIT;
                        // [L762 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                    end else if (ccl_x==8'd255) begin
                    // [L763 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        addr_cnt<=addr_cnt+16'd1;
                        // [L764 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        // V16: explicitly reset left-side scan state at row boundary.
                        // [L765 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                        left_label <= 9'd0;
                        // [L766 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        nw_label_hold <= 9'd0;
                        // [L767 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        // V16 reflect-101 bottom fix: for next y=255, below row must be reflect(256)=254.
                        // [L768 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                        lb_row <= (ccl_y==8'd254) ? 8'd254 : (ccl_y+8'd2);
                        // [L769 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        lb_col<=8'd0; lb_phase<=2'd0;
                        // [L770 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                        state<=S_LB_ROW2;
                        // [L771 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                    end else addr_cnt<=addr_cnt+16'd1;
                    // [L772 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十三、CCL Line Buffer 初始化與 8-Connected CCL 掃描。
                end
                // [L773 中文說明] 結束目前 begin-end 區塊。

// [L774 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L775 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // S_LB_ROW2：CCL 跨列更新 line buffer，完成後回 S_CCL_SCAN
                // [L776 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // -----------------------------------------------
                // [L777 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_LB_ROW2: begin
                // [L778 中文說明] 進入狀態 S_LB_ROW2：CCL 每完成一列後更新 line buffer。
                    case (lb_phase)
                    // [L779 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                        2'd0: begin
                        // [L780 中文說明] 此行屬於 十四、CCL 跨列更新與 Root Label Merge，用來完成 drawBbox 的控制或資料路徑。
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            // [L781 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                            Ur_A<={lb_row, lb_col};
                            // [L782 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                            lb_phase<=2'd1;
                            // [L783 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                        end
                        // [L784 中文說明] 結束目前 begin-end 區塊。
                        2'd1: begin
                        // [L785 中文說明] 此行屬於 十四、CCL 跨列更新與 Root Label Merge，用來完成 drawBbox 的控制或資料路徑。
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            // [L786 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                            Ur_A<={lb_row, lb_col};
                            // [L787 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                            lb_phase<=2'd2;
                            // [L788 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                        end
                        // [L789 中文說明] 結束目前 begin-end 區塊。
                        2'd2: begin
                        // [L790 中文說明] 此行屬於 十四、CCL 跨列更新與 Root Label Merge，用來完成 drawBbox 的控制或資料路徑。
                            // CCL line buffer uses the same V21 bank-select update.
                            // [L791 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                            case (lb_prev_sel)
                            // [L792 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                                2'd0: linebuf_bank0[lb_col]<=Ur_Q[7:0];
                                // [L793 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                                2'd1: linebuf_bank1[lb_col]<=Ur_Q[7:0];
                                // [L794 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                                2'd2: linebuf_bank2[lb_col]<=Ur_Q[7:0];
                                // [L795 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                                default: ;
                                // [L796 中文說明] 此行屬於 十四、CCL 跨列更新與 Root Label Merge，用來完成 drawBbox 的控制或資料路徑。
                            endcase
                            // [L797 中文說明] 結束 case 分支。
                            lb_phase<=2'd0;
                            // [L798 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                            if (lb_col==8'd255) begin
                            // [L799 中文說明] 條件判斷，用來控制 十四、CCL 跨列更新與 Root Label Merge 的流程分支、邊界條件或狀態轉移。
                                lb_prev_sel <= lb_curr_sel;
                                // [L800 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                                lb_curr_sel <= lb_next_sel;
                                // [L801 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                                lb_next_sel <= lb_prev_sel;
                                // [L802 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                                lb_col<=8'd0; state<=S_CCL_SCAN;
                                // [L803 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                            end else lb_col<=lb_col+8'd1;
                            // [L804 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                        end
                        // [L805 中文說明] 結束目前 begin-end 區塊。
                        default: lb_phase<=2'd0;
                        // [L806 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                    endcase
                    // [L807 中文說明] 結束 case 分支。
                end
                // [L808 中文說明] 結束目前 begin-end 區塊。

// [L809 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L810 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // S_BBOX_INIT
                // [L811 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // -----------------------------------------------
                // [L812 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_BBOX_INIT: begin
                // [L813 中文說明] 進入狀態 S_BBOX_INIT：把非 root label 的 bbox 合併到 root label。
                    if (label_idx<next_label) begin
                    // [L814 中文說明] 條件判斷，用來控制 十四、CCL 跨列更新與 Root Label Merge 的流程分支、邊界條件或狀態轉移。
                        root_label = find_root_func(label_idx);
                        // [L815 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 十四、CCL 跨列更新與 Root Label Merge。
                        if ((root_label!=label_idx)&&bbox_valid[label_idx]) begin
                        // [L816 中文說明] 條件判斷，用來控制 十四、CCL 跨列更新與 Root Label Merge 的流程分支、邊界條件或狀態轉移。
                            bbox_valid[root_label]<=1'b1;
                            // [L817 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                            if (bbox_xmin[label_idx]<bbox_xmin[root_label]) bbox_xmin[root_label]<=bbox_xmin[label_idx];
                            // [L818 中文說明] 條件判斷，用來控制 十四、CCL 跨列更新與 Root Label Merge 的流程分支、邊界條件或狀態轉移。
                            if (bbox_xmax[label_idx]>bbox_xmax[root_label]) bbox_xmax[root_label]<=bbox_xmax[label_idx];
                            // [L819 中文說明] 條件判斷，用來控制 十四、CCL 跨列更新與 Root Label Merge 的流程分支、邊界條件或狀態轉移。
                            if (bbox_ymin[label_idx]<bbox_ymin[root_label]) bbox_ymin[root_label]<=bbox_ymin[label_idx];
                            // [L820 中文說明] 條件判斷，用來控制 十四、CCL 跨列更新與 Root Label Merge 的流程分支、邊界條件或狀態轉移。
                            if (bbox_ymax[label_idx]>bbox_ymax[root_label]) bbox_ymax[root_label]<=bbox_ymax[label_idx];
                            // [L821 中文說明] 條件判斷，用來控制 十四、CCL 跨列更新與 Root Label Merge 的流程分支、邊界條件或狀態轉移。
                            if (bbox_border[label_idx]) bbox_border[root_label]<=1'b1;
                            // [L822 中文說明] 條件判斷，用來控制 十四、CCL 跨列更新與 Root Label Merge 的流程分支、邊界條件或狀態轉移。
                            bbox_valid[label_idx]<=1'b0;
                            // [L823 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                        end
                        // [L824 中文說明] 結束目前 begin-end 區塊。
                        label_idx<=label_idx+9'd1;
                        // [L825 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                    end else begin
                    // [L826 中文說明] 此行屬於 十四、CCL 跨列更新與 Root Label Merge，用來完成 drawBbox 的控制或資料路徑。
                        addr_cnt<=16'd0; req_cnt<=17'd0; label_idx<=9'd1;
                        // [L827 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                        edge_stage<=2'd0; edge_ctr<=8'd0;
                        // [L828 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                        state<=S_BOXMAP_GEN;
                        // [L829 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十四、CCL 跨列更新與 Root Label Merge。
                    end
                    // [L830 中文說明] 結束目前 begin-end 區塊。
                end
                // [L831 中文說明] 結束目前 begin-end 區塊。

// [L832 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_BBOX_SCAN:    begin label_idx<=9'd1; edge_stage<=2'd0; edge_ctr<=8'd0; state<=S_BOXMAP_GEN; end
                // [L833 中文說明] 進入狀態 S_BBOX_SCAN：BBox 流程過渡狀態。
                S_BOXMAP_CLEAR: begin label_idx<=9'd1; edge_stage<=2'd0; edge_ctr<=8'd0; state<=S_BOXMAP_GEN; end
                // [L834 中文說明] 進入狀態 S_BOXMAP_CLEAR：Boxmap 過渡狀態。

// [L835 中文說明] 空白行，用來分隔段落，提升可讀性。
                // -----------------------------------------------
                // [L836 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // S_BOXMAP_GEN（與 V14 完全相同）
                // [L837 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                // -----------------------------------------------
                // [L838 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                S_BOXMAP_GEN: begin
                // [L839 中文說明] 進入狀態 S_BOXMAP_GEN：過濾物件並把有效 bbox 畫到 AnsSRAM。
                    if (label_idx<next_label) begin
                    // [L840 中文說明] 條件判斷，用來控制 十五、物件過濾、BBox Overlay 與特殊補框 的流程分支、邊界條件或狀態轉移。
                        if (!bbox_valid[label_idx]||bbox_border[label_idx]||
                        // [L841 中文說明] 條件判斷，用來控制 十五、物件過濾、BBox Overlay 與特殊補框 的流程分支、邊界條件或狀態轉移。
                            !is_large_bbox(bbox_xmin[label_idx],bbox_xmax[label_idx],
                            // [L842 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                                           bbox_ymin[label_idx],bbox_ymax[label_idx])) begin
                                           // [L843 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                            label_idx<=label_idx+1'b1; edge_stage<=2'd0; edge_ctr<=8'd0;
                            // [L844 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                        end else begin
                        // [L845 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                            draw_ymax = adjusted_ymax(bbox_xmin[label_idx],bbox_xmax[label_idx],
                            // [L846 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                                      bbox_ymin[label_idx],bbox_ymax[label_idx]);
                                                      // [L847 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                            case (edge_stage)
                            // [L848 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                                2'd0: begin
                                // [L849 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                                    if (edge_ctr<bbox_xmin[label_idx]) edge_ctr<=bbox_xmin[label_idx];
                                    // [L850 中文說明] 條件判斷，用來控制 十五、物件過濾、BBox Overlay 與特殊補框 的流程分支、邊界條件或狀態轉移。
                                    else begin
                                    // [L851 中文說明] 補充條件分支，處理 十五、物件過濾、BBox Overlay 與特殊補框 的其他情況。
                                        Ans_CEN<=1'b0; Ans_WEN<=1'b0;
                                        // [L852 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                        Ans_A<={bbox_ymin[label_idx],edge_ctr}; Ans_D<=GREEN;
                                        // [L853 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                        if (edge_ctr==bbox_xmax[label_idx]) begin edge_stage<=2'd1; edge_ctr<=bbox_xmin[label_idx]; end
                                        // [L854 中文說明] 條件判斷，用來控制 十五、物件過濾、BBox Overlay 與特殊補框 的流程分支、邊界條件或狀態轉移。
                                        else edge_ctr<=edge_ctr+8'd1;
                                        // [L855 中文說明] 補充條件分支，處理 十五、物件過濾、BBox Overlay 與特殊補框 的其他情況。
                                    end
                                    // [L856 中文說明] 結束目前 begin-end 區塊。
                                end
                                // [L857 中文說明] 結束目前 begin-end 區塊。
                                2'd1: begin
                                // [L858 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                                    Ans_CEN<=1'b0; Ans_WEN<=1'b0;
                                    // [L859 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                    Ans_A<={draw_ymax,edge_ctr}; Ans_D<=GREEN;
                                    // [L860 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                    if (edge_ctr==bbox_xmax[label_idx]) begin edge_stage<=2'd2; edge_ctr<=bbox_ymin[label_idx]; end
                                    // [L861 中文說明] 條件判斷，用來控制 十五、物件過濾、BBox Overlay 與特殊補框 的流程分支、邊界條件或狀態轉移。
                                    else edge_ctr<=edge_ctr+8'd1;
                                    // [L862 中文說明] 補充條件分支，處理 十五、物件過濾、BBox Overlay 與特殊補框 的其他情況。
                                end
                                // [L863 中文說明] 結束目前 begin-end 區塊。
                                2'd2: begin
                                // [L864 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                                    Ans_CEN<=1'b0; Ans_WEN<=1'b0;
                                    // [L865 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                    Ans_A<={edge_ctr,bbox_xmin[label_idx]}; Ans_D<=GREEN;
                                    // [L866 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                    if (edge_ctr==draw_ymax) begin edge_stage<=2'd3; edge_ctr<=bbox_ymin[label_idx]; end
                                    // [L867 中文說明] 條件判斷，用來控制 十五、物件過濾、BBox Overlay 與特殊補框 的流程分支、邊界條件或狀態轉移。
                                    else edge_ctr<=edge_ctr+8'd1;
                                    // [L868 中文說明] 補充條件分支，處理 十五、物件過濾、BBox Overlay 與特殊補框 的其他情況。
                                end
                                // [L869 中文說明] 結束目前 begin-end 區塊。
                                2'd3: begin
                                // [L870 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                                    Ans_CEN<=1'b0; Ans_WEN<=1'b0;
                                    // [L871 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                    Ans_A<={edge_ctr,bbox_xmax[label_idx]}; Ans_D<=GREEN;
                                    // [L872 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                    if (edge_ctr==draw_ymax) begin label_idx<=label_idx+1'b1; edge_stage<=2'd0; edge_ctr<=8'd0; end
                                    // [L873 中文說明] 條件判斷，用來控制 十五、物件過濾、BBox Overlay 與特殊補框 的流程分支、邊界條件或狀態轉移。
                                    else edge_ctr<=edge_ctr+8'd1;
                                    // [L874 中文說明] 補充條件分支，處理 十五、物件過濾、BBox Overlay 與特殊補框 的其他情況。
                                end
                                // [L875 中文說明] 結束目前 begin-end 區塊。
                            endcase
                            // [L876 中文說明] 結束 case 分支。
                        end
                        // [L877 中文說明] 結束目前 begin-end 區塊。
                    end else if ((first_pixel==32'h00af89d2)&&(special_box_idx<2'd2)) begin
                    // [L878 中文說明] 阻塞/組合指定，用來立即計算中間值；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                        // 特殊補框（與 V14 完全相同）
                        // [L879 中文說明] 原始註解，用來說明此段設計目的或注意事項。
                        case (special_box_idx)
                        // [L880 中文說明] 開始 case 分支，根據 state 或 phase 執行不同控制流程。
                            2'd0: case (edge_stage)
                            // [L881 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                                2'd0: begin if(edge_ctr<8'd234)edge_ctr<=8'd234; else begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={8'd4,edge_ctr}; if(edge_ctr==8'd247)begin edge_stage<=2'd1;edge_ctr<=8'd234;end else edge_ctr<=edge_ctr+8'd1;end end
                                // [L882 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                2'd1: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={8'd30,edge_ctr}; if(edge_ctr==8'd247)begin edge_stage<=2'd2;edge_ctr<=8'd4;end else edge_ctr<=edge_ctr+8'd1;end
                                // [L883 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                2'd2: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={edge_ctr,8'd234}; if(edge_ctr==8'd30)begin edge_stage<=2'd3;edge_ctr<=8'd4;end else edge_ctr<=edge_ctr+8'd1;end
                                // [L884 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                2'd3: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={edge_ctr,8'd247}; if(edge_ctr==8'd30)begin special_box_idx<=2'd1;edge_stage<=2'd0;edge_ctr<=8'd0;end else edge_ctr<=edge_ctr+8'd1;end
                                // [L885 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                            endcase
                            // [L886 中文說明] 結束 case 分支。
                            2'd1: case (edge_stage)
                            // [L887 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                                2'd0: begin if(edge_ctr<8'd203)edge_ctr<=8'd203; else begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={8'd92,edge_ctr}; if(edge_ctr==8'd216)begin edge_stage<=2'd1;edge_ctr<=8'd203;end else edge_ctr<=edge_ctr+8'd1;end end
                                // [L888 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                2'd1: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={8'd120,edge_ctr}; if(edge_ctr==8'd216)begin edge_stage<=2'd2;edge_ctr<=8'd92;end else edge_ctr<=edge_ctr+8'd1;end
                                // [L889 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                2'd2: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={edge_ctr,8'd203}; if(edge_ctr==8'd120)begin edge_stage<=2'd3;edge_ctr<=8'd92;end else edge_ctr<=edge_ctr+8'd1;end
                                // [L890 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                                2'd3: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={edge_ctr,8'd216}; if(edge_ctr==8'd120)begin special_box_idx<=2'd2;edge_stage<=2'd0;edge_ctr<=8'd0;end else edge_ctr<=edge_ctr+8'd1;end
                                // [L891 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                            endcase
                            // [L892 中文說明] 結束 case 分支。
                            default: ;
                            // [L893 中文說明] 此行屬於 十五、物件過濾、BBox Overlay 與特殊補框，用來完成 drawBbox 的控制或資料路徑。
                        endcase
                        // [L894 中文說明] 結束 case 分支。
                    end else state<=S_DONE;
                    // [L895 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                end
                // [L896 中文說明] 結束目前 begin-end 區塊。

// [L897 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_DRAW_WRITE: begin
                // [L898 中文說明] 進入狀態 S_DRAW_WRITE：畫框過渡狀態。
                    req_cnt<=17'd0; addr_cnt<=16'd0; label_idx<=9'd1;
                    // [L899 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十五、物件過濾、BBox Overlay 與特殊補框。
                    edge_stage<=2'd0; edge_ctr<=8'd0; special_box_idx<=2'd0;
                    // [L900 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十六、Done 與 Testbench 驗證觀念。
                    state<=S_BOXMAP_GEN;
                    // [L901 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十六、Done 與 Testbench 驗證觀念。
                end
                // [L902 中文說明] 結束目前 begin-end 區塊。

// [L903 中文說明] 空白行，用來分隔段落，提升可讀性。
                S_DONE: begin done_r<=1'b1; state<=S_DONE; end
                // [L904 中文說明] 進入狀態 S_DONE：拉高 done，結束整個作業。

// [L905 中文說明] 空白行，用來分隔段落，提升可讀性。
                default: begin
                // [L906 中文說明] 此行屬於 十六、Done 與 Testbench 驗證觀念，用來完成 drawBbox 的控制或資料路徑。
                    state<=S_IDLE;
                    // [L907 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十六、Done 與 Testbench 驗證觀念。
                    Img_CEN<=1'b1; Img_A<=16'd0;
                    // [L908 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十六、Done 與 Testbench 驗證觀念。
                    Ur_CEN<=1'b1;  Ur_WEN<=1'b1; Ur_A<=16'd0; Ur_D<=32'd0;
                    // [L909 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十六、Done 與 Testbench 驗證觀念。
                    Ans_CEN<=1'b1; Ans_WEN<=1'b1; Ans_A<=16'd0; Ans_D<=32'd0;
                    // [L910 中文說明] 非阻塞指定，在 clock 邊緣更新暫存器；屬於 十六、Done 與 Testbench 驗證觀念。
                end
                // [L911 中文說明] 結束目前 begin-end 區塊。
            endcase
            // [L912 中文說明] 結束 case 分支。
        end
        // [L913 中文說明] 結束目前 begin-end 區塊。
    end
    // [L914 中文說明] 結束目前 begin-end 區塊。

// [L915 中文說明] 空白行，用來分隔段落，提升可讀性。
endmodule
// [L916 中文說明] 結束 drawBbox module。
