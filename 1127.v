module qr_decode(
    input clk,                          //clock input
    input srstn,                        //synchronous reset (active low)
    input qr_decode_start,              //start decoding for one QR code
                                        //1: start (one-cycle pulse)
    input [15:0] sram_rdata,            //read data from SRAM
    output reg [9:0] sram_raddr,            //read address to SRAM

    output reg decode_valid,                //decoded code is valid
    output reg [7:0] decode_jis8_code,      //decoded JIS8 code
    output reg qr_decode_finish             //1: decoding one QR code is finished
);

reg decode_valid_reg;
reg [7:0] decode_jis8_code_reg;
reg qr_decode_finish_reg;

reg qr_decode_start_reg;
reg [9:0] sram_pos, mask_pos;

reg [5:0] pos;

reg [9:0] start_pos; //
reg [9:0] start_tmp; //
reg [9:0] qrcode_start_tmp, qrcode_start, qrcode_start_whole;


reg [9:0] sram_raddr_reg;
reg [15:0] sram_rdata_reg;
reg [7:0] decode_cnt, decode_tmp;
reg [4:0] check;
// cnt
reg [6:0] position_cnt, position_tmp;
reg [6:0] store_cnt, store_tmp;
reg [7:0] mask_pattern_tmp, mask_pattern;
reg [2:0] rotation_cnt, rotation_tmp;

wire [0:6] position_truth [0:3];
assign position_truth[0] = 7'b1111111;
assign position_truth[1] = 7'b1000001;
assign position_truth[2] = 7'b1011101;
assign position_truth[3] = 7'b1011101;

wire [0:24] position_truth_line_1x;
assign position_truth_line_1x = 25'b1111111010101010101111111;
wire [0:49] position_truth_line_2x;
assign position_truth_line_2x = 50'b11111111111111001100110011001100110011111111111111;

reg check_1, check_2, check_3, check_4, check_5, check_6, check_7, check_8, check_9, check_10, check_11, check_12, check_13, check_14, check_15, check_16;
// 28*28
reg [0:27] position_block_line [0:3];
reg [0:27] position_block_line_tmp [0:3];

reg [0:11] position_block [0:11]; // 0:7
reg [3:0] rotation_type, rotation_type_tmp;
wire signed [8:0] rotation_correct[0:4];
assign rotation_correct[0] = 9'd128; //288 = 32 * 9 
assign rotation_correct[1] = 9'd132; // 297
assign rotation_correct[2] = 9'd92;
assign rotation_correct[3] = 9'd96;
assign rotation_correct[4] = 9'd96;
//
wire [4:0] qrcode_decode_pos_x [0:26] [0:7];
wire [4:0] qrcode_decode_pos_y [0:26] [0:7];
//
reg [7:0] length;
reg [8:0] tmp;
reg [4:0] ind;
wire [7:0] mask_length[0:7];
assign mask_length[0] = 8'b10011001;
assign mask_length[1] = 8'b11001100;
assign mask_length[2] = 8'b10101010;
assign mask_length[3] = 8'b01100001;
assign mask_length[4] = 8'b01101001;
assign mask_length[5] = 8'b10101010;
assign mask_length[6] = 8'b11101010;
assign mask_length[7] = 8'b10011101;
//
reg [1:0] x_ind, y_ind;
reg [5:0] x_tmp, y_tmp;
reg [5:0] x_qr_tmp, y_qr_tmp;
//
reg [2:0] mask, mask_pattern_real;
//
wire [7:0] mask_message [0:7] [0:25];
reg [7:0] qrcode_message;
//
reg [7:0] decode_length_tmp,decode_length_reg;
reg [7:0] decode_length;
//

//==============================
//FSM
//==============================
localparam IDLE=5'd0, POSITION=5'd1, WAIT=5'd2, CHECK=5'd3, CHECK_END = 5'd4, FIND_ROTATION=5'd7, DONE=5'd15, ROTATION_POSITION=5'd8, ROTATION_WAIT=5'd5, ROTATION_CHECK=5'd6,DECODE_MASK=5'd9, DECODE_WAIT=5'd10, DECODE_LENGTH=5'd11, DECODE_READ=5'd12, DECODE_READ_WAIT=5'd13, DECODE=5'd14;
reg [5:0] state, nstate;
always@* begin
    case(state)
        IDLE : nstate = qr_decode_start_reg ? POSITION : IDLE ;
        POSITION : nstate = position_cnt == 6 ? WAIT : POSITION; // 14 
        WAIT : nstate = store_cnt == 2 ? CHECK : WAIT;
        CHECK : nstate = check > 0 ? ROTATION_WAIT : (store_cnt == 25) ? CHECK_END : CHECK; // 128 - 28 / 4 
        CHECK_END : nstate = check > 0 ? ROTATION_WAIT : store_cnt == 27 ? POSITION : CHECK_END; // 9 + 3

        ROTATION_WAIT: nstate = store_cnt==0 ? ROTATION_CHECK : ROTATION_WAIT;
        ROTATION_CHECK: nstate = store_cnt==1 ? FIND_ROTATION:ROTATION_CHECK;
        FIND_ROTATION: nstate = rotation_type>0 ? DECODE_MASK :ROTATION_POSITION; //
        ROTATION_POSITION: nstate = position_cnt==9 ? ROTATION_WAIT: ROTATION_POSITION;//9
// timing check
        DECODE_MASK: begin nstate = store_cnt == 1? DECODE_WAIT:DECODE_MASK; end // 2 cycle
        DECODE_WAIT: begin nstate = store_cnt == 4? DECODE_LENGTH:DECODE_WAIT; end // 
        DECODE_LENGTH: begin nstate = decode_cnt == 12? DECODE_READ:DECODE_LENGTH; end
        DECODE_READ: begin nstate = decode_cnt == 8? DECODE_READ_WAIT:DECODE_READ; end
        DECODE_READ_WAIT: begin nstate = decode_cnt == 10? DECODE:DECODE_READ_WAIT; end  // localparam : 13
        DECODE: begin nstate = decode_length > length? DONE:DECODE_READ; end
        DONE: begin nstate = POSITION; end
	    default: nstate = IDLE;
    endcase
end

always@(posedge clk) begin
	if(!srstn) begin
	    state <= IDLE;
        qr_decode_start_reg <= 0;
        position_cnt <= 0;
        store_cnt <= 0;
        rotation_type <= 0;
        mask_pattern <= 0;
        rotation_cnt <= 0;
        decode_cnt <= 0;
        decode_length <= 0;
	    decode_length_reg <= 0;
        qrcode_start_whole <= 0;
	end
	else begin
	    state <= nstate;
        qr_decode_start_reg <= qr_decode_start;
        position_cnt <= position_tmp;
        store_cnt <= store_tmp;
        rotation_type <= rotation_type_tmp;
        mask_pattern <= mask_pattern_tmp;
        rotation_cnt <= rotation_tmp;
        decode_cnt <= decode_tmp;
        decode_length <= decode_length_reg;
        decode_length_reg <= decode_length_tmp;
        qrcode_start_whole <= qrcode_start_tmp;
	end
end

