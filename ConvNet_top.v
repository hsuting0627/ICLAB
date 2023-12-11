module ConvNet_top // DO NOT CHANGE THE TOP MODULE NAME!!!!
#(
  parameter CH_NUM = 4,
  parameter ACT_PER_ADDR = 4,
  parameter BW_PER_ACT = 12,
  parameter WEIGHT_PER_ADDR = 9,
  parameter BIAS_PER_ADDR = 1,
  parameter BW_PER_PARAM = 8
) 
(
  input clk,
  input srst_n,
  input enable,
  output reg valid,
  
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a0,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a1,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a2,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a3,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b0,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b1,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b2,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b3,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_c0,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_c1,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_c2,
  input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_c3,
  input [WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] sram_rdata_weight,
  input [BIAS_PER_ADDR*BW_PER_PARAM-1:0] sram_rdata_bias, 
  
  output reg [6-1:0] sram_addr_a0,
  output reg [6-1:0] sram_addr_a1,
  output reg [6-1:0] sram_addr_a2,
  output reg [6-1:0] sram_addr_a3,
  output reg [5-1:0] sram_addr_b0,
  output reg [5-1:0] sram_addr_b1,
  output reg [5-1:0] sram_addr_b2,
  output reg [5-1:0] sram_addr_b3,
  output reg [5-1:0] sram_addr_c0,
  output reg [5-1:0] sram_addr_c1,
  output reg [5-1:0] sram_addr_c2,
  output reg [5-1:0] sram_addr_c3,
  output reg [9-1:0] sram_raddr_weight,
  output reg [6-1:0] sram_raddr_bias,
  
  output reg sram_wen_a0,
  output reg sram_wen_a1,
  output reg sram_wen_a2,
  output reg sram_wen_a3,
  output reg sram_wen_b0,
  output reg sram_wen_b1,
  output reg sram_wen_b2,
  output reg sram_wen_b3,
  output reg sram_wen_c0,
  output reg sram_wen_c1,
  output reg sram_wen_c2,
  output reg sram_wen_c3,
    
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_a0,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_a1,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_a2,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_a3,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_b0,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_b1,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_b2,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_b3,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_c0,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_c1,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_c2,  
  output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_c3,  
    
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_a0,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_a1,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_a2,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_a3,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_b0,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_b1,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_b2,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_b3,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_c0,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_c1,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_c2,
  output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_c3
  
);
reg valid_next;


// //wire
// conv1_ctrl#(
// .CH_NUM(CH_NUM),
// .ACT_PER_ADDR(ACT_PER_ADDR),
// .BW_PER_ACT(BW_PER_ACT),
// .WEIGHT_PER_ADDR(WEIGHT_PER_ADDR), 
// .BIAS_PER_ADDR(BIAS_PER_ADDR),
// .BW_PER_PARAM(BW_PER_PARAM)
// ) conv1_ctrl
// (
// .clk(clk),
// .srst_n(srst_n),
// .conv1_en(conv1_en),
// .sram_rdata_a0(sram_rdata_a0),
// .sram_rdata_a1(sram_rdata_a1),
// .sram_rdata_a2(sram_rdata_a2),
// .sram_rdata_a3(sram_rdata_a3),
// .sram_rdata_weight(sram_rdata_weight),
// .sram_rdata_bias(sram_rdata_bias), 
// .sram_addr_c0(),
// .sram_addr_c1(),
// .sram_addr_c2(),
// .sram_addr_c3(),
// .sram_raddr_weight(),
// .sram_raddr_bias(),
// .sram_wen_c0(),
// .sram_wen_c1(),
// .sram_wen_c2(),
// .sram_wen_c3(),
// .sram_wordmask_c0(),  
// .sram_wordmask_c1(),  
// .sram_wordmask_c2(),  
// .sram_wordmask_c3(),  
// .sram_wdata_c0(),
// .sram_wdata_c1(),
// .sram_wdata_c2(),
// .sram_wdata_c3()
// )


reg [WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] sram_rdata_weight_reg;
reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_c;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_c;
reg [3:0] mask_partial;
reg [4*BW_PER_ACT-1:0] wdata_partial;
wire [BW_PER_ACT-1:0] mul_out; // 12bit

