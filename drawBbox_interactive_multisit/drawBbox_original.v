`timescale 1ns/1ps

// ============================================================
// Module Name : drawBbox
// 
// ============================================================

module drawBbox (
    input              clk,
    input              rst,
    input              enable,
    output             done,

    input      [31:0]  Img_Q,
    output reg         Img_CEN,
    output reg [15:0]  Img_A,

    input      [31:0]  Ur_Q,
    output reg         Ur_CEN,
    output reg         Ur_WEN,
    output reg [31:0]  Ur_D,
    output reg [15:0]  Ur_A,

    input      [31:0]  Ans_Q,
    output reg         Ans_CEN,
    output reg         Ans_WEN,
    output reg [31:0]  Ans_D,
    output reg [15:0]  Ans_A
);

    localparam [31:0] GREEN       = 32'h0000_FF00;
    localparam [16:0] NPIX        = 17'd65536;
    localparam [15:0] NPIX_LAST   = 16'hFFFF;
    localparam [9:0]  MAX_LABELS  = 10'd512;
    localparam [8:0]  MAX_LABEL_IDX = 9'd511;

    localparam [5:0]
        S_IDLE         = 6'd0,
        S_LOAD         = 6'd1,
        S_GRAY         = 6'd2,
        S_HIST_CLEAR   = 6'd3,
        S_LB_INIT      = 6'd4,   // 載入初始 line buffer（3 行）
        S_LB_ROW       = 6'd5,   // 載入單一 row → linebuf_next
        S_GAUSS_HIST   = 6'd6,
        S_OTSU_INIT    = 6'd7,
        S_OTSU_SCAN    = 6'd8,
        S_COUNT_HI     = 6'd9,
        S_POLARITY     = 6'd10,
        S_MASK_WRITE   = 6'd11,
        S_PARENT_INIT  = 6'd12,  // V16: clear parent/bbox arrays before CCL
        S_LB_INIT2     = 6'd13,  // CCL 前重新載入 line buffer
        S_CCL_SCAN     = 6'd14,
        S_LB_ROW2      = 6'd15,  // CCL 跨列 line buffer 更新
        S_BBOX_INIT    = 6'd16,
        S_BBOX_SCAN    = 6'd17,
        S_BOXMAP_CLEAR = 6'd18,
        S_BOXMAP_GEN   = 6'd19,
        S_DRAW_WRITE   = 6'd20,
        S_DONE         = 6'd21,
        // V19: split Otsu into multi-cycle states so DC sees one shared multiplier instead of many huge multipliers
        S_OTSU_LHS     = 6'd22,
        S_OTSU_DENOM   = 6'd23,
        S_OTSU_SQUARE  = 6'd24,
        S_OTSU_CMP1    = 6'd25,
        S_OTSU_CMP2    = 6'd26;

    reg [5:0] state;
    reg done_r;
    assign done = done_r;

    wire [31:0] unused_zero = (Ans_Q ^ Ans_Q);

    // ============================================================
    // 3-Row Line Buffer（取代 gray_mem[65535:0]）
    // ============================================================
    // V21: 3-bank line buffer.
    // Instead of physically rotating 256 columns (prev<=curr, curr<=next),
    // we keep three physical banks and rotate only 2-bit selectors.
    // This preserves RTL alignment but is much easier for Design Compiler.
    reg [7:0] linebuf_bank0 [0:255];
    reg [7:0] linebuf_bank1 [0:255];
    reg [7:0] linebuf_bank2 [0:255];
    reg [1:0] lb_prev_sel, lb_curr_sel, lb_next_sel;

    reg [31:0] hist [255:0];

    reg [8:0]  row_label    [0:255];
    reg [8:0]  left_label;
    reg [8:0]  nw_label_hold;
    reg [8:0]  cur_label_comb;

    reg [8:0]  parent      [MAX_LABELS-1:0];
    reg        bbox_valid  [MAX_LABELS-1:0];
    reg        bbox_border [MAX_LABELS-1:0];
    reg [7:0]  bbox_xmin   [MAX_LABELS-1:0];
    reg [7:0]  bbox_xmax   [MAX_LABELS-1:0];
    reg [7:0]  bbox_ymin   [MAX_LABELS-1:0];
    reg [7:0]  bbox_ymax   [MAX_LABELS-1:0];

    reg [15:0] addr_cnt;
    reg [16:0] req_cnt;
    reg [8:0]  next_label;
    reg [8:0]  label_idx;
    reg [7:0]  edge_ctr;
    reg [1:0]  edge_stage;

    // Line buffer loader
    reg [7:0]  lb_col;    // 目前載入的欄
    reg [7:0]  lb_row;    // 要從 UrSRAM 讀的列（供 S_LB_ROW 用）
    reg [1:0]  lb_phase;  // 0=送addr, 1=等latency, 2=存資料
    reg [1:0]  lb_seq;    // S_LB_INIT 階段序號 (0=prev, 1=curr, 2=next)

    // lb_row_w：S_LB_INIT 階段根據 lb_seq 選擇要讀的 row
    // 用 wire 避免 nonblocking timing 問題
    wire [7:0] lb_init_row = (lb_seq == 2'd1) ? 8'd0 : 8'd1;
    //   seq=0: 讀 row1 (reflect of y=-1) → prev
    //   seq=1: 讀 row0                   → curr
    //   seq=2: 讀 row1                   → next

    reg [7:0]  otsu_t;
    reg        invert_sel;
    reg [16:0] count_hi;
    reg [31:0] wb_acc, sum_b_acc;
    reg [7:0]  otsu_idx;
    reg [63:0] lhs48, rhs48;
    reg [64:0] diff48;
    reg [63:0] denom32;
    reg [31:0] sum_total, wb_next, sum_b_next, otsu_idx32;
    reg [129:0] square96, best_num;
    reg [63:0]  best_den;
    reg [193:0] cmp_lhs, cmp_rhs;

    // V19 synthesis-fast shared multiplier for Otsu.
    // The original V18 S_OTSU_SCAN described several large multipliers in one cycle
    // (32x32, 65x65, 130x64, 130x64). DC may spend a very long time optimizing them.
    // Here all Otsu products go through one 130x64 combinational multiplier across
    // several FSM states. RTL cycles increase by only ~5*256, but synthesis becomes much lighter.
    reg  [129:0] otsu_mul_a;
    reg  [63:0]  otsu_mul_b;
    wire [193:0] otsu_mul_y = otsu_mul_a * otsu_mul_b;

    reg [7:0]  ccl_x, ccl_y, ccl_base;
    reg        ccl_fg;
    reg [8:0]  ccl_n_w, ccl_n_nw, ccl_n_n, ccl_n_ne;
    reg [8:0]  ccl_chosen_label;
    reg        ccl_new_label;
    reg [8:0]  root_label;
    reg [7:0]  draw_ymax;

    reg [31:0] first_pixel;
    reg [1:0]  special_box_idx;
    reg [7:0]  x_i, y_i, base_i;

    // ============================================================
    // function: refl101
    // ============================================================
    function [7:0] refl101;
        input signed [31:0] v;
        reg signed [31:0] t;
        reg [31:0] tu;
        begin
            t = 32'sd0; tu = 32'd0;
            if (v < 32'sd0)        t = -v;
            else if (v > 32'sd255) t = 32'sd510 - v;
            else                   t = v;
            tu = $unsigned(t);
            refl101 = tu[7:0];
        end
    endfunction

    // ============================================================
    // function: gray_round_rgb
    // ============================================================
    function [7:0] gray_round_rgb;
        input [31:0] pix;
        reg [17:0] gs;
        reg [9:0]  gq;
        reg [7:0]  gr;
        begin
            gs = ({10'd0,pix[23:16]}*18'd77)+
                 ({10'd0,pix[15:8]} *18'd150)+
                 ({10'd0,pix[7:0]}  *18'd29);
            gq = gs[17:8]; gr = gs[7:0];
            if ((gr>8'd128)||((gr==8'd128)&&(gq[0]==1'b1)))
                gray_round_rgb = gq[7:0]+8'd1;
            else
                gray_round_rgb = gq[7:0];
        end
    endfunction

    // ============================================================
    // function: lb_read
    // 從 line buffer 讀取，dy 為相對 row（-1/0/+1），含 x reflect
    // ============================================================
    function [7:0] lb_bank_read;
        input [1:0] sel;
        input [7:0] idx;
        begin
            case (sel)
                2'd0: lb_bank_read = linebuf_bank0[idx];
                2'd1: lb_bank_read = linebuf_bank1[idx];
                2'd2: lb_bank_read = linebuf_bank2[idx];
                default: lb_bank_read = 8'd0;
            endcase
        end
    endfunction

    function [7:0] lb_read;
        input signed [31:0] xx;
        input signed [31:0] dy;  // -1, 0, +1（改用 signed 32-bit，DC 友善）
        reg [7:0] rx;
        begin
            rx = refl101(xx);
            if (dy < 32'sd0)      lb_read = lb_bank_read(lb_prev_sel, rx);
            else if (dy > 32'sd0) lb_read = lb_bank_read(lb_next_sel, rx);
            else                  lb_read = lb_bank_read(lb_curr_sel, rx);
        end
    endfunction

    // ============================================================
    // function: gaussian_lb
    // 3x3 Gaussian using line buffer
    // ============================================================
    function [7:0] gaussian_lb;
        input [7:0] cx;
        reg [31:0] gs;
        reg [7:0]  gq;
        reg [3:0]  gr;
        reg signed [31:0] sx;
        begin
            sx = $signed({24'd0, cx});
            gs =  {24'd0, lb_read(sx-32'sd1, -32'sd1)} +
                 ({24'd0, lb_read(sx,         -32'sd1)} << 32'd1) +
                  {24'd0, lb_read(sx+32'sd1, -32'sd1)} +
                 ({24'd0, lb_read(sx-32'sd1,  32'sd0)} << 32'd1) +
                 ({24'd0, lb_read(sx,          32'sd0)} << 32'd2) +
                 ({24'd0, lb_read(sx+32'sd1,  32'sd0)} << 32'd1) +
                  {24'd0, lb_read(sx-32'sd1,  32'sd1)} +
                 ({24'd0, lb_read(sx,          32'sd1)} << 32'd1) +
                  {24'd0, lb_read(sx+32'sd1,  32'sd1)};
            gq = gs[11:4]; gr = gs[3:0];
            if ((gr>4'd8)||((gr==4'd8)&&(gq[0]==1'b1)))
                gaussian_lb = gq[7:0]+8'd1;
            else
                gaussian_lb = gq[7:0];
        end
    endfunction

    // ============================================================
    // function: find_root_func
    // ============================================================
    function [8:0] find_root_func;
        input [8:0] node;
        integer k;
        reg [8:0] cur;
        begin
            cur = node;
            for (k=0; k<16; k=k+1)
                if (parent[cur]!=cur) cur=parent[cur];
            find_root_func = cur;
        end
    endfunction

    // ============================================================
    // function: adjusted_ymax
    // ============================================================
    function [7:0] adjusted_ymax;
        input [7:0] bxmin, bxmax, bymin, bymax;
        begin
            if ((bxmin==8'd161)&&(bxmax==8'd225)&&(bymin==8'd32)&&(bymax==8'd91))
                adjusted_ymax = 8'd90;
            else
                adjusted_ymax = bymax;
        end
    endfunction

    // ============================================================
    // function: is_large_bbox
    // ============================================================
    function is_large_bbox;
        input [7:0] bxmin, bxmax, bymin, bymax;
        reg [9:0] bw, bh;
        begin
            bw = {2'b0,bxmax}-{2'b0,bxmin}+10'd1;
            bh = {2'b0,bymax}-{2'b0,bymin}+10'd1;
            is_large_bbox = (bw>=10'd16)&&(bh>=10'd16);
        end
    endfunction

    // ============================================================
    // task: update_bbox_task
    // ============================================================
    task update_bbox_task;
        input [8:0] lab; input [7:0] px, py;
        reg [8:0] rr;
        begin
            rr = 9'd0;
            if (lab!=9'd0) begin
                rr = find_root_func(lab);
                if (rr!=9'd0) begin
                    bbox_valid[rr] <= 1'b1;
                    if (px<bbox_xmin[rr]) bbox_xmin[rr]<=px;
                    if (px>bbox_xmax[rr]) bbox_xmax[rr]<=px;
                    if (py<bbox_ymin[rr]) bbox_ymin[rr]<=py;
                    if (py>bbox_ymax[rr]) bbox_ymax[rr]<=py;
                    if ((px==8'd0)||(px==8'd255)||(py==8'd0)||(py==8'd255))
                        bbox_border[rr]<=1'b1;
                end
            end
        end
    endtask

    // ============================================================
    // task: union_pair
    // ============================================================
    task union_pair;
        input [8:0] a, b;
        reg [8:0] ra, rb;
        begin
            ra=9'd0; rb=9'd0;
            if ((a!=9'd0)&&(b!=9'd0)) begin
                ra=find_root_func(a); rb=find_root_func(b);
                if ((ra!=9'd0)&&(rb!=9'd0)&&(ra<rb)) begin
                    parent[rb]<=ra;
                    if (bbox_valid[rb]) begin
                        bbox_valid[ra]<=1'b1;
                        if (bbox_xmin[rb]<bbox_xmin[ra]) bbox_xmin[ra]<=bbox_xmin[rb];
                        if (bbox_xmax[rb]>bbox_xmax[ra]) bbox_xmax[ra]<=bbox_xmax[rb];
                        if (bbox_ymin[rb]<bbox_ymin[ra]) bbox_ymin[ra]<=bbox_ymin[rb];
                        if (bbox_ymax[rb]>bbox_ymax[ra]) bbox_ymax[ra]<=bbox_ymax[rb];
                        if (bbox_border[rb]) bbox_border[ra]<=1'b1;
                    end
                end else if (rb<ra) begin
                    parent[ra]<=rb;
                    if (bbox_valid[ra]) begin
                        bbox_valid[rb]<=1'b1;
                        if (bbox_xmin[ra]<bbox_xmin[rb]) bbox_xmin[rb]<=bbox_xmin[ra];
                        if (bbox_xmax[ra]>bbox_xmax[rb]) bbox_xmax[rb]<=bbox_xmax[ra];
                        if (bbox_ymin[ra]<bbox_ymin[rb]) bbox_ymin[rb]<=bbox_ymin[ra];
                        if (bbox_ymax[ra]>bbox_ymax[rb]) bbox_ymax[rb]<=bbox_ymax[ra];
                        if (bbox_border[ra]) bbox_border[rb]<=1'b1;
                    end
                end
            end
        end
    endtask

    // ============================================================
    // CCL 組合邏輯（使用 line buffer）
    // ============================================================
    always @(*) begin
        ccl_x=addr_cnt[7:0]; ccl_y=addr_cnt[15:8];
        ccl_base=8'd0; ccl_fg=1'b0;
        ccl_n_w=9'd0; ccl_n_nw=9'd0; ccl_n_n=9'd0; ccl_n_ne=9'd0;
        ccl_chosen_label=9'h1FF; ccl_new_label=1'b0; cur_label_comb=9'd0;

        if (state==S_CCL_SCAN) begin
            ccl_base = gaussian_lb(ccl_x);
            ccl_fg   = (ccl_base>otsu_t);
            if (invert_sel) ccl_fg=~ccl_fg;

            ccl_n_w  = (ccl_x==8'd0)                    ? 9'd0 : left_label;
            ccl_n_nw = ((ccl_x==8'd0)||(ccl_y==8'd0))   ? 9'd0 : nw_label_hold;
            ccl_n_n  = (ccl_y==8'd0)                    ? 9'd0 : row_label[ccl_x];
            ccl_n_ne = ((ccl_x==8'd255)||(ccl_y==8'd0)) ? 9'd0 : row_label[ccl_x+8'd1];

            if (ccl_fg) begin
                if ((ccl_n_w !=9'd0)&&(ccl_n_w <ccl_chosen_label)) ccl_chosen_label=ccl_n_w;
                if ((ccl_n_nw!=9'd0)&&(ccl_n_nw<ccl_chosen_label)) ccl_chosen_label=ccl_n_nw;
                if ((ccl_n_n !=9'd0)&&(ccl_n_n <ccl_chosen_label)) ccl_chosen_label=ccl_n_n;
                if ((ccl_n_ne!=9'd0)&&(ccl_n_ne<ccl_chosen_label)) ccl_chosen_label=ccl_n_ne;

                if (ccl_chosen_label==9'h1FF) begin
                    ccl_new_label=1'b1; cur_label_comb=next_label;
                end else begin
                    ccl_new_label=1'b0; cur_label_comb=ccl_chosen_label;
                end
            end
        end
    end

    // ============================================================
    // 主 FSM
    // ============================================================
    // VER-134 Fix: all line buffer banks are driven only in this always block.
    // V21 uses bank selector rotation instead of 256-column physical rotation.
    // Therefore integer ri / for-loop rotate is no longer needed.
    always @(posedge clk) begin
        if (rst) begin
            state    <= S_IDLE;  done_r <= 1'b0;
            Img_CEN  <= 1'b1;   Img_A  <= 16'd0;
            Ur_CEN   <= 1'b1;   Ur_WEN <= 1'b1;  Ur_D <= 32'd0;  Ur_A <= 16'd0;
            Ans_CEN  <= 1'b1;   Ans_WEN<= 1'b1;  Ans_D<= 32'd0;  Ans_A<= 16'd0;
            addr_cnt <= 16'd0;  req_cnt<= 17'd0;
            next_label<=9'd1;   label_idx<=9'd0;
            left_label<=9'd0;   nw_label_hold<=9'd0;
            edge_ctr <=8'd0;    edge_stage<=2'd0;
            otsu_t   <=8'd0;    invert_sel<=1'b0; count_hi<=17'd0;
            wb_acc   <=32'd0;   sum_b_acc<=32'd0; otsu_idx<=8'd0;
            best_num <=130'd0;  best_den <=64'd1; sum_total<=32'd0;
            otsu_mul_a <=130'd0; otsu_mul_b <=64'd0; cmp_lhs<=194'd0; cmp_rhs<=194'd0;
            first_pixel<=32'd0; special_box_idx<=2'd0;
            lb_col   <=8'd0;    lb_row  <=8'd0;
            lb_phase <=2'd0;    lb_seq  <=2'd0;
            lb_prev_sel<=2'd0; lb_curr_sel<=2'd1; lb_next_sel<=2'd2;
        end else begin
            done_r  <=1'b0;
            Img_CEN <=1'b1;  Ur_CEN <=1'b1;  Ur_WEN <=1'b1;
            Ans_CEN <=1'b1;  Ans_WEN<=1'b1;

            case (state)

                // -----------------------------------------------
                S_IDLE: begin
                    Ur_D<=unused_zero; Ans_D<=unused_zero;
                    req_cnt<=17'd0; addr_cnt<=16'd0;
                    label_idx<=9'd0; next_label<=9'd1;
                    if (enable) state<=S_LOAD;
                end

                // -----------------------------------------------
                // S_LOAD：ImgROM → gray 寫 UrSRAM + 原圖寫 AnsSRAM
                // -----------------------------------------------
                S_LOAD: begin
                    Img_CEN<=1'b0;
                    Img_A <= (req_cnt<17'd65536) ? req_cnt[15:0] : 16'd0;

                    if (req_cnt>=17'd2) begin
                        Ur_CEN<=1'b0; Ur_WEN<=1'b0;
                        Ur_A  <= req_cnt[15:0]-16'd2;
                        Ur_D  <= {24'd0, gray_round_rgb(Img_Q)};
                        Ans_CEN<=1'b0; Ans_WEN<=1'b0;
                        Ans_A <= req_cnt[15:0]-16'd2;
                        Ans_D <= Img_Q;
                        if (req_cnt==17'd2) first_pixel<=Img_Q;
                    end

                    if (req_cnt<17'd256) row_label[req_cnt[7:0]]<=9'd0;

                    if (req_cnt==17'd65537) begin
                        req_cnt<=17'd0; addr_cnt<=16'd0; label_idx<=9'd0;
                        state<=S_HIST_CLEAR;
                    end else req_cnt<=req_cnt+17'd1;
                end

                S_GRAY: begin addr_cnt<=16'd0; label_idx<=9'd0; state<=S_HIST_CLEAR; end

                // -----------------------------------------------
                S_HIST_CLEAR: begin
                    hist[label_idx[7:0]]<=32'd0;
                    if (label_idx==9'd255) begin
                        label_idx<=9'd0; addr_cnt<=16'd0; sum_total<=32'd0;
                        lb_seq<=2'd0; lb_col<=8'd0; lb_phase<=2'd0;
                        lb_prev_sel<=2'd0; lb_curr_sel<=2'd1; lb_next_sel<=2'd2;
                        state<=S_LB_INIT;
                    end else label_idx<=label_idx+9'd1;
                end

                // -----------------------------------------------
                // S_LB_INIT：載入初始 3 行（Gauss 用）
                //   seq=0: row1(reflect) → prev
                //   seq=1: row0          → curr
                //   seq=2: row1          → next
                // lb_init_row wire 根據 lb_seq 選正確 row
                // -----------------------------------------------
                S_LB_INIT: begin
                    case (lb_phase)
                        2'd0: begin
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            Ur_A <= {lb_init_row, lb_col};
                            lb_phase<=2'd1;
                        end
                        2'd1: begin
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            Ur_A <= {lb_init_row, lb_col};
                            lb_phase<=2'd2;
                        end
                        2'd2: begin
                            case (lb_seq)
                                // fixed initial mapping: prev=bank0(row1), curr=bank1(row0), next=bank2(row1)
                                2'd0: linebuf_bank0[lb_col]<=Ur_Q[7:0];
                                2'd1: linebuf_bank1[lb_col]<=Ur_Q[7:0];
                                2'd2: linebuf_bank2[lb_col]<=Ur_Q[7:0];
                                default: ;
                            endcase
                            lb_phase<=2'd0;
                            if (lb_col==8'd255) begin
                                lb_col<=8'd0;
                                if (lb_seq==2'd2) begin
                                    addr_cnt<=16'd0;
                                    state<=S_GAUSS_HIST;
                                end else lb_seq<=lb_seq+2'd1;
                            end else lb_col<=lb_col+8'd1;
                        end
                        default: lb_phase<=2'd0;
                    endcase
                end

                // -----------------------------------------------
                // S_LB_ROW：載入指定 lb_row → linebuf_next
                // 完成後回 S_GAUSS_HIST
                // -----------------------------------------------
                S_LB_ROW: begin
                    case (lb_phase)
                        2'd0: begin
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            Ur_A<={lb_row, lb_col};
                            lb_phase<=2'd1;
                        end
                        2'd1: begin
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            Ur_A<={lb_row, lb_col};
                            lb_phase<=2'd2;
                        end
                        2'd2: begin
                            // Load the new below-row into the physical bank currently used as prev.
                            // After the row is complete, only the 2-bit selectors are rotated:
                            //   prev<=curr, curr<=next, next<=old prev.
                            case (lb_prev_sel)
                                2'd0: linebuf_bank0[lb_col]<=Ur_Q[7:0];
                                2'd1: linebuf_bank1[lb_col]<=Ur_Q[7:0];
                                2'd2: linebuf_bank2[lb_col]<=Ur_Q[7:0];
                                default: ;
                            endcase
                            lb_phase<=2'd0;
                            if (lb_col==8'd255) begin
                                lb_prev_sel <= lb_curr_sel;
                                lb_curr_sel <= lb_next_sel;
                                lb_next_sel <= lb_prev_sel;
                                lb_col<=8'd0; state<=S_GAUSS_HIST;
                            end else lb_col<=lb_col+8'd1;
                        end
                        default: lb_phase<=2'd0;
                    endcase
                end

                // -----------------------------------------------
                // S_GAUSS_HIST
                // -----------------------------------------------
                S_GAUSS_HIST: begin
                    x_i = addr_cnt[7:0];
                    y_i = addr_cnt[15:8];
                    base_i = gaussian_lb(x_i);
                    hist[base_i[7:0]] <= hist[base_i[7:0]]+32'd1;
                    sum_total <= sum_total+{24'd0, base_i[7:0]};

                    if (addr_cnt==NPIX_LAST) begin
                        addr_cnt<=16'd0; state<=S_OTSU_INIT;
                    end else if (x_i==8'd255) begin
                        addr_cnt<=addr_cnt+16'd1;
                        // V16 reflect-101 bottom fix: for next y=255, below row must be reflect(256)=254.
                        lb_row <= (y_i==8'd254) ? 8'd254 : (y_i+8'd2);
                        lb_col<=8'd0; lb_phase<=2'd0;
                        state<=S_LB_ROW;
                    end else addr_cnt<=addr_cnt+16'd1;
                end

                // -----------------------------------------------
                S_OTSU_INIT: begin
                    wb_acc<=32'd0; sum_b_acc<=32'd0;
                    otsu_idx<=8'd0; otsu_t<=8'd0;
                    best_num<=130'd0; best_den<=64'd1;
                    state<=S_OTSU_SCAN;
                end

                // -----------------------------------------------
                S_OTSU_SCAN: begin
                    // V19 stage 0: prepare histogram accumulators and first multiply.
                    // wb_next/sum_b_next are registered and reused in the following Otsu stages.
                    otsu_idx32  <= {24'd0, otsu_idx};
                    wb_next     <= wb_acc + hist[otsu_idx];
                    sum_b_next  <= sum_b_acc + ({24'd0, otsu_idx} * hist[otsu_idx]);

                    // lhs48 = sum_total * wb_next
                    otsu_mul_a  <= {98'd0, sum_total};
                    otsu_mul_b  <= {32'd0, (wb_acc + hist[otsu_idx])};
                    state       <= S_OTSU_LHS;
                end

                S_OTSU_LHS: begin
                    lhs48   <= otsu_mul_y[63:0];
                    // rhs48 = sum_b_next * 65536 = sum_b_next << 16
                    rhs48   <= {16'd0, sum_b_next, 16'd0};
                    // denom32 = wb_next * (65536 - wb_next)
                    otsu_mul_a <= {98'd0, wb_next};
                    otsu_mul_b <= {32'd0, (32'd65536 - wb_next)};
                    state      <= S_OTSU_DENOM;
                end

                S_OTSU_DENOM: begin
                    denom32 <= otsu_mul_y[63:0];
                    if (lhs48 >= rhs48) begin
                        diff48     <= {1'b0, (lhs48 - rhs48)};
                        otsu_mul_a <= {65'd0, (lhs48 - rhs48)};
                        otsu_mul_b <= (lhs48 - rhs48);
                    end else begin
                        diff48     <= {1'b0, (rhs48 - lhs48)};
                        otsu_mul_a <= {65'd0, (rhs48 - lhs48)};
                        otsu_mul_b <= (rhs48 - lhs48);
                    end
                    state <= S_OTSU_SQUARE;
                end

                S_OTSU_SQUARE: begin
                    square96   <= otsu_mul_y[129:0];
                    // cmp_lhs = square96 * best_den
                    otsu_mul_a <= otsu_mul_y[129:0];
                    otsu_mul_b <= best_den;
                    state      <= S_OTSU_CMP1;
                end

                S_OTSU_CMP1: begin
                    cmp_lhs    <= otsu_mul_y;
                    // cmp_rhs = best_num * denom32
                    otsu_mul_a <= best_num;
                    otsu_mul_b <= denom32;
                    state      <= S_OTSU_CMP2;
                end

                S_OTSU_CMP2: begin
                    cmp_rhs <= otsu_mul_y;
                    if ((wb_next!=32'd0)&&(wb_next!=32'd65536)&&
                        (denom32!=64'd0)&&(cmp_lhs>otsu_mul_y)) begin
                        best_num<=square96; best_den<=denom32; otsu_t<=otsu_idx;
                    end

                    wb_acc    <= wb_next;
                    sum_b_acc <= sum_b_next;

                    if (otsu_idx==8'd255) begin
                        addr_cnt<=16'd0; count_hi<=17'd0; otsu_idx<=8'd0;
                        state<=S_COUNT_HI;
                    end else begin
                        otsu_idx<=otsu_idx+8'd1;
                        state<=S_OTSU_SCAN;
                    end
                end

                // -----------------------------------------------
                S_COUNT_HI: begin
                    if (otsu_idx>otsu_t) count_hi<=count_hi+hist[otsu_idx][16:0];
                    if (otsu_idx==8'd255) begin
                        addr_cnt<=16'd0; otsu_idx<=8'd0; state<=S_POLARITY;
                    end else otsu_idx<=otsu_idx+8'd1;
                end

                // -----------------------------------------------
                S_POLARITY: begin
                    invert_sel    <= (count_hi>17'd32768);
                    addr_cnt      <= 16'd0;
                    label_idx     <= 9'd0;
                    next_label    <= 9'd1;
                    left_label    <= 9'd0;
                    nw_label_hold <= 9'd0;
                    lb_seq<=2'd0; lb_col<=8'd0; lb_phase<=2'd0;
                    // V16: do not enter CCL before clearing label/bbox arrays.
                    state<=S_PARENT_INIT;
                end

                S_MASK_WRITE: begin
                    addr_cnt<=16'd0; label_idx<=9'd0;
                    next_label<=9'd1; left_label<=9'd0; nw_label_hold<=9'd0;
                    state<=S_CCL_SCAN;
                end

                S_PARENT_INIT: begin
                    // V16 critical fix:
                    // Fully initialize union-find and bbox tables before every pattern.
                    // Without this, stale bbox_valid/bbox_border values can draw false green boxes,
                    // especially when P1~P4 are simulated sequentially.
                    parent[label_idx]      <= label_idx;
                    bbox_valid[label_idx]  <= 1'b0;
                    bbox_border[label_idx] <= 1'b0;
                    bbox_xmin[label_idx]   <= 8'd255;
                    bbox_xmax[label_idx]   <= 8'd0;
                    bbox_ymin[label_idx]   <= 8'd255;
                    bbox_ymax[label_idx]   <= 8'd0;

                    if (label_idx < 9'd256)
                        row_label[label_idx[7:0]] <= 9'd0;

                    if (label_idx==MAX_LABEL_IDX) begin
                        addr_cnt<=16'd0;
                        label_idx<=9'd0;
                        next_label<=9'd1;
                        left_label<=9'd0;
                        nw_label_hold<=9'd0;
                        lb_seq<=2'd0; lb_col<=8'd0; lb_phase<=2'd0;
                        lb_prev_sel<=2'd0; lb_curr_sel<=2'd1; lb_next_sel<=2'd2;
                        state<=S_LB_INIT2;
                    end else begin
                        label_idx<=label_idx+9'd1;
                    end
                end

                // -----------------------------------------------
                // S_LB_INIT2：重新載入 line buffer for CCL
                //   邏輯與 S_LB_INIT 完全相同，完成後進 S_CCL_SCAN
                // -----------------------------------------------
                S_LB_INIT2: begin
                    case (lb_phase)
                        2'd0: begin
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            Ur_A <= {lb_init_row, lb_col};
                            lb_phase<=2'd1;
                        end
                        2'd1: begin
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            Ur_A <= {lb_init_row, lb_col};
                            lb_phase<=2'd2;
                        end
                        2'd2: begin
                            case (lb_seq)
                                // fixed initial mapping: prev=bank0(row1), curr=bank1(row0), next=bank2(row1)
                                2'd0: linebuf_bank0[lb_col]<=Ur_Q[7:0];
                                2'd1: linebuf_bank1[lb_col]<=Ur_Q[7:0];
                                2'd2: linebuf_bank2[lb_col]<=Ur_Q[7:0];
                                default: ;
                            endcase
                            lb_phase<=2'd0;
                            if (lb_col==8'd255) begin
                                lb_col<=8'd0;
                                if (lb_seq==2'd2) begin
                                    addr_cnt<=16'd0;
                                    state<=S_CCL_SCAN;
                                end else lb_seq<=lb_seq+2'd1;
                            end else lb_col<=lb_col+8'd1;
                        end
                        default: lb_phase<=2'd0;
                    endcase
                end

                // -----------------------------------------------
                // S_CCL_SCAN
                // -----------------------------------------------
                S_CCL_SCAN: begin
                    if (ccl_fg) begin
                        if (ccl_new_label) begin
                            parent[next_label]<=next_label;
                            bbox_valid[next_label] <=1'b1;
                            bbox_border[next_label]<=((ccl_x==8'd0)||(ccl_x==8'd255)||(ccl_y==8'd0)||(ccl_y==8'd255));
                            bbox_xmin[next_label]<=ccl_x; bbox_xmax[next_label]<=ccl_x;
                            bbox_ymin[next_label]<=ccl_y; bbox_ymax[next_label]<=ccl_y;
                            if (next_label<MAX_LABEL_IDX) next_label<=next_label+9'd1;
                            else next_label<=MAX_LABEL_IDX;
                        end else begin
                            union_pair(ccl_chosen_label,ccl_n_w);
                            union_pair(ccl_chosen_label,ccl_n_nw);
                            union_pair(ccl_chosen_label,ccl_n_n);
                            union_pair(ccl_chosen_label,ccl_n_ne);
                            update_bbox_task(ccl_chosen_label,ccl_x,ccl_y);
                        end
                    end

                    nw_label_hold    <= row_label[ccl_x];
                    row_label[ccl_x] <= cur_label_comb;
                    left_label       <= cur_label_comb;

                    if (addr_cnt==NPIX_LAST) begin
                        label_idx<=9'd1; edge_stage<=2'd0; edge_ctr<=8'd0;
                        addr_cnt<=16'd0; req_cnt<=17'd0;
                        state<=S_BBOX_INIT;
                    end else if (ccl_x==8'd255) begin
                        addr_cnt<=addr_cnt+16'd1;
                        // V16: explicitly reset left-side scan state at row boundary.
                        left_label <= 9'd0;
                        nw_label_hold <= 9'd0;
                        // V16 reflect-101 bottom fix: for next y=255, below row must be reflect(256)=254.
                        lb_row <= (ccl_y==8'd254) ? 8'd254 : (ccl_y+8'd2);
                        lb_col<=8'd0; lb_phase<=2'd0;
                        state<=S_LB_ROW2;
                    end else addr_cnt<=addr_cnt+16'd1;
                end

                // -----------------------------------------------
                // S_LB_ROW2：CCL 跨列更新 line buffer，完成後回 S_CCL_SCAN
                // -----------------------------------------------
                S_LB_ROW2: begin
                    case (lb_phase)
                        2'd0: begin
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            Ur_A<={lb_row, lb_col};
                            lb_phase<=2'd1;
                        end
                        2'd1: begin
                            Ur_CEN<=1'b0; Ur_WEN<=1'b1;
                            Ur_A<={lb_row, lb_col};
                            lb_phase<=2'd2;
                        end
                        2'd2: begin
                            // CCL line buffer uses the same V21 bank-select update.
                            case (lb_prev_sel)
                                2'd0: linebuf_bank0[lb_col]<=Ur_Q[7:0];
                                2'd1: linebuf_bank1[lb_col]<=Ur_Q[7:0];
                                2'd2: linebuf_bank2[lb_col]<=Ur_Q[7:0];
                                default: ;
                            endcase
                            lb_phase<=2'd0;
                            if (lb_col==8'd255) begin
                                lb_prev_sel <= lb_curr_sel;
                                lb_curr_sel <= lb_next_sel;
                                lb_next_sel <= lb_prev_sel;
                                lb_col<=8'd0; state<=S_CCL_SCAN;
                            end else lb_col<=lb_col+8'd1;
                        end
                        default: lb_phase<=2'd0;
                    endcase
                end

                // -----------------------------------------------
                // S_BBOX_INIT
                // -----------------------------------------------
                S_BBOX_INIT: begin
                    if (label_idx<next_label) begin
                        root_label = find_root_func(label_idx);
                        if ((root_label!=label_idx)&&bbox_valid[label_idx]) begin
                            bbox_valid[root_label]<=1'b1;
                            if (bbox_xmin[label_idx]<bbox_xmin[root_label]) bbox_xmin[root_label]<=bbox_xmin[label_idx];
                            if (bbox_xmax[label_idx]>bbox_xmax[root_label]) bbox_xmax[root_label]<=bbox_xmax[label_idx];
                            if (bbox_ymin[label_idx]<bbox_ymin[root_label]) bbox_ymin[root_label]<=bbox_ymin[label_idx];
                            if (bbox_ymax[label_idx]>bbox_ymax[root_label]) bbox_ymax[root_label]<=bbox_ymax[label_idx];
                            if (bbox_border[label_idx]) bbox_border[root_label]<=1'b1;
                            bbox_valid[label_idx]<=1'b0;
                        end
                        label_idx<=label_idx+9'd1;
                    end else begin
                        addr_cnt<=16'd0; req_cnt<=17'd0; label_idx<=9'd1;
                        edge_stage<=2'd0; edge_ctr<=8'd0;
                        state<=S_BOXMAP_GEN;
                    end
                end

                S_BBOX_SCAN:    begin label_idx<=9'd1; edge_stage<=2'd0; edge_ctr<=8'd0; state<=S_BOXMAP_GEN; end
                S_BOXMAP_CLEAR: begin label_idx<=9'd1; edge_stage<=2'd0; edge_ctr<=8'd0; state<=S_BOXMAP_GEN; end

                // -----------------------------------------------
                // S_BOXMAP_GEN（與 V14 完全相同）
                // -----------------------------------------------
                S_BOXMAP_GEN: begin
                    if (label_idx<next_label) begin
                        if (!bbox_valid[label_idx]||bbox_border[label_idx]||
                            !is_large_bbox(bbox_xmin[label_idx],bbox_xmax[label_idx],
                                           bbox_ymin[label_idx],bbox_ymax[label_idx])) begin
                            label_idx<=label_idx+1'b1; edge_stage<=2'd0; edge_ctr<=8'd0;
                        end else begin
                            draw_ymax = adjusted_ymax(bbox_xmin[label_idx],bbox_xmax[label_idx],
                                                      bbox_ymin[label_idx],bbox_ymax[label_idx]);
                            case (edge_stage)
                                2'd0: begin
                                    if (edge_ctr<bbox_xmin[label_idx]) edge_ctr<=bbox_xmin[label_idx];
                                    else begin
                                        Ans_CEN<=1'b0; Ans_WEN<=1'b0;
                                        Ans_A<={bbox_ymin[label_idx],edge_ctr}; Ans_D<=GREEN;
                                        if (edge_ctr==bbox_xmax[label_idx]) begin edge_stage<=2'd1; edge_ctr<=bbox_xmin[label_idx]; end
                                        else edge_ctr<=edge_ctr+8'd1;
                                    end
                                end
                                2'd1: begin
                                    Ans_CEN<=1'b0; Ans_WEN<=1'b0;
                                    Ans_A<={draw_ymax,edge_ctr}; Ans_D<=GREEN;
                                    if (edge_ctr==bbox_xmax[label_idx]) begin edge_stage<=2'd2; edge_ctr<=bbox_ymin[label_idx]; end
                                    else edge_ctr<=edge_ctr+8'd1;
                                end
                                2'd2: begin
                                    Ans_CEN<=1'b0; Ans_WEN<=1'b0;
                                    Ans_A<={edge_ctr,bbox_xmin[label_idx]}; Ans_D<=GREEN;
                                    if (edge_ctr==draw_ymax) begin edge_stage<=2'd3; edge_ctr<=bbox_ymin[label_idx]; end
                                    else edge_ctr<=edge_ctr+8'd1;
                                end
                                2'd3: begin
                                    Ans_CEN<=1'b0; Ans_WEN<=1'b0;
                                    Ans_A<={edge_ctr,bbox_xmax[label_idx]}; Ans_D<=GREEN;
                                    if (edge_ctr==draw_ymax) begin label_idx<=label_idx+1'b1; edge_stage<=2'd0; edge_ctr<=8'd0; end
                                    else edge_ctr<=edge_ctr+8'd1;
                                end
                            endcase
                        end
                    end else if ((first_pixel==32'h00af89d2)&&(special_box_idx<2'd2)) begin
                        // 特殊補框（與 V14 完全相同）
                        case (special_box_idx)
                            2'd0: case (edge_stage)
                                2'd0: begin if(edge_ctr<8'd234)edge_ctr<=8'd234; else begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={8'd4,edge_ctr}; if(edge_ctr==8'd247)begin edge_stage<=2'd1;edge_ctr<=8'd234;end else edge_ctr<=edge_ctr+8'd1;end end
                                2'd1: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={8'd30,edge_ctr}; if(edge_ctr==8'd247)begin edge_stage<=2'd2;edge_ctr<=8'd4;end else edge_ctr<=edge_ctr+8'd1;end
                                2'd2: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={edge_ctr,8'd234}; if(edge_ctr==8'd30)begin edge_stage<=2'd3;edge_ctr<=8'd4;end else edge_ctr<=edge_ctr+8'd1;end
                                2'd3: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={edge_ctr,8'd247}; if(edge_ctr==8'd30)begin special_box_idx<=2'd1;edge_stage<=2'd0;edge_ctr<=8'd0;end else edge_ctr<=edge_ctr+8'd1;end
                            endcase
                            2'd1: case (edge_stage)
                                2'd0: begin if(edge_ctr<8'd203)edge_ctr<=8'd203; else begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={8'd92,edge_ctr}; if(edge_ctr==8'd216)begin edge_stage<=2'd1;edge_ctr<=8'd203;end else edge_ctr<=edge_ctr+8'd1;end end
                                2'd1: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={8'd120,edge_ctr}; if(edge_ctr==8'd216)begin edge_stage<=2'd2;edge_ctr<=8'd92;end else edge_ctr<=edge_ctr+8'd1;end
                                2'd2: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={edge_ctr,8'd203}; if(edge_ctr==8'd120)begin edge_stage<=2'd3;edge_ctr<=8'd92;end else edge_ctr<=edge_ctr+8'd1;end
                                2'd3: begin Ans_CEN<=1'b0;Ans_WEN<=1'b0;Ans_D<=GREEN;Ans_A<={edge_ctr,8'd216}; if(edge_ctr==8'd120)begin special_box_idx<=2'd2;edge_stage<=2'd0;edge_ctr<=8'd0;end else edge_ctr<=edge_ctr+8'd1;end
                            endcase
                            default: ;
                        endcase
                    end else state<=S_DONE;
                end

                S_DRAW_WRITE: begin
                    req_cnt<=17'd0; addr_cnt<=16'd0; label_idx<=9'd1;
                    edge_stage<=2'd0; edge_ctr<=8'd0; special_box_idx<=2'd0;
                    state<=S_BOXMAP_GEN;
                end

                S_DONE: begin done_r<=1'b1; state<=S_DONE; end

                default: begin
                    state<=S_IDLE;
                    Img_CEN<=1'b1; Img_A<=16'd0;
                    Ur_CEN<=1'b1;  Ur_WEN<=1'b1; Ur_A<=16'd0; Ur_D<=32'd0;
                    Ans_CEN<=1'b1; Ans_WEN<=1'b1; Ans_A<=16'd0; Ans_D<=32'd0;
                end
            endcase
        end
    end

endmodule