always @* begin
    case(state)
        IDLE : begin
            sram_raddr_reg = sram_pos;
            position_tmp = 0;
            store_tmp = start_pos;
            start_tmp = 0;
            qr_decode_finish_reg = 0;
            rotation_tmp = 0;
            decode_tmp = 0;
            decode_valid_reg = 0;
            decode_jis8_code_reg  = 0;
        end
        POSITION: begin
            sram_raddr_reg = sram_pos;
            position_tmp = position_cnt+1; 
            start_tmp = start_pos;
            store_tmp = 0;
            qr_decode_finish_reg = 0;
            rotation_tmp = rotation_cnt;
            decode_tmp = 0;
            decode_valid_reg = 0;
            decode_jis8_code_reg  = 0;
        end
        WAIT: begin
            sram_raddr_reg = sram_pos;
            position_tmp = position_cnt+1; 
            start_tmp = start_pos;
            store_tmp = store_cnt+1;
            qr_decode_finish_reg = 0;
            rotation_tmp = rotation_cnt;
            decode_tmp = 0;
            decode_valid_reg = 0;
            decode_jis8_code_reg  = 0;    
        end
        CHECK: begin
                sram_raddr_reg = sram_pos;
                position_tmp = 0;
                start_tmp = start_pos+32;
                if(check==0) store_tmp = store_cnt+1;
                else store_tmp = 0;
                //store_tmp = store_cnt+1;
                qr_decode_finish_reg = 0;
                rotation_tmp = rotation_cnt;
                decode_tmp = 0;
                decode_valid_reg = 0;
                decode_jis8_code_reg  = 0;
            end
            CHECK_END: begin
                sram_raddr_reg = sram_pos;
                position_tmp = position_cnt+1;
                start_tmp = start_pos;
                if(check==0) store_tmp = store_cnt+1;
                else store_tmp = 0;
                qr_decode_finish_reg = 0;
                rotation_tmp = rotation_cnt;
                decode_tmp = 0;
                decode_valid_reg = 0;
                decode_jis8_code_reg  = 0;
            end
            FIND_ROTATION: begin // 5
                if(rotation_cnt<2) sram_raddr_reg = sram_pos+rotation_correct[rotation_cnt];
                else sram_raddr_reg = sram_pos-rotation_correct[rotation_cnt];
                position_tmp = position_cnt+1;
                start_tmp = start_pos+1;
                store_tmp = 0;
                qr_decode_finish_reg=0;
                rotation_tmp = rotation_cnt+1;
                decode_tmp = 0;
                decode_valid_reg = 0;
                decode_jis8_code_reg  = 0;
            end
            ROTATION_POSITION: begin
                if(rotation_cnt<3) sram_raddr_reg = sram_pos+rotation_correct[rotation_cnt-1];
                else sram_raddr_reg = sram_pos-rotation_correct[rotation_cnt-1];
                position_tmp = position_cnt+1;
                start_tmp = start_pos+1;
                store_tmp = 0;
                qr_decode_finish_reg=0;
                rotation_tmp = rotation_cnt;
                decode_tmp = 0;
                decode_valid_reg = 0;
                decode_jis8_code_reg  = 0;
            end
            ROTATION_WAIT: begin // 8
                if(rotation_cnt<2) sram_raddr_reg = sram_pos+rotation_correct[rotation_cnt];
                else sram_raddr_reg = sram_pos-rotation_correct[rotation_cnt];
                position_tmp = 0; 
                start_tmp = start_pos+1;
                store_tmp = store_cnt+1;
                qr_decode_finish_reg = 0;
                rotation_tmp = rotation_cnt;
                decode_tmp = 0;
                decode_valid_reg = 0;
                decode_jis8_code_reg  = 0;
            end
            ROTATION_CHECK: begin // 9
                if(rotation_cnt<2) sram_raddr_reg = sram_pos+rotation_correct[rotation_cnt];
                else sram_raddr_reg = sram_pos-rotation_correct[rotation_cnt];
                sram_raddr_reg = sram_pos+rotation_correct[rotation_cnt];
                position_tmp = position_cnt+1;
                start_tmp = start_pos+1;
                store_tmp = store_cnt+1;
                qr_decode_finish_reg = 0;
                rotation_tmp = rotation_cnt;
                decode_tmp = 0;
                decode_valid_reg = 0;
                decode_jis8_code_reg  = 0;
            end
            DECODE_MASK: begin
                    sram_raddr_reg = mask_pos;
                    position_tmp = 0;
                    start_tmp = 0;
                    store_tmp = store_cnt+1;
                    qr_decode_finish_reg=0;
                    rotation_tmp = 0;
                    decode_tmp = 0;
                    decode_valid_reg = 0;
                    decode_jis8_code_reg  = 0;
                end
                DECODE_WAIT: begin
                    sram_raddr_reg = qrcode_start_whole + {x_tmp[5:1],y_tmp[5:1]};
                    position_tmp = 0;
                    start_tmp = 0;
                    store_tmp = store_cnt+1;
                    qr_decode_finish_reg=0;
                    rotation_tmp = 0;
                    decode_tmp = decode_cnt+1; 
                    decode_valid_reg = 0;
                    decode_jis8_code_reg  = 0;
                end
                DECODE_READ: begin
                    sram_raddr_reg = qrcode_start_whole + {x_tmp[5:1],y_tmp[5:1]};
                    position_tmp = position_cnt+1;
                    start_tmp = 0;
                    store_tmp = 0;
                    qr_decode_finish_reg=0;
                    rotation_tmp = 0;
                    decode_tmp = decode_cnt+1;
                    decode_valid_reg = 0;
                    decode_jis8_code_reg  = 0;
                end
                DECODE_READ_WAIT: begin // 13
                    sram_raddr_reg = qrcode_start_whole + {x_tmp[5:1],y_tmp[5:1]};
                    position_tmp = position_cnt+1;
                    start_tmp = 0;
                    store_tmp = 0;
                    qr_decode_finish_reg=0;
                    rotation_tmp = 0;
                    if(decode_cnt==10) decode_tmp = 0;
                    else decode_tmp = decode_cnt+1;
                    decode_valid_reg = 0;
                    decode_jis8_code_reg  = 0;
                end
                DECODE_LENGTH: begin
                    sram_raddr_reg = qrcode_start_whole + {x_tmp[5:1],y_tmp[5:1]};
                    position_tmp = position_cnt+1;
                    start_tmp = 0;
                    store_tmp = 0;
                    qr_decode_finish_reg=0;
                    rotation_tmp = 0;
                    if(decode_cnt==12) decode_tmp = 0; //
                    else decode_tmp = decode_cnt+1;
                    decode_valid_reg = 0;
                    decode_jis8_code_reg  = 0;
                end
                DECODE: begin
                    sram_raddr_reg = qrcode_start_whole + {x_tmp[5:1],y_tmp[5:1]};
            //	    sram_raddr_reg = qrcode_start_whole + {(qrcode_decode_pos_x[decode_length][decode_cnt]+x_ind)>>1,(qrcode_decode_pos_y[decode_length][decode_cnt]+y_ind)>>1};
                    position_tmp = 0;
                    start_tmp = 0;
                    store_tmp = 0;
                    qr_decode_finish_reg=0;
                    rotation_tmp = 0;
                    decode_tmp = decode_cnt+1;
                    decode_valid_reg = 1;
                    decode_jis8_code_reg  = qrcode_message ^ mask_message[mask_pattern_real][decode_length-2];
                end
            DONE: begin
                sram_raddr_reg = 0;
                position_tmp = 0;
                start_tmp = 0;
                store_tmp = 0;
                qr_decode_finish_reg=1;
                rotation_tmp = 0;
                decode_tmp = 0;
                decode_valid_reg = 0;
                decode_jis8_code_reg  = 0;
	        end
	        default: begin
                sram_raddr_reg = 0;
                position_tmp = 0;
                start_tmp = 0;
                store_tmp = 0;
                qr_decode_finish_reg = 0;
                rotation_tmp = 0;
                decode_tmp = 0;
                decode_valid_reg = 0;
                decode_jis8_code_reg  = 0;
            end
    endcase
end
//========================================
// 4*28 table
// 
//========================================
always@(posedge clk) begin
    position_block_line[0] <= position_block_line_tmp[0];
    position_block_line[1] <= position_block_line_tmp[1];
    position_block_line[2] <= position_block_line_tmp[2];
    position_block_line[3] <= position_block_line_tmp[3];
end

always@* begin
    check_1 = 0;
    check_2 = 0;
    check_3 = 0;
    check_4 = 0;
    check_5 = 0;
    check_6 = 0;
    check_7 = 0;
    check_8 = 0;
    check_9 = 0;
    check_10 = 0;
    check_11 = 0;
    check_12 = 0;
    check_13 = 0;
    check_14 = 0;
    check_15 = 0;
    check_15 = 0;
    check_16 = 0;
    if(state==CHECK||state==CHECK_END) begin
    //    if(state==CHECK) begin
        if(position_block_line[2][0:24]==position_truth_line_1x) check_1 = 1;      //PAT1
        if(position_block_line[2][1:25]==position_truth_line_1x) check_2 = 1;      //PAT2
        if(position_block_line[2][2:26]==position_truth_line_1x) check_3 = 1;      //PAT3
        if(position_block_line[2][3:27]==position_truth_line_1x) check_4 = 1;      //PAT4
        if(position_block_line[3][0:24]==position_truth_line_1x) check_5 = 1;      //PAT1
        if(position_block_line[3][1:25]==position_truth_line_1x) check_6 = 1;      //PAT2
        if(position_block_line[3][2:26]==position_truth_line_1x) check_7 = 1;      //PAT3
        if(position_block_line[3][3:27]==position_truth_line_1x) check_8 = 1;      //PAT4
        if(position_block_line[0][0:24]==position_truth_line_1x) check_9 = 1;      //PAT1
        if(position_block_line[0][1:25]==position_truth_line_1x) check_10 = 1;      //PAT2
        if(position_block_line[0][2:26]==position_truth_line_1x) check_11 = 1;      //PAT3
        if(position_block_line[0][3:27]==position_truth_line_1x) check_12 = 1;      //PAT4
        if(position_block_line[1][0:24]==position_truth_line_1x) check_13 = 1;      //PAT1
        if(position_block_line[1][1:25]==position_truth_line_1x) check_14 = 1;      //PAT2
        if(position_block_line[1][2:26]==position_truth_line_1x) check_15 = 1;      //PAT3
        if(position_block_line[1][3:27]==position_truth_line_1x) check_16 = 1;      //PAT4
    end
end
always@* begin
    if(state==IDLE) rotation_type_tmp = 0;
    else if(state==ROTATION_CHECK && rotation_cnt>0) begin
	case(check)
	    1: begin 
//		if(position_block[0][0:6]==position_truth[0]&&position_block[1][0:6]==position_truth[1]&&position_block[2][0:6]==position_truth[2]&&position_block[3][0:6]==position_truth[3]&&position_block[4][0:6]==position_truth[4]&&position_block[5][0:6]==position_truth[5]&&position_block[6][0:6]==position_truth[6]) rotation_type_tmp = rotation_cnt; 
		if(position_block[2][0:6]==position_truth[0]&&position_block[3][0:6]==position_truth[1]&&position_block[4][0:6]==position_truth[2]&&position_block[5][0:6]==position_truth[3]) rotation_type_tmp = rotation_cnt; 
		else rotation_type_tmp = rotation_type; 
	    end
	    2: begin 
//		if(position_block[0][1:7]==position_truth[0]&&position_block[1][1:7]==position_truth[1]&&position_block[2][1:7]==position_truth[2]&&position_block[3][1:7]==position_truth[3]&&position_block[4][1:7]==position_truth[4]&&position_block[5][1:7]==position_truth[5]&&position_block[6][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[2][1:7]==position_truth[0]&&position_block[3][1:7]==position_truth[1]&&position_block[4][1:7]==position_truth[2]&&position_block[5][1:7]==position_truth[3]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    3: begin 
//		if(position_block[1][0:6]==position_truth[0]&&position_block[2][0:6]==position_truth[1]&&position_block[3][0:6]==position_truth[2]&&position_block[4][0:6]==position_truth[3]&&position_block[5][0:6]==position_truth[4]&&position_block[6][0:6]==position_truth[5]&&position_block[7][0:6]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[2][2:8]==position_truth[0]&&position_block[3][2:8]==position_truth[1]&&position_block[4][2:8]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    4: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[2][3:9]==position_truth[0]&&position_block[3][3:9]==position_truth[1]&&position_block[4][3:9]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
        //

	    5: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[3][0:6]==position_truth[0]&&position_block[4][0:6]==position_truth[1]&&position_block[5][0:6]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    6: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[3][1:7]==position_truth[0]&&position_block[4][1:7]==position_truth[1]&&position_block[5][1:7]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    7: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[3][2:8]==position_truth[0]&&position_block[4][2:8]==position_truth[1]&&position_block[5][2:8]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    8: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[3][3:9]==position_truth[0]&&position_block[4][3:9]==position_truth[1]&&position_block[5][3:9]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
        //
	    9: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[0][0:6]==position_truth[0]&&position_block[1][0:6]==position_truth[1]&&position_block[2][0:6]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    10: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[0][1:7]==position_truth[0]&&position_block[1][1:7]==position_truth[1]&&position_block[2][1:7]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    11: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[0][2:8]==position_truth[0]&&position_block[1][2:8]==position_truth[1]&&position_block[2][2:8]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    12: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[0][3:9]==position_truth[0]&&position_block[1][3:9]==position_truth[1]&&position_block[2][3:9]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
        //
	    13: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[1][0:6]==position_truth[0]&&position_block[2][0:6]==position_truth[1]&&position_block[3][0:6]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    14: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    15: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[1][2:8]==position_truth[0]&&position_block[2][2:8]==position_truth[1]&&position_block[3][2:8]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    16: begin 