reg [1:0] state, state_n;
reg [1:0] state_global, state_global_n;
reg [7:0] cnt, cnt_next;
reg [2:0] cnt_read_col, cnt_read_col_next;
reg [2:0] cnt_read_row, cnt_read_row_next;
reg [2:0] cnt_compute_col, cnt_compute_col_next;
reg [2:0] cnt_compute_row, cnt_compute_row_next;
reg [1:0] cnt_compute, cnt_compute_next;
reg [1:0] cnt_wait, cnt_wait_next;
reg [2:0] cnt_ofmap, cnt_ofmap_next;

reg [WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] weight [0:3];
reg [WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] weight_next [0:3];
reg [BIAS_PER_ADDR*BW_PER_PARAM-1:0] bias;
reg [BIAS_PER_ADDR*BW_PER_PARAM-1:0] bias_next;

reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] map0;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] map1;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] map2;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] map3;

reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a0_reg;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a1_reg;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a2_reg;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a3_reg;

integer i;
// Mul Block
mul #(
.CH_NUM(CH_NUM),
.ACT_PER_ADDR(ACT_PER_ADDR),
.BW_PER_ACT(BW_PER_ACT),
.WEIGHT_PER_ADDR(WEIGHT_PER_ADDR), 
.BIAS_PER_ADDR(BIAS_PER_ADDR),
.BW_PER_PARAM(BW_PER_PARAM)
) mul
(
.weight0(weight[0]), // ch0
.weight1(weight[1]), // ch1
.weight2(weight[2]), // ch2
.weight3(weight[3]), // ch3
.map0(map0),
.map1(map1),
.map2(map2),
.map3(map3),
.bias(bias),
.cnt(cnt_compute),
.out(mul_out)
);

always @(posedge clk) begin
  if(~srst_n) begin
    cnt_read_col <= 0;
    cnt_read_row <= 0;
    cnt_compute_col <= 0;
    cnt_compute_row <= 0;
    cnt_compute <= 0;
    cnt_wait <= 0;
    cnt_ofmap <= 0;    
    cnt <= 0;
    sram_rdata_weight_reg <= 0;
    sram_rdata_a0_reg <= 0;
    sram_rdata_a1_reg <= 0;
    sram_rdata_a2_reg <= 0;
    sram_rdata_a3_reg <= 0;
    valid <= 0;
  end
  else begin
    for(i = 0; i < 4; i = i + 1) begin
      weight[i] <= weight_next[i];
    end
      cnt <= cnt_next;
      bias <= bias_next;
      cnt_read_col <= cnt_read_col_next;
      cnt_read_row <= cnt_read_row_next;
      cnt_compute_col <= cnt_compute_col_next;
      cnt_compute_row <= cnt_compute_row_next;
      cnt_compute <= cnt_compute_next;
      cnt_wait <= cnt_wait_next;
      cnt_ofmap <= cnt_ofmap_next;
      sram_rdata_weight_reg <= sram_rdata_weight;
    sram_rdata_a0_reg <= sram_rdata_a0;
    sram_rdata_a1_reg <= sram_rdata_a1;
    sram_rdata_a2_reg <= sram_rdata_a2;
    sram_rdata_a3_reg <= sram_rdata_a3;
    valid <= valid_next;
  end
end
localparam IDLE = 2'd0, LOAD = 2'd1, COMPUTE = 2'd2, CONV1 = 2'd3;
always @* begin
  case(state_global)
    IDLE : state_global_n = enable ? CONV1 : IDLE;
  endcase
end

reg conv1_en;
always @* begin
  case (state_global)
    CONV1 : conv1_en = 1;
    default : conv1_en = 0;
  endcase
end
// conv1_en should be enable
//======================================================
// FSM for conv1 entire Feature Map
// LOAD: Bias 
// Compute: LOAD Weight and Feature Map
//======================================================

always@(posedge clk) begin
	if(~srst_n) begin
		state <= IDLE;
    state_global <= IDLE;
	end
	else begin
	 	state <= state_n;
    state_global <= state_global_n;
	end