//		if(position_block[1][1:7]==position_truth[0]&&position_block[2][1:7]==position_truth[1]&&position_block[3][1:7]==position_truth[2]&&position_block[4][1:7]==position_truth[3]&&position_block[5][1:7]==position_truth[4]&&position_block[6][1:7]==position_truth[5]&&position_block[7][1:7]==position_truth[6]) rotation_type_tmp = rotation_cnt;
		if(position_block[1][3:9]==position_truth[0]&&position_block[2][3:9]==position_truth[1]&&position_block[3][3:9]==position_truth[2]) rotation_type_tmp = rotation_cnt;
		else rotation_type_tmp = rotation_type;
	    end
	    default: begin rotation_type_tmp = 0; end
	endcase
    end
    else rotation_type_tmp = rotation_type;
end

//assign sram_raddr = sram_raddr_reg;

always@(posedge clk) begin
    if (!srstn) begin
        sram_raddr <= 0;
        sram_rdata_reg <= 0;
    end
    else begin
        sram_raddr <= sram_raddr_reg;
        sram_rdata_reg <= sram_rdata;
    end
end

always@(*) begin
    if(state==IDLE) begin
    	position_block_line_tmp[0] = 64'b0;
    	position_block_line_tmp[1] = 64'b0;
    end
    else if(state==POSITION||state==WAIT) begin
        pos = position_cnt-2;                                          // pos     0 
        position_block_line_tmp[0][pos*4]  = sram_rdata_reg[0];       // Line0 // 0  1  2  3 ,, 00 01 02 03
        position_block_line_tmp[0][pos*4+1]= sram_rdata_reg[1];       // Line1 // 4  5  6  7 // 10 11 12 13
        position_block_line_tmp[0][pos*4+2]  = sram_rdata_reg[2];     // Line2 // 8  9 10 11
        position_block_line_tmp[0][pos*4+3]= sram_rdata_reg[3];       // Line3 //12 13 14 15
        position_block_line_tmp[1][pos*4]  = sram_rdata_reg[4];       
        position_block_line_tmp[1][pos*4+1]= sram_rdata_reg[5];       // pos 1
        position_block_line_tmp[1][pos*4+2]  = sram_rdata_reg[6];     // 04 05 06 07
        position_block_line_tmp[1][pos*4+3]= sram_rdata_reg[7];       // 08 09 10 11
        position_block_line_tmp[2][pos*4]  = sram_rdata_reg[8];       
        position_block_line_tmp[2][pos*4+1]= sram_rdata_reg[9];       
        position_block_line_tmp[2][pos*4+2]  = sram_rdata_reg[10];
        position_block_line_tmp[2][pos*4+3]= sram_rdata_reg[11];
        position_block_line_tmp[3][pos*4]  = sram_rdata_reg[12];      
        position_block_line_tmp[3][pos*4+1]= sram_rdata_reg[13];      
        position_block_line_tmp[3][pos*4+2]  = sram_rdata_reg[14];
        position_block_line_tmp[3][pos*4+3]= sram_rdata_reg[15];        
    end
    else if ((state==CHECK || state==CHECK_END)) begin
        position_block_line_tmp[0] = {position_block_line[0][4:27], sram_rdata_reg[0], sram_rdata_reg[1], sram_rdata_reg[2], sram_rdata_reg[3]};
	    position_block_line_tmp[1] = {position_block_line[1][4:27], sram_rdata_reg[4], sram_rdata_reg[5], sram_rdata_reg[6], sram_rdata_reg[7]};
        position_block_line_tmp[2] = {position_block_line[2][4:27], sram_rdata_reg[8], sram_rdata_reg[9], sram_rdata_reg[10], sram_rdata_reg[11]};
        position_block_line_tmp[3] = {position_block_line[3][4:27], sram_rdata_reg[12], sram_rdata_reg[13], sram_rdata_reg[14], sram_rdata_reg[15]};
    end
    else if(state==ROTATION_POSITION||state==ROTATION_WAIT) begin // pos = 0, 1, 2, // 3, 4, 5, // 6, 7, 8
        pos = position_cnt-2;
        case(pos)
            4'd0: begin
                position_block[0][0] = sram_rdata_reg[0];
                position_block[0][1] = sram_rdata_reg[1];
                position_block[0][2] = sram_rdata_reg[2];
                position_block[0][3] = sram_rdata_reg[3];
                position_block[1][0] = sram_rdata_reg[4];
                position_block[1][1] = sram_rdata_reg[5];
                position_block[1][2] = sram_rdata_reg[6];
                position_block[1][3] = sram_rdata_reg[7];
                position_block[2][0] = sram_rdata_reg[8];
                position_block[2][1] = sram_rdata_reg[9];
                position_block[2][2] = sram_rdata_reg[10];
                position_block[2][3] = sram_rdata_reg[11];
                position_block[3][0] = sram_rdata_reg[12];
                position_block[3][1] = sram_rdata_reg[13];
                position_block[3][2] = sram_rdata_reg[14];
                position_block[3][3] = sram_rdata_reg[15];
            end
            4'd1: begin
                position_block[0][4] = sram_rdata_reg[0];
                position_block[0][5] = sram_rdata_reg[1];
                position_block[0][6] = sram_rdata_reg[2];
                position_block[0][7] = sram_rdata_reg[3];
                position_block[1][4] = sram_rdata_reg[4];
                position_block[1][5] = sram_rdata_reg[5];
                position_block[1][6] = sram_rdata_reg[6];
                position_block[1][7] = sram_rdata_reg[7];
                position_block[2][4] = sram_rdata_reg[8];
                position_block[2][5] = sram_rdata_reg[9];
                position_block[2][6] = sram_rdata_reg[10];
                position_block[2][7] = sram_rdata_reg[11];
                position_block[3][4] = sram_rdata_reg[12];
                position_block[3][5] = sram_rdata_reg[13];
                position_block[3][6] = sram_rdata_reg[14];
                position_block[3][7] = sram_rdata_reg[15];
            end
            4'd2: begin
                position_block[0][8] = sram_rdata_reg[0];
                position_block[0][9] = sram_rdata_reg[1];
                position_block[0][10] = sram_rdata_reg[2];
                position_block[0][11] = sram_rdata_reg[3];
                position_block[1][8] = sram_rdata_reg[4];
                position_block[1][9] = sram_rdata_reg[5];
                position_block[1][10] = sram_rdata_reg[6];
                position_block[1][11] = sram_rdata_reg[7];
                position_block[2][8] = sram_rdata_reg[8];
                position_block[2][9] = sram_rdata_reg[9];
                position_block[2][10] = sram_rdata_reg[10];
                position_block[2][11] = sram_rdata_reg[11];
                position_block[3][8] = sram_rdata_reg[12];
                position_block[3][9] = sram_rdata_reg[13];
                position_block[3][10] = sram_rdata_reg[14];
                position_block[3][11] = sram_rdata_reg[15];
            end
            4'd3: begin
                position_block[4][0] = sram_rdata_reg[0];
                position_block[4][1] = sram_rdata_reg[1];
                position_block[4][2] = sram_rdata_reg[2];
                position_block[4][3] = sram_rdata_reg[3];
                position_block[5][0] = sram_rdata_reg[4];
                position_block[5][1] = sram_rdata_reg[5];
                position_block[5][2] = sram_rdata_reg[6];
                position_block[5][3] = sram_rdata_reg[7];
                position_block[6][0] = sram_rdata_reg[8];
                position_block[6][1] = sram_rdata_reg[9];
                position_block[6][2] = sram_rdata_reg[10];
                position_block[6][3] = sram_rdata_reg[11];
                position_block[7][0] = sram_rdata_reg[12];
                position_block[7][1] = sram_rdata_reg[13];
                position_block[7][2] = sram_rdata_reg[14];
                position_block[7][3] = sram_rdata_reg[15];
            end
            4'd4: begin
                position_block[4][4] = sram_rdata_reg[0];
                position_block[4][5] = sram_rdata_reg[1];
                position_block[4][6] = sram_rdata_reg[2];
                position_block[4][7] = sram_rdata_reg[3];
                position_block[5][4] = sram_rdata_reg[4];
                position_block[5][5] = sram_rdata_reg[5];
                position_block[5][6] = sram_rdata_reg[6];
                position_block[5][7] = sram_rdata_reg[7];
                position_block[6][4] = sram_rdata_reg[8];
                position_block[6][5] = sram_rdata_reg[9];
                position_block[6][6] = sram_rdata_reg[10];
                position_block[6][7] = sram_rdata_reg[11];
                position_block[7][4] = sram_rdata_reg[12];
                position_block[7][5] = sram_rdata_reg[13];
                position_block[7][6] = sram_rdata_reg[14];
                position_block[7][7] = sram_rdata_reg[15];
            end
            4'd5: begin
                position_block[4][8] = sram_rdata_reg[0];
                position_block[4][9] = sram_rdata_reg[1];
                position_block[4][10] = sram_rdata_reg[2];
                position_block[4][11] = sram_rdata_reg[3];
                position_block[5][8] = sram_rdata_reg[4];
                position_block[5][9] = sram_rdata_reg[5];
                position_block[5][10] = sram_rdata_reg[6];
                position_block[5][11] = sram_rdata_reg[7];
                position_block[6][8] = sram_rdata_reg[8];
                position_block[6][9] = sram_rdata_reg[9];
                position_block[6][10] = sram_rdata_reg[10];
                position_block[6][11] = sram_rdata_reg[11];
                position_block[7][8] = sram_rdata_reg[12];
                position_block[7][9] = sram_rdata_reg[13];
                position_block[7][10] = sram_rdata_reg[14];
                position_block[7][11] = sram_rdata_reg[15];
            end
            4'd6: begin
                position_block[8][0] = sram_rdata_reg[0];
                position_block[8][1] = sram_rdata_reg[1];
                position_block[8][2] = sram_rdata_reg[2];
                position_block[8][3] = sram_rdata_reg[3];
                position_block[9][0] = sram_rdata_reg[4];
                position_block[9][1] = sram_rdata_reg[5];
                position_block[9][2] = sram_rdata_reg[6];
                position_block[9][3] = sram_rdata_reg[7];
                position_block[10][0] = sram_rdata_reg[8];
                position_block[10][1] = sram_rdata_reg[9];
                position_block[10][2] = sram_rdata_reg[10];
                position_block[10][3] = sram_rdata_reg[11];
                position_block[11][0] = sram_rdata_reg[12];
                position_block[11][1] = sram_rdata_reg[13];
                position_block[11][2] = sram_rdata_reg[14];
                position_block[11][3] = sram_rdata_reg[15];
            end
            4'd7: begin
                position_block[8][4] = sram_rdata_reg[0];
                position_block[8][5] = sram_rdata_reg[1];
                position_block[8][6] = sram_rdata_reg[2];
                position_block[8][7] = sram_rdata_reg[3];
                position_block[9][4] = sram_rdata_reg[4];
                position_block[9][5] = sram_rdata_reg[5];
                position_block[9][6] = sram_rdata_reg[6];
                position_block[9][7] = sram_rdata_reg[7];
                position_block[10][4] = sram_rdata_reg[8];
                position_block[10][5] = sram_rdata_reg[9];
                position_block[10][6] = sram_rdata_reg[10];
                position_block[10][7] = sram_rdata_reg[11];
                position_block[11][4] = sram_rdata_reg[12];
                position_block[11][5] = sram_rdata_reg[13];
                position_block[11][6] = sram_rdata_reg[14];
                position_block[11][7] = sram_rdata_reg[15];
            end
            4'd8: begin
                position_block[8][8] = sram_rdata_reg[0];
                position_block[8][9] = sram_rdata_reg[1];
                position_block[8][10] = sram_rdata_reg[2];
                position_block[8][11] = sram_rdata_reg[3];
                position_block[9][8] = sram_rdata_reg[4];
                position_block[9][9] = sram_rdata_reg[5];
                position_block[9][10] = sram_rdata_reg[6];
                position_block[9][11] = sram_rdata_reg[7];
                position_block[10][8] = sram_rdata_reg[8];
                position_block[10][9] = sram_rdata_reg[9];
                position_block[10][10] = sram_rdata_reg[10];
                position_block[10][11] = sram_rdata_reg[11];
                position_block[11][8] = sram_rdata_reg[12];
                position_block[11][9] = sram_rdata_reg[13];
                position_block[11][10] = sram_rdata_reg[14];
                position_block[11][11] = sram_rdata_reg[15];
            end
        endcase
        // position_block[pos[3:2]*4][pos[1:0]*4] = sram_rdata_reg[0];
        // position_block[pos[3:2]*4][pos[1:0]*4+1] = sram_rdata_reg[1];
        // position_block[pos[3:2]*4][pos[1:0]*4+2] = sram_rdata_reg[2];
        // position_block[pos[3:2]*4][pos[1:0]*4+3] = sram_rdata_reg[3];
        // position_block[pos[3:2]*4+1][pos[1:0]*4] = sram_rdata_reg[4];
        // position_block[pos[3:2]*4+1][pos[1:0]*4+1] = sram_rdata_reg[5];
        // position_block[pos[3:2]*4+1][pos[1:0]*4+2] = sram_rdata_reg[6];
        // position_block[pos[3:2]*4+1][pos[1:0]*4+3] = sram_rdata_reg[7];
        // position_block[pos[3:2]*4+2][pos[1:0]*4] = sram_rdata_reg[8];
        // position_block[pos[3:2]*4+2][pos[1:0]*4+1] = sram_rdata_reg[9];
        // position_block[pos[3:2]*4+2][pos[1:0]*4+2] = sram_rdata_reg[10];
        // position_block[pos[3:2]*4+2][pos[1:0]*4+3] = sram_rdata_reg[11];
        // position_block[pos[3:2]*4+3][pos[1:0]*4] = sram_rdata_reg[12];
        // position_block[pos[3:2]*4+3][pos[1:0]*4+1] = sram_rdata_reg[13];
        // position_block[pos[3:2]*4+3][pos[1:0]*4+2] = sram_rdata_reg[14];
        // position_block[pos[3:2]*4+3][pos[1:0]*4+3] = sram_rdata_reg[15];
    end
end

always@* begin
    case(check)
	    1: begin
	        x_ind = 0; y_ind = 0;
    	end
    	2: begin
    	    x_ind = 0; y_ind = 1;
    	end
    	3: begin
   	        x_ind = 0; y_ind = 2;
    	end
    	4: begin
    	   x_ind = 0; y_ind = 3;
    	end
     	5: begin
    	   x_ind = 1; y_ind = 0;
    	end
    	6: begin
    	   x_ind = 1; y_ind = 1;
    	end
    	7: begin
    	   x_ind = 1; y_ind = 2;
    	end
    	8: begin
    	   x_ind = 1; y_ind = 3;
    	end      
	    9: begin
	        x_ind = 2; y_ind = 0;
    	end
    	10: begin
    	    x_ind = 2; y_ind = 1;
    	end
    	11: begin
   	        x_ind = 2; y_ind = 2;
    	end
    	12: begin
    	    x_ind = 2; y_ind = 3;
    	end
     	13: begin
    	   x_ind = 3; y_ind = 0;
    	end
    	14: begin
    	   x_ind = 3; y_ind = 1;
    	end
    	15: begin
    	   x_ind = 3; y_ind = 2;
    	end
    	16: begin
    	   x_ind = 3; y_ind = 3;
    	end   
    	default: begin 
    	   x_ind = 0; y_ind = 0;
    	end
    endcase
end

always@* begin
    if(state==CHECK||state==DONE||state==CHECK_END) begin
	check[0] = check_1 || check_3 || check_5 || check_7 || check_9 || check_11 || check_13 || check_15;
	check[1] = check_2 || check_3 || check_6 || check_7 || check_10 || check_11 || check_14 || check_15;
	check[2] = check_4 || check_5 || check_6 || check_7 || check_12 || check_13 || check_14 || check_15;
    check[3] = check_8 || check_9 || check_10 || check_11 || check_12 || check_13 || check_14 || check_15;
    check[4] = check_16; 
    end
    else check=check;
end

//git
always@(posedge clk) begin
	if(~srstn) start_pos <= 32; // 192
	else if(state==CHECK && store_cnt==25) begin // iter first point
		start_pos <= start_tmp;
	end
	else start_pos <= start_pos;
end

always@(posedge clk) begin
    if((check_1||check_2||check_3||check_4||check_5||check_6||check_7||check_8||check_9||check_10||check_11||check_12||check_13||check_14||check_15||check_16)) begin
        if(state==CHECK) begin
            if(store_cnt>2) qrcode_start <= start_pos+store_cnt - 35 ; // 32 * 3 - 3
            else qrcode_start<= start_pos+store_cnt- 34; // 32 * 3 -2
        end
//	    else qrcode_start<=start_pos+store_cnt-67; // 32 * 4 - 3 = 131
    end
end

// counter control

always@* begin
	if(state==CHECK_END||state==POSITION)sram_pos = start_pos+position_cnt;
	else if(state==CHECK||state==WAIT) sram_pos = start_pos+store_cnt+7; // 7 * 4 = 28
	else if(state==FIND_ROTATION||state==ROTATION_POSITION||state==ROTATION_CHECK||state==ROTATION_WAIT) begin
		if(position_cnt<3) sram_pos = qrcode_start + position_cnt; // 2*2 -> 8*8 4*4 12*12 pos = 0 0-4, pos 1 5-8 pos 2 9 - 11
		else if(position_cnt<6) sram_pos = qrcode_start + (position_cnt-3) + 32; // pos 3 32 
		else if(position_cnt<9) sram_pos = qrcode_start + (position_cnt-6) + 64;
		else sram_pos = qrcode_start + (position_cnt-9) + 96;
	end
	else sram_pos = start_pos+position_cnt;
end

always@* begin
    if(state==DECODE_LENGTH && decode_cnt==11) decode_length_tmp = 1;
    else if(state==DECODE_READ_WAIT && decode_cnt==9) decode_length_tmp = decode_length_reg+1;
    else if(state==IDLE) decode_length_tmp = 0;
    else decode_length_tmp = decode_length_reg;
end

//reg [7:0] length_tmp, qrcode_message_tmp;
//
//always@(posedge clk) begin
//    length <= length_tmp;
//    qrcode_message <= qrcode_message_tmp;
//end

always@* begin
    if(decode_length==0) length[decode_cnt-3] = sram_rdata_reg[{x_qr_tmp[0],y_qr_tmp[0]}] ^ mask_length[mask_pattern_real][decode_cnt-3];
    if(decode_cnt>2) qrcode_message[decode_cnt-3] = sram_rdata_reg[{x_qr_tmp[0],y_qr_tmp[0]}];
    qrcode_message[0]=qrcode_message[0];
    qrcode_message[1]=qrcode_message[1];
    qrcode_message[2]=qrcode_message[2];
    qrcode_message[3]=qrcode_message[3];
    qrcode_message[4]=qrcode_message[4];
    qrcode_message[5]=qrcode_message[5];
    qrcode_message[6]=qrcode_message[6];
    qrcode_message[7]=qrcode_message[7];
    length[0] = length[0];
    length[1] = length[1];
    length[2] = length[2];
    length[3] = length[3];
    length[4] = length[4];
    length[5] = length[5];
    length[6] = length[6];
    length[7] = length[7];
end

always@* begin
    case(rotation_type)
	1: begin
    	    x_qr_tmp = qrcode_decode_pos_x[decode_length][decode_cnt-3]+x_ind;
	    y_qr_tmp = qrcode_decode_pos_y[decode_length][decode_cnt-3]+y_ind;
	end
	2: begin
    	    x_qr_tmp = qrcode_decode_pos_y[decode_length][decode_cnt-3]+x_ind;
	    y_qr_tmp = 24-qrcode_decode_pos_x[decode_length][decode_cnt-3]+y_ind;
	end
	3: begin
    	    x_qr_tmp = 24-qrcode_decode_pos_x[decode_length][decode_cnt-3]+x_ind;
	    y_qr_tmp = 24-qrcode_decode_pos_y[decode_length][decode_cnt-3]+y_ind;
	end
	4: begin
    	    x_qr_tmp = 24-qrcode_decode_pos_y[decode_length][decode_cnt-3]+x_ind;
	    y_qr_tmp = qrcode_decode_pos_x[decode_length][decode_cnt-3]+y_ind;
	end
	default: begin
    	    x_qr_tmp = qrcode_decode_pos_x[decode_length][decode_cnt-3]+x_ind;
	    y_qr_tmp = qrcode_decode_pos_y[decode_length][decode_cnt-3]+y_ind;
	end
    endcase
end

always@* begin
    case(rotation_type)
	1: begin
	    x_tmp = qrcode_decode_pos_x[decode_length][decode_cnt]+x_ind;
	    y_tmp = qrcode_decode_pos_y[decode_length][decode_cnt]+y_ind;
	end
	2: begin
	    x_tmp = qrcode_decode_pos_y[decode_length][decode_cnt]+x_ind;
	    y_tmp = 24-qrcode_decode_pos_x[decode_length][decode_cnt]+y_ind;
	end
	3: begin
	    x_tmp = 24-qrcode_decode_pos_x[decode_length][decode_cnt]+x_ind;
	    y_tmp = 24-qrcode_decode_pos_y[decode_length][decode_cnt]+y_ind;
	end
	4: begin
	    x_tmp = 24-qrcode_decode_pos_y[decode_length][decode_cnt]+x_ind;
	    y_tmp = qrcode_decode_pos_x[decode_length][decode_cnt]+y_ind;
	end
	default: begin
	    x_tmp = qrcode_decode_pos_x[decode_length][decode_cnt]+x_ind;
	    y_tmp = qrcode_decode_pos_y[decode_length][decode_cnt]+y_ind;
	end
    endcase