end

always@* begin
	case(state)
		IDLE: state_n = conv1_en ? LOAD : IDLE; // conv1_en should come from System FSM 
		LOAD: state_n = cnt == 5 ? COMPUTE : LOAD;  // CNT == 5?
		COMPUTE: begin
			if(cnt_compute_row == 5 && cnt_compute_col == 5 && cnt_compute == 3) begin
				if(cnt_ofmap == 7) state_n = IDLE; // 3_> 7 weight
				else state_n = LOAD;
			end
			else state_n = COMPUTE;
		end
		default: state_n = IDLE; 
	endcase
end

always @* begin
    case (state)
        IDLE: begin 
          cnt_next = 0; 
          cnt_wait_next = 0;
          cnt_read_row_next = 0;
          cnt_read_col_next = 0;
          cnt_ofmap_next = 0;
          cnt_compute_next = 0;
          cnt_compute_row_next = 0;
          cnt_compute_col_next = 0;
          valid_next = 0;
        end
        LOAD: begin
            cnt_next = (cnt == 5) ? 0 : (cnt + 1); // reset 5-> 9
            if(cnt >= 4) cnt_wait_next = cnt_wait + 1;
        end
        COMPUTE: begin
            if(cnt_compute_row == 5 && cnt_compute_col == 5 && cnt_compute == 3) begin
              cnt_ofmap_next = cnt_ofmap + 1;
              cnt_compute_next = 0;
              cnt_next = 0;
              cnt_read_col_next = 0;
              cnt_read_row_next = 0;	
              cnt_compute_next = 0;
              cnt_compute_col_next = 0;
              cnt_compute_row_next = 0;
              cnt_wait_next = 0;
              if(cnt_ofmap == 7) valid_next = 1;
              else valid_next = 0;
            end
            else begin
                cnt_next = cnt + 1;
                cnt_compute_next = cnt_compute + 1;
                cnt_wait_next = cnt_wait + 1;
                if(cnt_wait == 3) begin
                    if(cnt_read_col == 5) begin
                        cnt_read_row_next = cnt_read_row + 1; 
                        cnt_read_col_next = 0;
                    end
                    else begin
                        cnt_read_row_next = cnt_read_row;
                        cnt_read_col_next = cnt_read_col + 1;
                    end
                end
                if(cnt_compute == 3) begin  // finish 4x4 finsh 36's
                    if(cnt_compute_col == 5) begin
                        cnt_compute_row_next = cnt_compute_row + 1;
                        cnt_compute_col_next = 0;
                    end
                    else begin
                        cnt_compute_row_next = cnt_compute_row;
                        cnt_compute_col_next = cnt_compute_col + 1;
                    end
                end
            end
        end
    endcase
end
// Read data from UNSHUFFLE SRAM A
always @* begin
    if(conv1_en) begin
        sram_addr_a0 = 4 * ((cnt_read_row + 1) >> 1) + ((cnt_read_col + 1) >> 1);
        sram_addr_a1 = 4 * ((cnt_read_row + 1) >> 1) + (cnt_read_col >> 1);
        sram_addr_a2 = 4 * (cnt_read_row >> 1) + ((cnt_read_col + 1) >> 1);
        sram_addr_a3 = 4 * (cnt_read_row >> 1) + (cnt_read_col >> 1);
    end
end

// cnt of map = 0, 1, 2, ... 7
always @* begin
	if(conv1_en) begin
        case(state)
            LOAD: begin
                if(cnt >= 2) begin
                    weight_next[cnt-2] = sram_rdata_weight_reg; // read 0, 1, 2, 3
                    bias_next = sram_rdata_bias;
                end
            end
        endcase
    end
end

// READ WEIGHT AND BIAS FOR ONE 

always @* begin
	if(conv1_en) begin
        case(state)
            LOAD: begin
                sram_raddr_weight = cnt + 4 * cnt_ofmap;
			          sram_raddr_bias = cnt_ofmap; 
            end
        endcase
    end
end