end

always@* begin
    if(state==DECODE_WAIT && store_cnt>2) begin
	mask_pattern_tmp = mask_pattern + sram_rdata_reg <<< ((4-store_cnt)+(4-store_cnt)+(4-store_cnt)+(4-store_cnt));
    end
    else mask_pattern_tmp = mask_pattern; 
    mask_pattern_real = mask ^ 101;
end

always@* begin
    case(rotation_type)
	1: begin
	    case(check)
		1: begin mask = {mask_pattern[4],mask_pattern[5],mask_pattern[0]};end
		2: begin mask = {mask_pattern[5],mask_pattern[0],mask_pattern[1]};end
		3: begin mask = {mask_pattern[6],mask_pattern[7],mask_pattern[2]};end
		4: begin mask = {mask_pattern[7],mask_pattern[2],mask_pattern[3]};end
		default: begin mask = 0; end
	    endcase
	end
	2: begin
	    case(check)
		1: begin mask = {mask_pattern[4],mask_pattern[6],mask_pattern[0]};end
		2: begin mask = {mask_pattern[5],mask_pattern[7],mask_pattern[1]};end
		3: begin mask = {mask_pattern[6],mask_pattern[0],mask_pattern[2]};end
		4: begin mask = {mask_pattern[7],mask_pattern[1],mask_pattern[3]};end
		default: begin mask = 0; end
	    endcase
	end
	3: begin
	    case(check)
		1: begin mask = {mask_pattern[4],mask_pattern[1],mask_pattern[0]};end
		2: begin mask = {mask_pattern[5],mask_pattern[4],mask_pattern[1]};end
		3: begin mask = {mask_pattern[6],mask_pattern[3],mask_pattern[2]};end
		4: begin mask = {mask_pattern[7],mask_pattern[6],mask_pattern[3]};end
		default: begin mask = 0; end
	    endcase
	end
	4: begin
	    case(check)
		1: begin mask = {mask_pattern[4],mask_pattern[2],mask_pattern[0]};end
		2: begin mask = {mask_pattern[5],mask_pattern[3],mask_pattern[1]};end
		3: begin mask = {mask_pattern[6],mask_pattern[4],mask_pattern[2]};end
		4: begin mask = {mask_pattern[7],mask_pattern[5],mask_pattern[3]};end
		default: begin mask = 0; end
	    endcase
	end
	default: begin mask = 0; end
    endcase
end

always@* begin
    case(rotation_type)
	1: begin qrcode_start_tmp = qrcode_start;end // 0 degree
	2: begin qrcode_start_tmp = qrcode_start;end // 90 degree
	3: begin qrcode_start_tmp = qrcode_start-192;end // 180 degree
	4: begin qrcode_start_tmp = qrcode_start-192;end // 270 degree
	default: begin qrcode_start_tmp = qrcode_start;end
    endcase
end
always@* begin
    if(state==DECODE_MASK) begin //find 8, 2:4
	case(rotation_type)
	    1: begin mask_pos = qrcode_start_whole + 129 + store_cnt; end  // 129
	    2: begin mask_pos = qrcode_start_whole + 40  + (store_cnt <<<5);end // 40
	    3: begin mask_pos = qrcode_start_whole + 267 - store_cnt; end  // 267 
	    4: begin mask_pos = qrcode_start_whole + 356 - (store_cnt <<<5); end // 356
	    default: begin mask_pos = qrcode_start_whole+129+store_cnt; end
	endcase
    end
    else mask_pos = qrcode_start_whole;
end
assign qrcode_decode_pos_x[0][7]=5'd22;
assign qrcode_decode_pos_x[0][6]=5'd22;
assign qrcode_decode_pos_x[0][5]=5'd21;
assign qrcode_decode_pos_x[0][4]=5'd21;
assign qrcode_decode_pos_x[0][3]=5'd20;
assign qrcode_decode_pos_x[0][2]=5'd20;
assign qrcode_decode_pos_x[0][1]=5'd19;
assign qrcode_decode_pos_x[0][0]=5'd19;

assign qrcode_decode_pos_x[1][7]=5'd18;
assign qrcode_decode_pos_x[1][6]=5'd18;
assign qrcode_decode_pos_x[1][5]=5'd17;
assign qrcode_decode_pos_x[1][4]=5'd17;
assign qrcode_decode_pos_x[1][3]=5'd16;
assign qrcode_decode_pos_x[1][2]=5'd16;
assign qrcode_decode_pos_x[1][1]=5'd15;
assign qrcode_decode_pos_x[1][0]=5'd15;

assign qrcode_decode_pos_x[2][7]=5'd14;
assign qrcode_decode_pos_x[2][6]=5'd14;
assign qrcode_decode_pos_x[2][5]=5'd13;
assign qrcode_decode_pos_x[2][4]=5'd13;
assign qrcode_decode_pos_x[2][3]=5'd12;
assign qrcode_decode_pos_x[2][2]=5'd12;
assign qrcode_decode_pos_x[2][1]=5'd11;
assign qrcode_decode_pos_x[2][0]=5'd11;

assign qrcode_decode_pos_x[3][7]=5'd10;
assign qrcode_decode_pos_x[3][6]=5'd10;
assign qrcode_decode_pos_x[3][5]=5'd9;
assign qrcode_decode_pos_x[3][4]=5'd9;
assign qrcode_decode_pos_x[3][3]=5'd9;
assign qrcode_decode_pos_x[3][2]=5'd9;
assign qrcode_decode_pos_x[3][1]=5'd10;
assign qrcode_decode_pos_x[3][0]=5'd10;

assign qrcode_decode_pos_x[4][7]=5'd11;
assign qrcode_decode_pos_x[4][6]=5'd11;
assign qrcode_decode_pos_x[4][5]=5'd12;
assign qrcode_decode_pos_x[4][4]=5'd12;
assign qrcode_decode_pos_x[4][3]=5'd13;
assign qrcode_decode_pos_x[4][2]=5'd13;
assign qrcode_decode_pos_x[4][1]=5'd14;
assign qrcode_decode_pos_x[4][0]=5'd14;

assign qrcode_decode_pos_x[5][7]=5'd15;
assign qrcode_decode_pos_x[5][6]=5'd15;
assign qrcode_decode_pos_x[5][5]=5'd16;
assign qrcode_decode_pos_x[5][4]=5'd16;
assign qrcode_decode_pos_x[5][3]=5'd17;
assign qrcode_decode_pos_x[5][2]=5'd17;
assign qrcode_decode_pos_x[5][1]=5'd18;
assign qrcode_decode_pos_x[5][0]=5'd18;

assign qrcode_decode_pos_x[6][7]=5'd19;
assign qrcode_decode_pos_x[6][6]=5'd19;
assign qrcode_decode_pos_x[6][5]=5'd20;
assign qrcode_decode_pos_x[6][4]=5'd20;
assign qrcode_decode_pos_x[6][3]=5'd21;
assign qrcode_decode_pos_x[6][2]=5'd21;
assign qrcode_decode_pos_x[6][1]=5'd22;
assign qrcode_decode_pos_x[6][0]=5'd22;

assign qrcode_decode_pos_x[7][7]=5'd23;
assign qrcode_decode_pos_x[7][6]=5'd23;
assign qrcode_decode_pos_x[7][5]=5'd24;
assign qrcode_decode_pos_x[7][4]=5'd24;
assign qrcode_decode_pos_x[7][3]=5'd24;
assign qrcode_decode_pos_x[7][2]=5'd24;
assign qrcode_decode_pos_x[7][1]=5'd23;
assign qrcode_decode_pos_x[7][0]=5'd23;

assign qrcode_decode_pos_x[8][7]=5'd22;
assign qrcode_decode_pos_x[8][6]=5'd22;
assign qrcode_decode_pos_x[8][5]=5'd21;
assign qrcode_decode_pos_x[8][4]=5'd21;
assign qrcode_decode_pos_x[8][3]=5'd15;
assign qrcode_decode_pos_x[8][2]=5'd15;
assign qrcode_decode_pos_x[8][1]=5'd14;
assign qrcode_decode_pos_x[8][0]=5'd14;

assign qrcode_decode_pos_x[9][7]=5'd13;
assign qrcode_decode_pos_x[9][6]=5'd13;
assign qrcode_decode_pos_x[9][5]=5'd12;
assign qrcode_decode_pos_x[9][4]=5'd12;
assign qrcode_decode_pos_x[9][3]=5'd11;
assign qrcode_decode_pos_x[9][2]=5'd11;
assign qrcode_decode_pos_x[9][1]=5'd10;
assign qrcode_decode_pos_x[9][0]=5'd10;

assign qrcode_decode_pos_x[10][7]=5'd9;
assign qrcode_decode_pos_x[10][6]=5'd9;
assign qrcode_decode_pos_x[10][5]=5'd9;
assign qrcode_decode_pos_x[10][4]=5'd9;
assign qrcode_decode_pos_x[10][3]=5'd10;
assign qrcode_decode_pos_x[10][2]=5'd10;
assign qrcode_decode_pos_x[10][1]=5'd11;
assign qrcode_decode_pos_x[10][0]=5'd11;

assign qrcode_decode_pos_x[11][7]=5'd12;
assign qrcode_decode_pos_x[11][6]=5'd12;
assign qrcode_decode_pos_x[11][5]=5'd13;
assign qrcode_decode_pos_x[11][4]=5'd13;
assign qrcode_decode_pos_x[11][3]=5'd14;
assign qrcode_decode_pos_x[11][2]=5'd14;
assign qrcode_decode_pos_x[11][1]=5'd15;
assign qrcode_decode_pos_x[11][0]=5'd15;

assign qrcode_decode_pos_x[12][7]=5'd21;
assign qrcode_decode_pos_x[12][6]=5'd21;
assign qrcode_decode_pos_x[12][5]=5'd22;
assign qrcode_decode_pos_x[12][4]=5'd22;
assign qrcode_decode_pos_x[12][3]=5'd23;
assign qrcode_decode_pos_x[12][2]=5'd23;
assign qrcode_decode_pos_x[12][1]=5'd24;
assign qrcode_decode_pos_x[12][0]=5'd24;

assign qrcode_decode_pos_x[13][7]=5'd24;
assign qrcode_decode_pos_x[13][6]=5'd24;
assign qrcode_decode_pos_x[13][5]=5'd23;
assign qrcode_decode_pos_x[13][4]=5'd23;
assign qrcode_decode_pos_x[13][3]=5'd22;
assign qrcode_decode_pos_x[13][2]=5'd22;
assign qrcode_decode_pos_x[13][1]=5'd21;
assign qrcode_decode_pos_x[13][0]=5'd21;

assign qrcode_decode_pos_x[14][7]=5'd20;
assign qrcode_decode_pos_x[14][6]=5'd19;
assign qrcode_decode_pos_x[14][5]=5'd18;
assign qrcode_decode_pos_x[14][4]=5'd17;
assign qrcode_decode_pos_x[14][3]=5'd16;
assign qrcode_decode_pos_x[14][2]=5'd15;
assign qrcode_decode_pos_x[14][1]=5'd15;
assign qrcode_decode_pos_x[14][0]=5'd14;

assign qrcode_decode_pos_x[15][7]=5'd14;
assign qrcode_decode_pos_x[15][6]=5'd13;
assign qrcode_decode_pos_x[15][5]=5'd13;
assign qrcode_decode_pos_x[15][4]=5'd12;
assign qrcode_decode_pos_x[15][3]=5'd12;
assign qrcode_decode_pos_x[15][2]=5'd11;
assign qrcode_decode_pos_x[15][1]=5'd11;
assign qrcode_decode_pos_x[15][0]=5'd10;

assign qrcode_decode_pos_x[16][7]=5'd10;
assign qrcode_decode_pos_x[16][6]=5'd9;
assign qrcode_decode_pos_x[16][5]=5'd9;
assign qrcode_decode_pos_x[16][4]=5'd8;
assign qrcode_decode_pos_x[16][3]=5'd8;
assign qrcode_decode_pos_x[16][2]=5'd7;
assign qrcode_decode_pos_x[16][1]=5'd7;
assign qrcode_decode_pos_x[16][0]=5'd5;

assign qrcode_decode_pos_x[17][7]=5'd5;
assign qrcode_decode_pos_x[17][6]=5'd4;
assign qrcode_decode_pos_x[17][5]=5'd4;
assign qrcode_decode_pos_x[17][4]=5'd3;
assign qrcode_decode_pos_x[17][3]=5'd3;
assign qrcode_decode_pos_x[17][2]=5'd2;
assign qrcode_decode_pos_x[17][1]=5'd2;
assign qrcode_decode_pos_x[17][0]=5'd1;

assign qrcode_decode_pos_x[18][7]=5'd1;
assign qrcode_decode_pos_x[18][6]=5'd0;
assign qrcode_decode_pos_x[18][5]=5'd0;
assign qrcode_decode_pos_x[18][4]=5'd0;
assign qrcode_decode_pos_x[18][3]=5'd0;
assign qrcode_decode_pos_x[18][2]=5'd1;
assign qrcode_decode_pos_x[18][1]=5'd1;
assign qrcode_decode_pos_x[18][0]=5'd2;

assign qrcode_decode_pos_x[19][7]=5'd2;
assign qrcode_decode_pos_x[19][6]=5'd3;
assign qrcode_decode_pos_x[19][5]=5'd3;
assign qrcode_decode_pos_x[19][4]=5'd4;
assign qrcode_decode_pos_x[19][3]=5'd4;
assign qrcode_decode_pos_x[19][2]=5'd5;
assign qrcode_decode_pos_x[19][1]=5'd5;
assign qrcode_decode_pos_x[19][0]=5'd7;

assign qrcode_decode_pos_x[20][7]=5'd7;
assign qrcode_decode_pos_x[20][6]=5'd8;
assign qrcode_decode_pos_x[20][5]=5'd8;
assign qrcode_decode_pos_x[20][4]=5'd9;
assign qrcode_decode_pos_x[20][3]=5'd9;
assign qrcode_decode_pos_x[20][2]=5'd10;
assign qrcode_decode_pos_x[20][1]=5'd10;
assign qrcode_decode_pos_x[20][0]=5'd11;

assign qrcode_decode_pos_x[21][7]=5'd11;
assign qrcode_decode_pos_x[21][6]=5'd12;
assign qrcode_decode_pos_x[21][5]=5'd12;
assign qrcode_decode_pos_x[21][4]=5'd13;
assign qrcode_decode_pos_x[21][3]=5'd13;
assign qrcode_decode_pos_x[21][2]=5'd14;
assign qrcode_decode_pos_x[21][1]=5'd14;
assign qrcode_decode_pos_x[21][0]=5'd15;

assign qrcode_decode_pos_x[22][7]=5'd15;
assign qrcode_decode_pos_x[22][6]=5'd16;
assign qrcode_decode_pos_x[22][5]=5'd16;
assign qrcode_decode_pos_x[22][4]=5'd17;
assign qrcode_decode_pos_x[22][3]=5'd17;
assign qrcode_decode_pos_x[22][2]=5'd18;
assign qrcode_decode_pos_x[22][1]=5'd18;
assign qrcode_decode_pos_x[22][0]=5'd19;

assign qrcode_decode_pos_x[23][7]=5'd19;
assign qrcode_decode_pos_x[23][6]=5'd20;
assign qrcode_decode_pos_x[23][5]=5'd20;
assign qrcode_decode_pos_x[23][4]=5'd21;
assign qrcode_decode_pos_x[23][3]=5'd21;
assign qrcode_decode_pos_x[23][2]=5'd22;
assign qrcode_decode_pos_x[23][1]=5'd22;
assign qrcode_decode_pos_x[23][0]=5'd23;

assign qrcode_decode_pos_x[24][7]=5'd23;
assign qrcode_decode_pos_x[24][6]=5'd24;
assign qrcode_decode_pos_x[24][5]=5'd24;
assign qrcode_decode_pos_x[24][4]=5'd24;
assign qrcode_decode_pos_x[24][3]=5'd24;
assign qrcode_decode_pos_x[24][2]=5'd23;
assign qrcode_decode_pos_x[24][1]=5'd23;
assign qrcode_decode_pos_x[24][0]=5'd22;

assign qrcode_decode_pos_x[25][7]=5'd22;
assign qrcode_decode_pos_x[25][6]=5'd21;
assign qrcode_decode_pos_x[25][5]=5'd21;
assign qrcode_decode_pos_x[25][4]=5'd20;
assign qrcode_decode_pos_x[25][3]=5'd20;
assign qrcode_decode_pos_x[25][2]=5'd19;
assign qrcode_decode_pos_x[25][1]=5'd19;
assign qrcode_decode_pos_x[25][0]=5'd18;

assign qrcode_decode_pos_x[26][7]=5'd18;
assign qrcode_decode_pos_x[26][6]=5'd17;
assign qrcode_decode_pos_x[26][5]=5'd17;
assign qrcode_decode_pos_x[26][4]=5'd16;
assign qrcode_decode_pos_x[26][3]=5'd16;
assign qrcode_decode_pos_x[26][2]=5'd15;
assign qrcode_decode_pos_x[26][1]=5'd15;
assign qrcode_decode_pos_x[26][0]=5'd14;

assign qrcode_decode_pos_y[0][7]=5'd24;
assign qrcode_decode_pos_y[0][6]=5'd23;
assign qrcode_decode_pos_y[0][5]=5'd24;
assign qrcode_decode_pos_y[0][4]=5'd23;
assign qrcode_decode_pos_y[0][3]=5'd24;
assign qrcode_decode_pos_y[0][2]=5'd23;
assign qrcode_decode_pos_y[0][1]=5'd24;
assign qrcode_decode_pos_y[0][0]=5'd23;

assign qrcode_decode_pos_y[1][7]=5'd24;
assign qrcode_decode_pos_y[1][6]=5'd23;
assign qrcode_decode_pos_y[1][5]=5'd24;
assign qrcode_decode_pos_y[1][4]=5'd23;
assign qrcode_decode_pos_y[1][3]=5'd24;
assign qrcode_decode_pos_y[1][2]=5'd23;
assign qrcode_decode_pos_y[1][1]=5'd24;
assign qrcode_decode_pos_y[1][0]=5'd23;

assign qrcode_decode_pos_y[2][7]=5'd24;
assign qrcode_decode_pos_y[2][6]=5'd23;
assign qrcode_decode_pos_y[2][5]=5'd24;
assign qrcode_decode_pos_y[2][4]=5'd23;
assign qrcode_decode_pos_y[2][3]=5'd24;
assign qrcode_decode_pos_y[2][2]=5'd23;
assign qrcode_decode_pos_y[2][1]=5'd24;
assign qrcode_decode_pos_y[2][0]=5'd23;

assign qrcode_decode_pos_y[3][7]=5'd24;
assign qrcode_decode_pos_y[3][6]=5'd23;
assign qrcode_decode_pos_y[3][5]=5'd24;
assign qrcode_decode_pos_y[3][4]=5'd23;
assign qrcode_decode_pos_y[3][3]=5'd22;
assign qrcode_decode_pos_y[3][2]=5'd21;
assign qrcode_decode_pos_y[3][1]=5'd22;
assign qrcode_decode_pos_y[3][0]=5'd21;

assign qrcode_decode_pos_y[4][7]=5'd22;
assign qrcode_decode_pos_y[4][6]=5'd21;
assign qrcode_decode_pos_y[4][5]=5'd22;
assign qrcode_decode_pos_y[4][4]=5'd21;
assign qrcode_decode_pos_y[4][3]=5'd22;
assign qrcode_decode_pos_y[4][2]=5'd21;
assign qrcode_decode_pos_y[4][1]=5'd22;
assign qrcode_decode_pos_y[4][0]=5'd21;

assign qrcode_decode_pos_y[5][7]=5'd22;
assign qrcode_decode_pos_y[5][6]=5'd21;
assign qrcode_decode_pos_y[5][5]=5'd22;
assign qrcode_decode_pos_y[5][4]=5'd21;
assign qrcode_decode_pos_y[5][3]=5'd22;
assign qrcode_decode_pos_y[5][2]=5'd21;
assign qrcode_decode_pos_y[5][1]=5'd22;
assign qrcode_decode_pos_y[5][0]=5'd21;

assign qrcode_decode_pos_y[6][7]=5'd22;
assign qrcode_decode_pos_y[6][6]=5'd21;
assign qrcode_decode_pos_y[6][5]=5'd22;
assign qrcode_decode_pos_y[6][4]=5'd21;
assign qrcode_decode_pos_y[6][3]=5'd22;
assign qrcode_decode_pos_y[6][2]=5'd21;
assign qrcode_decode_pos_y[6][1]=5'd22;
assign qrcode_decode_pos_y[6][0]=5'd21;