// map reposition
always@* begin
	map0 = sram_rdata_a0_reg;
	map1 = sram_rdata_a1_reg;
	map2 = sram_rdata_a2_reg;
	map3 = sram_rdata_a3_reg;
	if(conv1_en) begin
		if(cnt_compute_row[0]) begin
			if(cnt_compute_col[0]) begin
				map0 = sram_rdata_a3_reg;
				map1 = sram_rdata_a2_reg;
				map2 = sram_rdata_a1_reg;
				map3 = sram_rdata_a0_reg;
			end
			else begin
				map0 = sram_rdata_a2_reg;
				map1 = sram_rdata_a3_reg;
				map2 = sram_rdata_a0_reg;
				map3 = sram_rdata_a1_reg;
			end
		end
		else begin
			if(cnt_compute_col[0]) begin
				map0 = sram_rdata_a1_reg;
				map1 = sram_rdata_a0_reg;
				map2 = sram_rdata_a3_reg;
				map3 = sram_rdata_a2_reg;
			end
			else begin
				map0 = sram_rdata_a0_reg;
				map1 = sram_rdata_a1_reg;
				map2 = sram_rdata_a2_reg;
				map3 = sram_rdata_a3_reg;
			end
		end	
	end
end

always @* begin
	if(conv1_en) begin
		case(state)
			COMPUTE: begin
        sram_wen_c0 = 1;
        sram_wen_c1 = 1;
        sram_wen_c2 = 1;
        sram_wen_c3 = 1;
				if(cnt_compute_row == 0 & cnt_compute_col == 0) begin
					wdata_partial = {36'b0, mul_out}; // 155:144
					mask_partial = 4'b1110; // only write LSB
					sram_addr_c0 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 0 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c0 = 0; end
						2'd1 : begin sram_wen_c2 = 0; end
						2'd2 : begin sram_wen_c1 = 0; end
						2'd3 : begin sram_wen_c3 = 0; end
					endcase
				end
				if(cnt_compute_row == 0 & cnt_compute_col == 1) begin
					wdata_partial = {24'b0, mul_out, 12'b0}; // 167:156
					mask_partial = 4'b1101;
					sram_addr_c0 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 1 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c1 = 0; end
						2'd1 : begin sram_wen_c3 = 0; end
						2'd2 : begin sram_wen_c0 = 0; end
						2'd3 : begin sram_wen_c2 = 0; end
					endcase
				end
				if(cnt_compute_row == 0 & cnt_compute_col == 2) begin
					wdata_partial = {36'b0, mul_out}; // 155:144
					mask_partial = 4'b1110; // only write LSB
					sram_addr_c0 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 1 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c1 = 0; end
						2'd1 : begin sram_wen_c3 = 0; end
						2'd2 : begin sram_wen_c0 = 0; end
						2'd3 : begin sram_wen_c2 = 0; end
					endcase
				end
				if(cnt_compute_row == 0 & cnt_compute_col == 3) begin
					wdata_partial = {24'b0, mul_out, 12'b0}; // 167:156
					mask_partial = 4'b1101;
					sram_addr_c0 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 2 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c0 = 0; end
						2'd1 : begin sram_wen_c2 = 0; end
						2'd2 : begin sram_wen_c1 = 0; end
						2'd3 : begin sram_wen_c3 = 0; end
					endcase
				end
				if(cnt_compute_row == 0 & cnt_compute_col == 4) begin
					wdata_partial = {36'b0, mul_out}; // 155:144
					mask_partial = 4'b1110; // only write LSB
					sram_addr_c0 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 2 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c0 = 0; end
						2'd1 : begin sram_wen_c2 = 0; end
						2'd2 : begin sram_wen_c1 = 0; end
						2'd3 : begin sram_wen_c3 = 0; end
					endcase
				end
				if(cnt_compute_row == 0 & cnt_compute_col == 5) begin
					wdata_partial = {24'b0, mul_out, 12'b0}; // 167:156
					mask_partial = 4'b1101;
					sram_addr_c0 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 0 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c1 = 0; end
						2'd1 : begin sram_wen_c3 = 0; end
						2'd2 : begin sram_wen_c0 = 0; end
						2'd3 : begin sram_wen_c2 = 0; end
					endcase
				end
				if(cnt_compute_row == 1 & cnt_compute_col == 0) begin
					wdata_partial = {12'b0, mul_out, 24'b0}; // 179:168
					mask_partial = 4'b1011;
					sram_addr_c0 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 3 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c2 = 0; end
						2'd1 : begin sram_wen_c0 = 0; end
						2'd2 : begin sram_wen_c3 = 0; end
						2'd3 : begin sram_wen_c1 = 0; end
					endcase
				end
				if(cnt_compute_row == 1 & cnt_compute_col == 1) begin
					wdata_partial = {mul_out, 36'b0}; // 191:180
					mask_partial = 4'b0111; // only write MSB 
					sram_addr_c0 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 5 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c3 = 0; end
						2'd1 : begin sram_wen_c1 = 0; end
						2'd2 : begin sram_wen_c2 = 0; end
						2'd3 : begin sram_wen_c0 = 0; end
					endcase
				end		
				if(cnt_compute_row == 1 & cnt_compute_col == 2) begin
					wdata_partial = {12'b0, mul_out, 24'b0}; // 179:168
					mask_partial = 4'b1011;
					sram_addr_c0 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 5 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c3 = 0; end //g
						2'd1 : begin sram_wen_c1 = 0; end //b
						2'd2 : begin sram_wen_c2 = 0; end //y
						2'd3 : begin sram_wen_c0 = 0; end //o
					endcase
				end			
				if(cnt_compute_row == 1 & cnt_compute_col == 3) begin
					wdata_partial = {mul_out, 36'b0}; // 191:180
					mask_partial = 4'b0111; // only write MSB
					sram_addr_c0 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 6 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c2 = 0; end //y
						2'd1 : begin sram_wen_c0 = 0; end //o
						2'd2 : begin sram_wen_c3 = 0; end //g
						2'd3 : begin sram_wen_c1 = 0; end //b
					endcase
				end					
				if(cnt_compute_row == 1 & cnt_compute_col == 4) begin
					wdata_partial = {12'b0, mul_out, 24'b0}; // 179:168
					mask_partial = 4'b1011;
					sram_addr_c0 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 6 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c2 = 0; end //y
						2'd1 : begin sram_wen_c0 = 0; end //o
						2'd2 : begin sram_wen_c3 = 0; end //g
						2'd3 : begin sram_wen_c1 = 0; end //b
					endcase
				end				
				if(cnt_compute_row == 1 & cnt_compute_col == 5) begin
					wdata_partial = {mul_out, 36'b0}; // 191:180
					mask_partial = 4'b0111; // only write MSB 
					sram_addr_c0 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 3 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c3 = 0; end //g
						2'd1 : begin sram_wen_c1 = 0; end //b
						2'd2 : begin sram_wen_c2 = 0; end //y
						2'd3 : begin sram_wen_c0 = 0; end //o
					endcase
				end					
				if(cnt_compute_row == 2 & cnt_compute_col == 0) begin
					wdata_partial = {36'b0, mul_out}; // 155:144
					mask_partial = 4'b1110; // only write LSB
					sram_addr_c0 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 3 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c2 = 0; end
						2'd1 : begin sram_wen_c0 = 0; end
						2'd2 : begin sram_wen_c3 = 0; end
						2'd3 : begin sram_wen_c1 = 0; end
					endcase
				end
				if(cnt_compute_row == 2 & cnt_compute_col == 1) begin
					wdata_partial = {24'b0, mul_out, 12'b0}; // 1
					mask_partial = 4'b1101;
					sram_addr_c0 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 5 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c3 = 0; end
						2'd1 : begin sram_wen_c1 = 0; end
						2'd2 : begin sram_wen_c2 = 0; end
						2'd3 : begin sram_wen_c0 = 0; end
					endcase
				end		
				if(cnt_compute_row == 2 & cnt_compute_col == 2) begin
					wdata_partial = {36'b0, mul_out}; // 155:144
					mask_partial = 4'b1110; // only write LSB
					sram_addr_c0 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 5 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 5 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c3 = 0; end //g
						2'd1 : begin sram_wen_c1 = 0; end //b
						2'd2 : begin sram_wen_c2 = 0; end //y
						2'd3 : begin sram_wen_c0 = 0; end //o
					endcase
				end			
				if(cnt_compute_row == 2 & cnt_compute_col == 3) begin
					wdata_partial = {24'b0, mul_out, 12'b0}; // 1
					mask_partial = 4'b1101;
					sram_addr_c0 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 6 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c2 = 0; end //y
						2'd1 : begin sram_wen_c0 = 0; end //o
						2'd2 : begin sram_wen_c3 = 0; end //g
						2'd3 : begin sram_wen_c1 = 0; end //b
					endcase
				end					
				if(cnt_compute_row == 2 & cnt_compute_col == 4) begin
					wdata_partial = {36'b0, mul_out}; // 155:144
					mask_partial = 4'b1110; // only write LSB
					sram_addr_c0 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 6 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 6 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c2 = 0; end //y
						2'd1 : begin sram_wen_c0 = 0; end //o
						2'd2 : begin sram_wen_c3 = 0; end //g
						2'd3 : begin sram_wen_c1 = 0; end //b
					endcase
				end				
				if(cnt_compute_row == 2 & cnt_compute_col == 5) begin
					wdata_partial = {24'b0, mul_out, 12'b0}; // 1
					mask_partial = 4'b1101;
					sram_addr_c0 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 3 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 3 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c3 = 0; end //g
						2'd1 : begin sram_wen_c1 = 0; end //b
						2'd2 : begin sram_wen_c2 = 0; end //y
						2'd3 : begin sram_wen_c0 = 0; end //o
					endcase
				end				
				if(cnt_compute_row == 3 & cnt_compute_col == 0) begin
					wdata_partial = {12'b0, mul_out, 24'b0}; // 179:168(2)
					mask_partial = 4'b1011;
					sram_addr_c0 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 4 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c0 = 0; end
						2'd1 : begin sram_wen_c2 = 0; end
						2'd2 : begin sram_wen_c1 = 0; end
						2'd3 : begin sram_wen_c3 = 0; end
					endcase
				end
				if(cnt_compute_row == 3 & cnt_compute_col == 1) begin
					wdata_partial = {mul_out, 36'b0}; // 191:180 (3)
					mask_partial = 4'b0111; // only write MSB 
					sram_addr_c0 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 7 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c1 = 0; end
						2'd1 : begin sram_wen_c3 = 0; end
						2'd2 : begin sram_wen_c0 = 0; end
						2'd3 : begin sram_wen_c2 = 0; end
					endcase
				end
				if(cnt_compute_row == 3 & cnt_compute_col == 2) begin
					wdata_partial = {12'b0, mul_out, 24'b0}; // 179:168(2)
					mask_partial = 4'b1011;
					sram_addr_c0 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 7 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c1 = 0; end
						2'd1 : begin sram_wen_c3 = 0; end
						2'd2 : begin sram_wen_c0 = 0; end
						2'd3 : begin sram_wen_c2 = 0; end
					endcase
				end
				if(cnt_compute_row == 3 & cnt_compute_col == 3) begin
					wdata_partial = {mul_out, 36'b0}; // 191:180 (3)
					mask_partial = 4'b0111; // only write MSB 
					sram_addr_c0 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 8 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c0 = 0; end
						2'd1 : begin sram_wen_c2 = 0; end
						2'd2 : begin sram_wen_c1 = 0; end
						2'd3 : begin sram_wen_c3 = 0; end
					endcase
				end
				if(cnt_compute_row == 3 & cnt_compute_col == 4) begin
					wdata_partial = {12'b0, mul_out, 24'b0}; // 179:168(2)
					mask_partial = 4'b1011;
					sram_addr_c0 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 8 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c0 = 0; end
						2'd1 : begin sram_wen_c2 = 0; end
						2'd2 : begin sram_wen_c1 = 0; end
						2'd3 : begin sram_wen_c3 = 0; end
					endcase
				end
				if(cnt_compute_row == 3 & cnt_compute_col == 5) begin
					wdata_partial = {mul_out, 36'b0}; // 191:180 (3)
					mask_partial = 4'b0111; // only write MSB 
					sram_addr_c0 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 4 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c1 = 0; end
						2'd1 : begin sram_wen_c3 = 0; end
						2'd2 : begin sram_wen_c0 = 0; end
						2'd3 : begin sram_wen_c2 = 0; end
					endcase
				end	
				if(cnt_compute_row == 4 & cnt_compute_col == 0) begin
					wdata_partial = {36'b0, mul_out}; // 155:144(0)
					mask_partial = 4'b1110; // only write LSB
					sram_addr_c0 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 4 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c0 = 0; end
						2'd1 : begin sram_wen_c2 = 0; end
						2'd2 : begin sram_wen_c1 = 0; end
						2'd3 : begin sram_wen_c3 = 0; end
					endcase
				end
				if(cnt_compute_row == 4 & cnt_compute_col == 1) begin
					wdata_partial = {24'b0, mul_out, 12'b0}; // 1
					mask_partial = 4'b1101;
					sram_addr_c0 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 7 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c1 = 0; end
						2'd1 : begin sram_wen_c3 = 0; end
						2'd2 : begin sram_wen_c0 = 0; end
						2'd3 : begin sram_wen_c2 = 0; end
					endcase
				end
				if(cnt_compute_row == 4 & cnt_compute_col == 2) begin
					wdata_partial = {36'b0, mul_out}; // 155:144(0)
					mask_partial = 4'b1110; // only write LSB
					sram_addr_c0 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 7 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 7 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c1 = 0; end
						2'd1 : begin sram_wen_c3 = 0; end
						2'd2 : begin sram_wen_c0 = 0; end
						2'd3 : begin sram_wen_c2 = 0; end
					endcase
				end
				if(cnt_compute_row == 4 & cnt_compute_col == 3) begin
					wdata_partial = {24'b0, mul_out, 12'b0}; // 1
					mask_partial = 4'b1101;
					sram_addr_c0 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 8 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c0 = 0; end
						2'd1 : begin sram_wen_c2 = 0; end
						2'd2 : begin sram_wen_c1 = 0; end
						2'd3 : begin sram_wen_c3 = 0; end
					endcase
				end
				if(cnt_compute_row == 4 & cnt_compute_col == 4) begin
					wdata_partial = {36'b0, mul_out}; // 155:144(0)
					mask_partial = 4'b1110; // only write LSB
					sram_addr_c0 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 8 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 8 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c0 = 0; end
						2'd1 : begin sram_wen_c2 = 0; end
						2'd2 : begin sram_wen_c1 = 0; end
						2'd3 : begin sram_wen_c3 = 0; end
					endcase
				end
				if(cnt_compute_row == 4 & cnt_compute_col == 5) begin
					wdata_partial = {24'b0, mul_out, 12'b0}; // 1
					mask_partial = 4'b1101;
					sram_addr_c0 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 4 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 4 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c1 = 0; end
						2'd1 : begin sram_wen_c3 = 0; end
						2'd2 : begin sram_wen_c0 = 0; end
						2'd3 : begin sram_wen_c2 = 0; end
					endcase
				end		
				if(cnt_compute_row == 5 & cnt_compute_col == 0) begin
					wdata_partial = {12'b0, mul_out, 24'b0}; // 179:168(2)
					mask_partial = 4'b1011;
					sram_addr_c0 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 0 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c2 = 0; end
						2'd1 : begin sram_wen_c0 = 0; end
						2'd2 : begin sram_wen_c3 = 0; end
						2'd3 : begin sram_wen_c1 = 0; end
					endcase
				end
				if(cnt_compute_row == 5 & cnt_compute_col == 1) begin
					wdata_partial = {mul_out, 36'b0}; // 191:180 (3)
					mask_partial = 4'b0111; // only write MSB 
					sram_addr_c0 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 1 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c3 = 0; end
						2'd1 : begin sram_wen_c1 = 0; end
						2'd2 : begin sram_wen_c2 = 0; end
						2'd3 : begin sram_wen_c0 = 0; end
					endcase
				end		
				if(cnt_compute_row == 5 & cnt_compute_col == 2) begin
					wdata_partial = {12'b0, mul_out, 24'b0}; // 179:168(2)
					mask_partial = 4'b1011;
					sram_addr_c0 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 1 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 1 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c3 = 0; end //g
						2'd1 : begin sram_wen_c1 = 0; end //b
						2'd2 : begin sram_wen_c2 = 0; end //y
						2'd3 : begin sram_wen_c0 = 0; end //o
					endcase
				end			
				if(cnt_compute_row == 5 & cnt_compute_col == 3) begin
					wdata_partial = {mul_out, 36'b0}; // 191:180 (3)
					mask_partial = 4'b0111; // only write MSB 
					sram_addr_c0 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 2 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c2 = 0; end //y
						2'd1 : begin sram_wen_c0 = 0; end //o
						2'd2 : begin sram_wen_c3 = 0; end //g
						2'd3 : begin sram_wen_c1 = 0; end //b
					endcase
				end					
				if(cnt_compute_row == 5 & cnt_compute_col == 4) begin
					wdata_partial = {12'b0, mul_out, 24'b0}; // 179:168(2)
					mask_partial = 4'b1011;
					sram_addr_c0 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 2 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 2 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c2 = 0; end //y
						2'd1 : begin sram_wen_c0 = 0; end //o
						2'd2 : begin sram_wen_c3 = 0; end //g
						2'd3 : begin sram_wen_c1 = 0; end //b
					endcase
				end				
				if(cnt_compute_row == 5 & cnt_compute_col == 5) begin
					wdata_partial = {mul_out, 36'b0}; // 191:180(3)
					mask_partial = 4'b0111; // only write MSB 
					sram_addr_c0 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c1 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c2 = 0 + 9 * cnt_ofmap[2];
					sram_addr_c3 = 0 + 9 * cnt_ofmap[2];
					case (cnt_compute)
						2'd0 : begin sram_wen_c3 = 0; end //g
						2'd1 : begin sram_wen_c1 = 0; end //b
						2'd2 : begin sram_wen_c2 = 0; end //y
						2'd3 : begin sram_wen_c0 = 0; end //o
					endcase
				end								
			end
      default :  begin
        sram_wen_c0 = 1;
        sram_wen_c1 = 1;
        sram_wen_c2 = 1;
        sram_wen_c3 = 1;
      end
		endcase
	end
end

// Partial -> Whole
always @* begin
	if(conv1_en) // 0000 0001 0010 0011 0100
		case(cnt_ofmap[1:0])
			0: begin
				sram_wordmask_c = {mask_partial, 12'hfff};
				sram_wdata_c = {wdata_partial, 144'b0};
			end
			1: begin 
				sram_wordmask_c = {4'hf, mask_partial, 8'hff};
				sram_wdata_c = {48'b0, wdata_partial, 96'b0};
			end
			2: begin 
				sram_wordmask_c = {8'hff, mask_partial, 4'hf};
				sram_wdata_c = {96'b0, wdata_partial, 48'b0};
			end
			3: begin 
				sram_wordmask_c = {12'hfff, mask_partial};
				sram_wdata_c = {144'b0, wdata_partial};
			end
			default: begin 
				sram_wordmask_c = 16'hffff;
				sram_wdata_c = 0;
			end
		endcase
end

always @* begin
	sram_wdata_c0 = !sram_wen_c0 ? sram_wdata_c : 0;
	sram_wdata_c1 = !sram_wen_c1 ? sram_wdata_c : 0;
	sram_wdata_c2 = !sram_wen_c2 ? sram_wdata_c : 0;
	sram_wdata_c3 = !sram_wen_c3 ? sram_wdata_c : 0;
	sram_wordmask_c0 = !sram_wen_c0 ? sram_wordmask_c : 16'hffff;
	sram_wordmask_c1 = !sram_wen_c1 ? sram_wordmask_c : 16'hffff;
	sram_wordmask_c2 = !sram_wen_c2 ? sram_wordmask_c : 16'hffff;
	sram_wordmask_c3 = !sram_wen_c3 ? sram_wordmask_c : 16'hffff;
end
endmodule 