assign qrcode_decode_pos_y[7][7]=5'd22;
assign qrcode_decode_pos_y[7][6]=5'd21;
assign qrcode_decode_pos_y[7][5]=5'd22;
assign qrcode_decode_pos_y[7][4]=5'd21;
assign qrcode_decode_pos_y[7][3]=5'd20;
assign qrcode_decode_pos_y[7][2]=5'd19;
assign qrcode_decode_pos_y[7][1]=5'd20;
assign qrcode_decode_pos_y[7][0]=5'd19;

assign qrcode_decode_pos_y[8][7]=5'd20;
assign qrcode_decode_pos_y[8][6]=5'd19;
assign qrcode_decode_pos_y[8][5]=5'd20;
assign qrcode_decode_pos_y[8][4]=5'd19;
assign qrcode_decode_pos_y[8][3]=5'd20;
assign qrcode_decode_pos_y[8][2]=5'd19;
assign qrcode_decode_pos_y[8][1]=5'd20;
assign qrcode_decode_pos_y[8][0]=5'd19;

assign qrcode_decode_pos_y[9][7]=5'd20;
assign qrcode_decode_pos_y[9][6]=5'd19;
assign qrcode_decode_pos_y[9][5]=5'd20;
assign qrcode_decode_pos_y[9][4]=5'd19;
assign qrcode_decode_pos_y[9][3]=5'd20;
assign qrcode_decode_pos_y[9][2]=5'd19;
assign qrcode_decode_pos_y[9][1]=5'd20;
assign qrcode_decode_pos_y[9][0]=5'd19;

assign qrcode_decode_pos_y[10][7]=5'd20;
assign qrcode_decode_pos_y[10][6]=5'd19;
assign qrcode_decode_pos_y[10][5]=5'd18;
assign qrcode_decode_pos_y[10][4]=5'd17;
assign qrcode_decode_pos_y[10][3]=5'd18;
assign qrcode_decode_pos_y[10][2]=5'd17;
assign qrcode_decode_pos_y[10][1]=5'd18;
assign qrcode_decode_pos_y[10][0]=5'd17;

assign qrcode_decode_pos_y[11][7]=5'd18;
assign qrcode_decode_pos_y[11][6]=5'd17;
assign qrcode_decode_pos_y[11][5]=5'd18;
assign qrcode_decode_pos_y[11][4]=5'd17;
assign qrcode_decode_pos_y[11][3]=5'd18;
assign qrcode_decode_pos_y[11][2]=5'd17;
assign qrcode_decode_pos_y[11][1]=5'd18;
assign qrcode_decode_pos_y[11][0]=5'd17;

assign qrcode_decode_pos_y[12][7]=5'd18;
assign qrcode_decode_pos_y[12][6]=5'd17;
assign qrcode_decode_pos_y[12][5]=5'd18;
assign qrcode_decode_pos_y[12][4]=5'd17;
assign qrcode_decode_pos_y[12][3]=5'd18;
assign qrcode_decode_pos_y[12][2]=5'd17;
assign qrcode_decode_pos_y[12][1]=5'd18;
assign qrcode_decode_pos_y[12][0]=5'd17;

assign qrcode_decode_pos_y[13][7]=5'd16;
assign qrcode_decode_pos_y[13][6]=5'd15;
assign qrcode_decode_pos_y[13][5]=5'd16;
assign qrcode_decode_pos_y[13][4]=5'd15;
assign qrcode_decode_pos_y[13][3]=5'd16;
assign qrcode_decode_pos_y[13][2]=5'd15;
assign qrcode_decode_pos_y[13][1]=5'd16;
assign qrcode_decode_pos_y[13][0]=5'd15;

assign qrcode_decode_pos_y[14][7]=5'd15;
assign qrcode_decode_pos_y[14][6]=5'd15;
assign qrcode_decode_pos_y[14][5]=5'd15;
assign qrcode_decode_pos_y[14][4]=5'd15;
assign qrcode_decode_pos_y[14][3]=5'd15;
assign qrcode_decode_pos_y[14][2]=5'd16;
assign qrcode_decode_pos_y[14][1]=5'd15;
assign qrcode_decode_pos_y[14][0]=5'd16;

assign qrcode_decode_pos_y[15][7]=5'd15;
assign qrcode_decode_pos_y[15][6]=5'd16;
assign qrcode_decode_pos_y[15][5]=5'd15;
assign qrcode_decode_pos_y[15][4]=5'd16;
assign qrcode_decode_pos_y[15][3]=5'd15;
assign qrcode_decode_pos_y[15][2]=5'd16;
assign qrcode_decode_pos_y[15][1]=5'd15;
assign qrcode_decode_pos_y[15][0]=5'd16;

assign qrcode_decode_pos_y[16][7]=5'd15;
assign qrcode_decode_pos_y[16][6]=5'd16;
assign qrcode_decode_pos_y[16][5]=5'd15;
assign qrcode_decode_pos_y[16][4]=5'd16;
assign qrcode_decode_pos_y[16][3]=5'd15;
assign qrcode_decode_pos_y[16][2]=5'd16;
assign qrcode_decode_pos_y[16][1]=5'd15;
assign qrcode_decode_pos_y[16][0]=5'd16;

assign qrcode_decode_pos_y[17][7]=5'd15;
assign qrcode_decode_pos_y[17][6]=5'd16;
assign qrcode_decode_pos_y[17][5]=5'd15;
assign qrcode_decode_pos_y[17][4]=5'd16;
assign qrcode_decode_pos_y[17][3]=5'd15;
assign qrcode_decode_pos_y[17][2]=5'd16;
assign qrcode_decode_pos_y[17][1]=5'd15;
assign qrcode_decode_pos_y[17][0]=5'd16;

assign qrcode_decode_pos_y[18][7]=5'd15;
assign qrcode_decode_pos_y[18][6]=5'd16;
assign qrcode_decode_pos_y[18][5]=5'd15;
assign qrcode_decode_pos_y[18][4]=5'd14;
assign qrcode_decode_pos_y[18][3]=5'd13;
assign qrcode_decode_pos_y[18][2]=5'd14;
assign qrcode_decode_pos_y[18][1]=5'd13;
assign qrcode_decode_pos_y[18][0]=5'd14;

assign qrcode_decode_pos_y[19][7]=5'd13;
assign qrcode_decode_pos_y[19][6]=5'd14;
assign qrcode_decode_pos_y[19][5]=5'd13;
assign qrcode_decode_pos_y[19][4]=5'd14;
assign qrcode_decode_pos_y[19][3]=5'd13;
assign qrcode_decode_pos_y[19][2]=5'd14;
assign qrcode_decode_pos_y[19][1]=5'd13;
assign qrcode_decode_pos_y[19][0]=5'd14;

assign qrcode_decode_pos_y[20][7]=5'd13;
assign qrcode_decode_pos_y[20][6]=5'd14;
assign qrcode_decode_pos_y[20][5]=5'd13;
assign qrcode_decode_pos_y[20][4]=5'd14;
assign qrcode_decode_pos_y[20][3]=5'd13;
assign qrcode_decode_pos_y[20][2]=5'd14;
assign qrcode_decode_pos_y[20][1]=5'd13;
assign qrcode_decode_pos_y[20][0]=5'd14;

assign qrcode_decode_pos_y[21][7]=5'd13;
assign qrcode_decode_pos_y[21][6]=5'd14;
assign qrcode_decode_pos_y[21][5]=5'd13;
assign qrcode_decode_pos_y[21][4]=5'd14;
assign qrcode_decode_pos_y[21][3]=5'd13;
assign qrcode_decode_pos_y[21][2]=5'd14;
assign qrcode_decode_pos_y[21][1]=5'd13;
assign qrcode_decode_pos_y[21][0]=5'd14;

assign qrcode_decode_pos_y[22][7]=5'd13;
assign qrcode_decode_pos_y[22][6]=5'd14;
assign qrcode_decode_pos_y[22][5]=5'd13;
assign qrcode_decode_pos_y[22][4]=5'd14;
assign qrcode_decode_pos_y[22][3]=5'd13;
assign qrcode_decode_pos_y[22][2]=5'd14;
assign qrcode_decode_pos_y[22][1]=5'd13;
assign qrcode_decode_pos_y[22][0]=5'd14;

assign qrcode_decode_pos_y[23][7]=5'd13;
assign qrcode_decode_pos_y[23][6]=5'd14;
assign qrcode_decode_pos_y[23][5]=5'd13;
assign qrcode_decode_pos_y[23][4]=5'd14;
assign qrcode_decode_pos_y[23][3]=5'd13;
assign qrcode_decode_pos_y[23][2]=5'd14;
assign qrcode_decode_pos_y[23][1]=5'd13;
assign qrcode_decode_pos_y[23][0]=5'd14;

assign qrcode_decode_pos_y[24][7]=5'd13;
assign qrcode_decode_pos_y[24][6]=5'd14;
assign qrcode_decode_pos_y[24][5]=5'd13;
assign qrcode_decode_pos_y[24][4]=5'd12;
assign qrcode_decode_pos_y[24][3]=5'd11;
assign qrcode_decode_pos_y[24][2]=5'd12;
assign qrcode_decode_pos_y[24][1]=5'd11;
assign qrcode_decode_pos_y[24][0]=5'd12;

assign qrcode_decode_pos_y[25][7]=5'd11;
assign qrcode_decode_pos_y[25][6]=5'd12;
assign qrcode_decode_pos_y[25][5]=5'd11;
assign qrcode_decode_pos_y[25][4]=5'd12;
assign qrcode_decode_pos_y[25][3]=5'd11;
assign qrcode_decode_pos_y[25][2]=5'd12;
assign qrcode_decode_pos_y[25][1]=5'd11;
assign qrcode_decode_pos_y[25][0]=5'd12;

assign qrcode_decode_pos_y[26][7]=5'd11;
assign qrcode_decode_pos_y[26][6]=5'd12;
assign qrcode_decode_pos_y[26][5]=5'd11;
assign qrcode_decode_pos_y[26][4]=5'd12;
assign qrcode_decode_pos_y[26][3]=5'd11;
assign qrcode_decode_pos_y[26][2]=5'd12;
assign qrcode_decode_pos_y[26][1]=5'd11;
assign qrcode_decode_pos_y[26][0]=5'd12;

assign mask_message[0][0]  = 8'b10011001;
assign mask_message[0][1]  = 8'b10011001;
assign mask_message[0][2]  = 8'b10010110;
assign mask_message[0][3]  = 8'b01100110;
assign mask_message[0][4]  = 8'b01100110;
assign mask_message[0][5]  = 8'b01100110;
assign mask_message[0][6]  = 8'b01101001;
assign mask_message[0][7]  = 8'b10010110;
assign mask_message[0][8]  = 8'b01100110;
assign mask_message[0][9]  = 8'b01011001;
assign mask_message[0][10] = 8'b10011001;
assign mask_message[0][11] = 8'b01100110;
assign mask_message[0][12] = 8'b10011001;
assign mask_message[0][13] = 8'b01010011;
assign mask_message[0][14] = 8'b00110011;
assign mask_message[0][15] = 8'b00110010;
assign mask_message[0][16] = 8'b11001100;
assign mask_message[0][17] = 8'b11010011;
assign mask_message[0][18] = 8'b00110010;
assign mask_message[0][19] = 8'b11001100;
assign mask_message[0][20] = 8'b11001100;
assign mask_message[0][21] = 8'b11001100;
assign mask_message[0][22] = 8'b11001100;
assign mask_message[0][23] = 8'b11010011;
assign mask_message[0][24] = 8'b00110011;
assign mask_message[0][25] = 8'b00110011;

assign mask_message[1][0]  = 8'b11001100;
assign mask_message[1][1]  = 8'b11001100;
assign mask_message[1][2]  = 8'b11000011;
assign mask_message[1][3]  = 8'b00110011;
assign mask_message[1][4]  = 8'b00110011;
assign mask_message[1][5]  = 8'b00110011;
assign mask_message[1][6]  = 8'b00111100;
assign mask_message[1][7]  = 8'b11000011;
assign mask_message[1][8]  = 8'b00110011;
assign mask_message[1][9]  = 8'b00001100;
assign mask_message[1][10] = 8'b11001100;
assign mask_message[1][11] = 8'b00110011;
assign mask_message[1][12] = 8'b11001100;
assign mask_message[1][13] = 8'b10101001;
assign mask_message[1][14] = 8'b10011001;
assign mask_message[1][15] = 8'b10011000;
assign mask_message[1][16] = 8'b01100110;
assign mask_message[1][17] = 8'b01111001;
assign mask_message[1][18] = 8'b10011000;
assign mask_message[1][19] = 8'b01100110;
assign mask_message[1][20] = 8'b01100110;
assign mask_message[1][21] = 8'b01100110;
assign mask_message[1][22] = 8'b01100110;
assign mask_message[1][23] = 8'b01111001;
assign mask_message[1][24] = 8'b10011001;
assign mask_message[1][25] = 8'b10011001;

assign mask_message[2][0]  = 8'b10101010;
assign mask_message[2][1]  = 8'b10101010;
assign mask_message[2][2]  = 8'b10100101;
assign mask_message[2][3]  = 8'b01010101;
assign mask_message[2][4]  = 8'b01010101;
assign mask_message[2][5]  = 8'b01010101;
assign mask_message[2][6]  = 8'b01010000;
assign mask_message[2][7]  = 8'b00000000;
assign mask_message[2][8]  = 8'b00000000;
assign mask_message[2][9]  = 8'b00101010;
assign mask_message[2][10] = 8'b10101010;
assign mask_message[2][11] = 8'b10101010;
assign mask_message[2][12] = 8'b01010101;
assign mask_message[2][13] = 8'b11111010;
assign mask_message[2][14] = 8'b10101010;
assign mask_message[2][15] = 8'b10101010;
assign mask_message[2][16] = 8'b10101010;
assign mask_message[2][17] = 8'b10100000;
assign mask_message[2][18] = 8'b00000000;
assign mask_message[2][19] = 8'b00000000;
assign mask_message[2][20] = 8'b00000000;
assign mask_message[2][21] = 8'b00000000;
assign mask_message[2][22] = 8'b00000000;
assign mask_message[2][23] = 8'b00010101;
assign mask_message[2][24] = 8'b01010101;
assign mask_message[2][25] = 8'b01010101;

assign mask_message[3][0]  = 8'b10000110;
assign mask_message[3][1]  = 8'b00011000;
assign mask_message[3][2]  = 8'b01100100;
assign mask_message[3][3]  = 8'b10010010;
assign mask_message[3][4]  = 8'b01001001;
assign mask_message[3][5]  = 8'b00100100;
assign mask_message[3][6]  = 8'b10010001;
assign mask_message[3][7]  = 8'b10000001;
assign mask_message[3][8]  = 8'b10000110;
assign mask_message[3][9]  = 8'b00100100;
assign mask_message[3][10] = 8'b10010010;
assign mask_message[3][11] = 8'b10010010;
assign mask_message[3][12] = 8'b01100001;
assign mask_message[3][13] = 8'b00100011;
assign mask_message[3][14] = 8'b00001100;
assign mask_message[3][15] = 8'b00110001;
assign mask_message[3][16] = 8'b00001100;
assign mask_message[3][17] = 8'b00100100;
assign mask_message[3][18] = 8'b10010011;
assign mask_message[3][19] = 8'b00100100;
assign mask_message[3][20] = 8'b10010010;
assign mask_message[3][21] = 8'b01001001;
assign mask_message[3][22] = 8'b00100100;
assign mask_message[3][23] = 8'b10010000;
assign mask_message[3][24] = 8'b11000011;
assign mask_message[3][25] = 8'b00001100;

assign mask_message[4][0] = 8'b01101001;
assign mask_message[4][1] = 8'b01101001;
assign mask_message[4][2] = 8'b01100011;
assign mask_message[4][3] = 8'b11000011;
assign mask_message[4][4] = 8'b11000011;
assign mask_message[4][5] = 8'b11000011;
assign mask_message[4][6] = 8'b11001100;
assign mask_message[4][7] = 8'b00110000;
assign mask_message[4][8] = 8'b11110000;
assign mask_message[4][9] = 8'b11100101;
assign mask_message[4][10] = 8'b10100101;
assign mask_message[4][11] = 8'b10010110;
assign mask_message[4][12] = 8'b00111100;
assign mask_message[4][13] = 8'b01100111;
assign mask_message[4][14] = 8'b10000111;
assign mask_message[4][15] = 8'b10000110;
assign mask_message[4][16] = 8'b00011110;
assign mask_message[4][17] = 8'b00011110;
assign mask_message[4][18] = 8'b00011110;
assign mask_message[4][19] = 8'b01111000;
assign mask_message[4][20] = 8'b01111000;
assign mask_message[4][21] = 8'b01111000;
assign mask_message[4][22] = 8'b01111000;
assign mask_message[4][23] = 8'b01110010;
assign mask_message[4][24] = 8'b11010010;
assign mask_message[4][25] = 8'b11010010;

assign mask_message[5][0]  = 8'b11101010;
assign mask_message[5][1]  = 8'b10101110;
assign mask_message[5][2]  = 8'b10101001;
assign mask_message[5][3]  = 8'b00110001;
assign mask_message[5][4]  = 8'b10010011;
assign mask_message[5][5]  = 8'b00011001;
assign mask_message[5][6]  = 8'b00111100;
assign mask_message[5][7]  = 8'b00101000;
assign mask_message[5][8]  = 8'b00110000;
assign mask_message[5][9]  = 8'b10101010;
assign mask_message[5][10] = 8'b11101010;
assign mask_message[5][11] = 8'b10101011;
assign mask_message[5][12] = 8'b11000110;
assign mask_message[5][13] = 8'b10101100;
assign mask_message[5][14] = 8'b10011000;
assign mask_message[5][15] = 8'b11001000;
assign mask_message[5][16] = 8'b00110010;
assign mask_message[5][17] = 8'b01111000;
assign mask_message[5][18] = 8'b01000000;
assign mask_message[5][19] = 8'b00010000;
assign mask_message[5][20] = 8'b01100001;
assign mask_message[5][21] = 8'b00000110;
assign mask_message[5][22] = 8'b00010000;
assign mask_message[5][23] = 8'b01111101;
assign mask_message[5][24] = 8'b01010101;
assign mask_message[5][25] = 8'b11010101;

assign mask_message[6][0] = 8'b11111110;
assign mask_message[6][1] = 8'b10101111;
assign mask_message[6][2] = 8'b11101001;
assign mask_message[6][3] = 8'b10110011;
assign mask_message[6][4] = 8'b10011011;
assign mask_message[6][5] = 8'b00111001;
assign mask_message[6][6] = 8'b10111100;
assign mask_message[6][7] = 8'b10101001;
assign mask_message[6][8] = 8'b11110010;
assign mask_message[6][9] = 8'b10101111;
assign mask_message[6][10] = 8'b11101010;
assign mask_message[6][11] = 8'b10111111;
assign mask_message[6][12] = 8'b11100110;
assign mask_message[6][13] = 8'b10101101;
assign mask_message[6][14] = 8'b10011100;
assign mask_message[6][15] = 8'b11011001;
assign mask_message[6][16] = 8'b00110110;
assign mask_message[6][17] = 8'b01111110;
assign mask_message[6][18] = 8'b11010001;
assign mask_message[6][19] = 8'b10110100;
assign mask_message[6][20] = 8'b01111011;
assign mask_message[6][21] = 8'b01000111;
assign mask_message[6][22] = 8'b10110100;
assign mask_message[6][23] = 8'b01111111;
assign mask_message[6][24] = 8'b11010101;
assign mask_message[6][25] = 8'b11111101;

assign mask_message[7][0]  = 8'b10001001;
assign mask_message[7][1]  = 8'b11011000;
assign mask_message[7][2]  = 8'b10010100;
assign mask_message[7][3]  = 8'b01101110;
assign mask_message[7][4]  = 8'b01000110;
assign mask_message[7][5]  = 8'b11100100;
assign mask_message[7][6]  = 8'b01101011;
assign mask_message[7][7]  = 8'b11010100;
assign mask_message[7][8]  = 8'b00101111;
assign mask_message[7][9]  = 8'b01011000;
assign mask_message[7][10] = 8'b10011101;
assign mask_message[7][11] = 8'b01100010;
assign mask_message[7][12] = 8'b10010001;
assign mask_message[7][13] = 8'b01010011;
assign mask_message[7][14] = 8'b01110010;
assign mask_message[7][15] = 8'b00110110;
assign mask_message[7][16] = 8'b10001101;
assign mask_message[7][17] = 8'b11010000;
assign mask_message[7][18] = 8'b00111110;
assign mask_message[7][19] = 8'b00001111;
assign mask_message[7][20] = 8'b11000000;
assign mask_message[7][21] = 8'b11111100;
assign mask_message[7][22] = 8'b00001111;
assign mask_message[7][23] = 8'b11010001;
assign mask_message[7][24] = 8'b00111011;
assign mask_message[7][25] = 8'b00010011;
endmodule



