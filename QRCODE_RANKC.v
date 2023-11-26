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
parameter QR_LEN = 25;
parameter IDLE = 4'd0, MEM = 4'd1, ROTATE = 4'd2, DECODE = 4'd3, SEND_OUTPUT = 4'd4, FINISH = 4'd5;
reg [4-1:0] state, state_n;            // for FSM state
reg [32-1:0] read_cnt, read_cnt_n;
reg [8-1:0] decode_cnt, decode_cnt_n;
reg [6-1:0] img_r, img_c, img_r_next, img_c_next;
// reg [QR_LEN-1:0] qr_in [QR_LEN-1:0];
// reg [QR_LEN-1:0] qr_in_next [QR_LEN-1:0];
// reg [QR_LEN-1:0] qr_demask [QR_LEN-1:0];
reg [QR_LEN-1:0] qr_in [0:27];
reg [QR_LEN-1:0] qr_in_next [0:27];
reg [QR_LEN-1:0] qr_demask [0:27];
reg [8-1:0] codeword_origin [0:44-1];
reg [8-1:0] codeword_origin_next [0:44-1];
reg decode_valid_next;
reg [7:0] decode_jis8_code_next;
reg [7:0] text_length;
reg [15:0] sram_rdata_reg;
reg [9:0] sram_raddr_reg;
reg [6-1:0] UL_sum, UR_sum, LL_sum, LR_sum;
reg [8-1:0] send_output_cnt, send_output_cnt_next;

reg qr_decode_finish_reg;
reg find_qrcode, find_qrcode_next;
reg [6-1:0] first_r, first_c, first_r_next, first_c_next;
integer i, j;
always @(posedge clk) begin
    if(~srstn)
        sram_rdata_reg <= 0;
    else
        sram_rdata_reg <= sram_rdata;
end
always @(posedge clk) begin
    if(~srstn)
        decode_valid <= 0;
    else
        decode_valid <= decode_valid_next;
end
always @(posedge clk) begin
    if(~srstn)
        qr_decode_finish <= 0;
    else
        qr_decode_finish <= qr_decode_finish_reg;
end
always @(posedge clk) begin
    if(!srstn)
        for (i = 0; i < 28; i = i + 1) begin
            qr_in[i] <= 0;
        end
    else
        for (i = 0; i < 28; i = i + 1) begin
            qr_in[i] <= qr_in_next[i];
        end
end
always @(posedge clk) begin
    if(!srstn)
        state <= 0;
    else
        state <= state_n;
end
always @* begin
    if (state == MEM) begin
        case (sram_raddr) // qr_in_next[3][3:0] = sram_rdata_reg[12 +: 4] [15:12]
            10'd1: for (i = 0; i < 4; i = i + 1) qr_in_next[i][3:0] = sram_rdata_reg[4*i +: 4]; //[0][3:0] 3:0, [1][3:0] 
            10'd2: for (i = 0; i < 4; i = i + 1) qr_in_next[i][7:4] = sram_rdata_reg[4*i +: 4]; 
            10'd3: for (i = 0; i < 4; i = i + 1) qr_in_next[i][11:8] = sram_rdata_reg[4*i +: 4];
            10'd4: for (i = 0; i < 4; i = i + 1) qr_in_next[i][15:12] = sram_rdata_reg[4*i +: 4];
            10'd5: for (i = 0; i < 4; i = i + 1) qr_in_next[i][19:16] = sram_rdata_reg[4*i +: 4];
            10'd6: for (i = 0; i < 4; i = i + 1) qr_in_next[i][23:20] = sram_rdata_reg[4*i +: 4];
            10'd32: for (i = 0; i < 4; i = i + 1) qr_in_next[i][24] = sram_rdata_reg[4*i];
//           10'd32: for (i = 0; i < 1; i = i + 1) qr_in_next[i][27:24] = sram_rdata_reg[4*i +: 4];

            10'd33: for (i = 0; i < 4; i = i + 1) qr_in_next[i+4][3:0] = sram_rdata_reg[4*i +: 4];
            10'd34: for (i = 0; i < 4; i = i + 1) qr_in_next[i+4][7:4] = sram_rdata_reg[4*i +: 4];
            10'd35: for (i = 0; i < 4; i = i + 1) qr_in_next[i+4][11:8] = sram_rdata_reg[4*i +: 4];
            10'd36: for (i = 0; i < 4; i = i + 1) qr_in_next[i+4][15:12] = sram_rdata_reg[4*i +: 4];
            10'd37: for (i = 0; i < 4; i = i + 1) qr_in_next[i+4][19:16] = sram_rdata_reg[4*i +: 4];
            10'd38: for (i = 0; i < 4; i = i + 1) qr_in_next[i+4][23:20] = sram_rdata_reg[4*i +: 4];
            10'd64: for (i = 0; i < 4; i = i + 1) qr_in_next[i+4][24] = sram_rdata_reg[4*i];
            // 10'd64: for (i = 0; i < 4; i = i + 1) qr_in_next[i+4][27:24] = sram_rdata_reg[4*i +: 4];

            10'd65: for (i = 0; i < 4; i = i + 1) qr_in_next[i+8][3:0] = sram_rdata_reg[4*i +: 4];
            10'd66: for (i = 0; i < 4; i = i + 1) qr_in_next[i+8][7:4] = sram_rdata_reg[4*i +: 4];
            10'd67: for (i = 0; i < 4; i = i + 1) qr_in_next[i+8][11:8] = sram_rdata_reg[4*i +: 4];
            10'd68: for (i = 0; i < 4; i = i + 1) qr_in_next[i+8][15:12] = sram_rdata_reg[4*i +: 4];
            10'd69: for (i = 0; i < 4; i = i + 1) qr_in_next[i+8][19:16] = sram_rdata_reg[4*i +: 4];
            10'd70: for (i = 0; i < 4; i = i + 1) qr_in_next[i+8][23:20] = sram_rdata_reg[4*i +: 4];
            //10'd96: for (i = 0; i < 4; i = i + 1) qr_in_next[i+8][27:24] = sram_rdata_reg[4*i +: 4];
            10'd96: for (i = 0; i < 4; i = i + 1) qr_in_next[i+8][24] = sram_rdata_reg[4*i];

            10'd97: for (i = 0; i < 4; i = i + 1) qr_in_next[i+12][3:0] = sram_rdata_reg[4*i +: 4];
            10'd98: for (i = 0; i < 4; i = i + 1) qr_in_next[i+12][7:4] = sram_rdata_reg[4*i +: 4];
            10'd99: for (i = 0; i < 4; i = i + 1) qr_in_next[i+12][11:8] = sram_rdata_reg[4*i +: 4];
            10'd100: for (i = 0; i < 4; i = i + 1) qr_in_next[i+12][15:12] = sram_rdata_reg[4*i +: 4];
            10'd101: for (i = 0; i < 4; i = i + 1) qr_in_next[i+12][19:16] = sram_rdata_reg[4*i +: 4];
            10'd102: for (i = 0; i < 4; i = i + 1) qr_in_next[i+12][23:20] = sram_rdata_reg[4*i +: 4];
        //    10'd128: for (i = 0; i < 4; i = i + 1) qr_in_next[i+12][27:24] = sram_rdata_reg[4*i +: 4];
            10'd128: for (i = 0; i < 4; i = i + 1) qr_in_next[i+12][24] = sram_rdata_reg[4*i];

            10'd129: for (i = 0; i < 4; i = i + 1) qr_in_next[i+16][3:0] = sram_rdata_reg[4*i +: 4];
            10'd130: for (i = 0; i < 4; i = i + 1) qr_in_next[i+16][7:4] = sram_rdata_reg[4*i +: 4];
            10'd131: for (i = 0; i < 4; i = i + 1) qr_in_next[i+16][11:8] = sram_rdata_reg[4*i +: 4];
            10'd132: for (i = 0; i < 4; i = i + 1) qr_in_next[i+16][15:12] = sram_rdata_reg[4*i +: 4];
            10'd133: for (i = 0; i < 4; i = i + 1) qr_in_next[i+16][19:16] = sram_rdata_reg[4*i +: 4];
            10'd134: for (i = 0; i < 4; i = i + 1) qr_in_next[i+16][23:20] = sram_rdata_reg[4*i +: 4];
        //    10'd160: for (i = 0; i < 4; i = i + 1) qr_in_next[i+16][27:24] = sram_rdata_reg[4*i +: 4];
            10'd160: for (i = 0; i < 4; i = i + 1) qr_in_next[i+16][24] = sram_rdata_reg[4*i];

            10'd161: for (i = 0; i < 4; i = i + 1) qr_in_next[i+20][3:0] = sram_rdata_reg[4*i +: 4];
            10'd162: for (i = 0; i < 4; i = i + 1) qr_in_next[i+20][7:4] = sram_rdata_reg[4*i +: 4];
            10'd163: for (i = 0; i < 4; i = i + 1) qr_in_next[i+20][11:8] = sram_rdata_reg[4*i +: 4];
            10'd164: for (i = 0; i < 4; i = i + 1) qr_in_next[i+20][15:12] = sram_rdata_reg[4*i +: 4];
            10'd165: for (i = 0; i < 4; i = i + 1) qr_in_next[i+20][19:16] = sram_rdata_reg[4*i +: 4];
            10'd166: for (i = 0; i < 4; i = i + 1) qr_in_next[i+20][23:20] = sram_rdata_reg[4*i +: 4];
       //     10'd192: for (i = 0; i < 4; i = i + 1) qr_in_next[i+20][27:24] = sram_rdata_reg[4*i +: 4];
            10'd192: for (i = 0; i < 4; i = i + 1) qr_in_next[i+20][24] = sram_rdata_reg[4*i];

            10'd193: for (i = 0; i < 4; i = i + 1) qr_in_next[i+24][3:0] = sram_rdata_reg[4*i +: 4];
            10'd194: for (i = 0; i < 4; i = i + 1) qr_in_next[i+24][7:4] = sram_rdata_reg[4*i +: 4];
            10'd195: for (i = 0; i < 4; i = i + 1) qr_in_next[i+24][11:8] = sram_rdata_reg[4*i +: 4];
            10'd196: for (i = 0; i < 4; i = i + 1) qr_in_next[i+24][15:12] = sram_rdata_reg[4*i +: 4];
            10'd197: for (i = 0; i < 4; i = i + 1) qr_in_next[i+24][19:16] = sram_rdata_reg[4*i +: 4];
            10'd198: for (i = 0; i < 4; i = i + 1) qr_in_next[i+24][23:20] = sram_rdata_reg[4*i +: 4];
           // 10'd199: for (i = 0; i < 4; i = i + 1) qr_in_next[i+24][27:24] = sram_rdata_reg[4*i +: 4];
            10'd199: for (i = 0; i < 4; i = i + 1) qr_in_next[i+24][24] = sram_rdata_reg[4*i];
            // default: begin
            //     QR[0][0] = QR[0][0];
            //     // for (j = 0; j < 27; j = j + 1) begin
            //     //     for (i = 0; i < 27; i = i + 1) begin
            //     //         QR[i][j] = QR[i][j];
            //     //     end
            //     // end
            // end
        endcase
    end
    else if (state == ROTATE && UL_sum + LL_sum + LR_sum == 27) begin
        // rotate right 90 deg
        qr_in_next[0] = {qr_in[0][0], qr_in[1][0], qr_in[2][0], qr_in[3][0], qr_in[4][0], qr_in[5][0], qr_in[6][0], qr_in[7][0], qr_in[8][0], qr_in[9][0], qr_in[10][0], qr_in[11][0], qr_in[12][0], qr_in[13][0], qr_in[14][0], qr_in[15][0], qr_in[16][0], qr_in[17][0], qr_in[18][0], qr_in[19][0], qr_in[20][0], qr_in[21][0], qr_in[22][0], qr_in[23][0], qr_in[24][0]};
        qr_in_next[1] = {qr_in[0][1], qr_in[1][1], qr_in[2][1], qr_in[3][1], qr_in[4][1], qr_in[5][1], qr_in[6][1], qr_in[7][1], qr_in[8][1], qr_in[9][1], qr_in[10][1], qr_in[11][1], qr_in[12][1], qr_in[13][1], qr_in[14][1], qr_in[15][1], qr_in[16][1], qr_in[17][1], qr_in[18][1], qr_in[19][1], qr_in[20][1], qr_in[21][1], qr_in[22][1], qr_in[23][1], qr_in[24][1]};
        qr_in_next[2] = {qr_in[0][2], qr_in[1][2], qr_in[2][2], qr_in[3][2], qr_in[4][2], qr_in[5][2], qr_in[6][2], qr_in[7][2], qr_in[8][2], qr_in[9][2], qr_in[10][2], qr_in[11][2], qr_in[12][2], qr_in[13][2], qr_in[14][2], qr_in[15][2], qr_in[16][2], qr_in[17][2], qr_in[18][2], qr_in[19][2], qr_in[20][2], qr_in[21][2], qr_in[22][2], qr_in[23][2], qr_in[24][2]};
        qr_in_next[3] = {qr_in[0][3], qr_in[1][3], qr_in[2][3], qr_in[3][3], qr_in[4][3], qr_in[5][3], qr_in[6][3], qr_in[7][3], qr_in[8][3], qr_in[9][3], qr_in[10][3], qr_in[11][3], qr_in[12][3], qr_in[13][3], qr_in[14][3], qr_in[15][3], qr_in[16][3], qr_in[17][3], qr_in[18][3], qr_in[19][3], qr_in[20][3], qr_in[21][3], qr_in[22][3], qr_in[23][3], qr_in[24][3]};
        qr_in_next[4] = {qr_in[0][4], qr_in[1][4], qr_in[2][4], qr_in[3][4], qr_in[4][4], qr_in[5][4], qr_in[6][4], qr_in[7][4], qr_in[8][4], qr_in[9][4], qr_in[10][4], qr_in[11][4], qr_in[12][4], qr_in[13][4], qr_in[14][4], qr_in[15][4], qr_in[16][4], qr_in[17][4], qr_in[18][4], qr_in[19][4], qr_in[20][4], qr_in[21][4], qr_in[22][4], qr_in[23][4], qr_in[24][4]};
        qr_in_next[5] = {qr_in[0][5], qr_in[1][5], qr_in[2][5], qr_in[3][5], qr_in[4][5], qr_in[5][5], qr_in[6][5], qr_in[7][5], qr_in[8][5], qr_in[9][5], qr_in[10][5], qr_in[11][5], qr_in[12][5], qr_in[13][5], qr_in[14][5], qr_in[15][5], qr_in[16][5], qr_in[17][5], qr_in[18][5], qr_in[19][5], qr_in[20][5], qr_in[21][5], qr_in[22][5], qr_in[23][5], qr_in[24][5]};
        qr_in_next[6] = {qr_in[0][6], qr_in[1][6], qr_in[2][6], qr_in[3][6], qr_in[4][6], qr_in[5][6], qr_in[6][6], qr_in[7][6], qr_in[8][6], qr_in[9][6], qr_in[10][6], qr_in[11][6], qr_in[12][6], qr_in[13][6], qr_in[14][6], qr_in[15][6], qr_in[16][6], qr_in[17][6], qr_in[18][6], qr_in[19][6], qr_in[20][6], qr_in[21][6], qr_in[22][6], qr_in[23][6], qr_in[24][6]};
        qr_in_next[7] = {qr_in[0][7], qr_in[1][7], qr_in[2][7], qr_in[3][7], qr_in[4][7], qr_in[5][7], qr_in[6][7], qr_in[7][7], qr_in[8][7], qr_in[9][7], qr_in[10][7], qr_in[11][7], qr_in[12][7], qr_in[13][7], qr_in[14][7], qr_in[15][7], qr_in[16][7], qr_in[17][7], qr_in[18][7], qr_in[19][7], qr_in[20][7], qr_in[21][7], qr_in[22][7], qr_in[23][7], qr_in[24][7]};
        qr_in_next[8] = {qr_in[0][8], qr_in[1][8], qr_in[2][8], qr_in[3][8], qr_in[4][8], qr_in[5][8], qr_in[6][8], qr_in[7][8], qr_in[8][8], qr_in[9][8], qr_in[10][8], qr_in[11][8], qr_in[12][8], qr_in[13][8], qr_in[14][8], qr_in[15][8], qr_in[16][8], qr_in[17][8], qr_in[18][8], qr_in[19][8], qr_in[20][8], qr_in[21][8], qr_in[22][8], qr_in[23][8], qr_in[24][8]};
        qr_in_next[9] = {qr_in[0][9], qr_in[1][9], qr_in[2][9], qr_in[3][9], qr_in[4][9], qr_in[5][9], qr_in[6][9], qr_in[7][9], qr_in[8][9], qr_in[9][9], qr_in[10][9], qr_in[11][9], qr_in[12][9], qr_in[13][9], qr_in[14][9], qr_in[15][9], qr_in[16][9], qr_in[17][9], qr_in[18][9], qr_in[19][9], qr_in[20][9], qr_in[21][9], qr_in[22][9], qr_in[23][9], qr_in[24][9]};
        qr_in_next[10] = {qr_in[0][10], qr_in[1][10], qr_in[2][10], qr_in[3][10], qr_in[4][10], qr_in[5][10], qr_in[6][10], qr_in[7][10], qr_in[8][10], qr_in[9][10], qr_in[10][10], qr_in[11][10], qr_in[12][10], qr_in[13][10], qr_in[14][10], qr_in[15][10], qr_in[16][10], qr_in[17][10], qr_in[18][10], qr_in[19][10], qr_in[20][10], qr_in[21][10], qr_in[22][10], qr_in[23][10], qr_in[24][10]};
        qr_in_next[11] = {qr_in[0][11], qr_in[1][11], qr_in[2][11], qr_in[3][11], qr_in[4][11], qr_in[5][11], qr_in[6][11], qr_in[7][11], qr_in[8][11], qr_in[9][11], qr_in[10][11], qr_in[11][11], qr_in[12][11], qr_in[13][11], qr_in[14][11], qr_in[15][11], qr_in[16][11], qr_in[17][11], qr_in[18][11], qr_in[19][11], qr_in[20][11], qr_in[21][11], qr_in[22][11], qr_in[23][11], qr_in[24][11]};
        qr_in_next[12] = {qr_in[0][12], qr_in[1][12], qr_in[2][12], qr_in[3][12], qr_in[4][12], qr_in[5][12], qr_in[6][12], qr_in[7][12], qr_in[8][12], qr_in[9][12], qr_in[10][12], qr_in[11][12], qr_in[12][12], qr_in[13][12], qr_in[14][12], qr_in[15][12], qr_in[16][12], qr_in[17][12], qr_in[18][12], qr_in[19][12], qr_in[20][12], qr_in[21][12], qr_in[22][12], qr_in[23][12], qr_in[24][12]};
        qr_in_next[13] = {qr_in[0][13], qr_in[1][13], qr_in[2][13], qr_in[3][13], qr_in[4][13], qr_in[5][13], qr_in[6][13], qr_in[7][13], qr_in[8][13], qr_in[9][13], qr_in[10][13], qr_in[11][13], qr_in[12][13], qr_in[13][13], qr_in[14][13], qr_in[15][13], qr_in[16][13], qr_in[17][13], qr_in[18][13], qr_in[19][13], qr_in[20][13], qr_in[21][13], qr_in[22][13], qr_in[23][13], qr_in[24][13]};
        qr_in_next[14] = {qr_in[0][14], qr_in[1][14], qr_in[2][14], qr_in[3][14], qr_in[4][14], qr_in[5][14], qr_in[6][14], qr_in[7][14], qr_in[8][14], qr_in[9][14], qr_in[10][14], qr_in[11][14], qr_in[12][14], qr_in[13][14], qr_in[14][14], qr_in[15][14], qr_in[16][14], qr_in[17][14], qr_in[18][14], qr_in[19][14], qr_in[20][14], qr_in[21][14], qr_in[22][14], qr_in[23][14], qr_in[24][14]};
        qr_in_next[15] = {qr_in[0][15], qr_in[1][15], qr_in[2][15], qr_in[3][15], qr_in[4][15], qr_in[5][15], qr_in[6][15], qr_in[7][15], qr_in[8][15], qr_in[9][15], qr_in[10][15], qr_in[11][15], qr_in[12][15], qr_in[13][15], qr_in[14][15], qr_in[15][15], qr_in[16][15], qr_in[17][15], qr_in[18][15], qr_in[19][15], qr_in[20][15], qr_in[21][15], qr_in[22][15], qr_in[23][15], qr_in[24][15]};
        qr_in_next[16] = {qr_in[0][16], qr_in[1][16], qr_in[2][16], qr_in[3][16], qr_in[4][16], qr_in[5][16], qr_in[6][16], qr_in[7][16], qr_in[8][16], qr_in[9][16], qr_in[10][16], qr_in[11][16], qr_in[12][16], qr_in[13][16], qr_in[14][16], qr_in[15][16], qr_in[16][16], qr_in[17][16], qr_in[18][16], qr_in[19][16], qr_in[20][16], qr_in[21][16], qr_in[22][16], qr_in[23][16], qr_in[24][16]};
        qr_in_next[17] = {qr_in[0][17], qr_in[1][17], qr_in[2][17], qr_in[3][17], qr_in[4][17], qr_in[5][17], qr_in[6][17], qr_in[7][17], qr_in[8][17], qr_in[9][17], qr_in[10][17], qr_in[11][17], qr_in[12][17], qr_in[13][17], qr_in[14][17], qr_in[15][17], qr_in[16][17], qr_in[17][17], qr_in[18][17], qr_in[19][17], qr_in[20][17], qr_in[21][17], qr_in[22][17], qr_in[23][17], qr_in[24][17]};
        qr_in_next[18] = {qr_in[0][18], qr_in[1][18], qr_in[2][18], qr_in[3][18], qr_in[4][18], qr_in[5][18], qr_in[6][18], qr_in[7][18], qr_in[8][18], qr_in[9][18], qr_in[10][18], qr_in[11][18], qr_in[12][18], qr_in[13][18], qr_in[14][18], qr_in[15][18], qr_in[16][18], qr_in[17][18], qr_in[18][18], qr_in[19][18], qr_in[20][18], qr_in[21][18], qr_in[22][18], qr_in[23][18], qr_in[24][18]};
        qr_in_next[19] = {qr_in[0][19], qr_in[1][19], qr_in[2][19], qr_in[3][19], qr_in[4][19], qr_in[5][19], qr_in[6][19], qr_in[7][19], qr_in[8][19], qr_in[9][19], qr_in[10][19], qr_in[11][19], qr_in[12][19], qr_in[13][19], qr_in[14][19], qr_in[15][19], qr_in[16][19], qr_in[17][19], qr_in[18][19], qr_in[19][19], qr_in[20][19], qr_in[21][19], qr_in[22][19], qr_in[23][19], qr_in[24][19]};
        qr_in_next[20] = {qr_in[0][20], qr_in[1][20], qr_in[2][20], qr_in[3][20], qr_in[4][20], qr_in[5][20], qr_in[6][20], qr_in[7][20], qr_in[8][20], qr_in[9][20], qr_in[10][20], qr_in[11][20], qr_in[12][20], qr_in[13][20], qr_in[14][20], qr_in[15][20], qr_in[16][20], qr_in[17][20], qr_in[18][20], qr_in[19][20], qr_in[20][20], qr_in[21][20], qr_in[22][20], qr_in[23][20], qr_in[24][20]};
        qr_in_next[21] = {qr_in[0][21], qr_in[1][21], qr_in[2][21], qr_in[3][21], qr_in[4][21], qr_in[5][21], qr_in[6][21], qr_in[7][21], qr_in[8][21], qr_in[9][21], qr_in[10][21], qr_in[11][21], qr_in[12][21], qr_in[13][21], qr_in[14][21], qr_in[15][21], qr_in[16][21], qr_in[17][21], qr_in[18][21], qr_in[19][21], qr_in[20][21], qr_in[21][21], qr_in[22][21], qr_in[23][21], qr_in[24][21]};
        qr_in_next[22] = {qr_in[0][22], qr_in[1][22], qr_in[2][22], qr_in[3][22], qr_in[4][22], qr_in[5][22], qr_in[6][22], qr_in[7][22], qr_in[8][22], qr_in[9][22], qr_in[10][22], qr_in[11][22], qr_in[12][22], qr_in[13][22], qr_in[14][22], qr_in[15][22], qr_in[16][22], qr_in[17][22], qr_in[18][22], qr_in[19][22], qr_in[20][22], qr_in[21][22], qr_in[22][22], qr_in[23][22], qr_in[24][22]};
        qr_in_next[23] = {qr_in[0][23], qr_in[1][23], qr_in[2][23], qr_in[3][23], qr_in[4][23], qr_in[5][23], qr_in[6][23], qr_in[7][23], qr_in[8][23], qr_in[9][23], qr_in[10][23], qr_in[11][23], qr_in[12][23], qr_in[13][23], qr_in[14][23], qr_in[15][23], qr_in[16][23], qr_in[17][23], qr_in[18][23], qr_in[19][23], qr_in[20][23], qr_in[21][23], qr_in[22][23], qr_in[23][23], qr_in[24][23]};
        qr_in_next[24] = {qr_in[0][24], qr_in[1][24], qr_in[2][24], qr_in[3][24], qr_in[4][24], qr_in[5][24], qr_in[6][24], qr_in[7][24], qr_in[8][24], qr_in[9][24], qr_in[10][24], qr_in[11][24], qr_in[12][24], qr_in[13][24], qr_in[14][24], qr_in[15][24], qr_in[16][24], qr_in[17][24], qr_in[18][24], qr_in[19][24], qr_in[20][24], qr_in[21][24], qr_in[22][24], qr_in[23][24], qr_in[24][24]};
    end
    else if (state == ROTATE && UR_sum + LL_sum + LR_sum == 27) begin
        // $display("rotate 180");
        // rotate 180 deg
        qr_in_next[0] = {qr_in[24][0], qr_in[24][1], qr_in[24][2], qr_in[24][3], qr_in[24][4], qr_in[24][5], qr_in[24][6], qr_in[24][7], qr_in[24][8], qr_in[24][9], qr_in[24][10], qr_in[24][11], qr_in[24][12], qr_in[24][13], qr_in[24][14], qr_in[24][15], qr_in[24][16], qr_in[24][17], qr_in[24][18], qr_in[24][19], qr_in[24][20], qr_in[24][21], qr_in[24][22], qr_in[24][23], qr_in[24][24]};
        qr_in_next[1] = {qr_in[23][0], qr_in[23][1], qr_in[23][2], qr_in[23][3], qr_in[23][4], qr_in[23][5], qr_in[23][6], qr_in[23][7], qr_in[23][8], qr_in[23][9], qr_in[23][10], qr_in[23][11], qr_in[23][12], qr_in[23][13], qr_in[23][14], qr_in[23][15], qr_in[23][16], qr_in[23][17], qr_in[23][18], qr_in[23][19], qr_in[23][20], qr_in[23][21], qr_in[23][22], qr_in[23][23], qr_in[23][24]};
        qr_in_next[2] = {qr_in[22][0], qr_in[22][1], qr_in[22][2], qr_in[22][3], qr_in[22][4], qr_in[22][5], qr_in[22][6], qr_in[22][7], qr_in[22][8], qr_in[22][9], qr_in[22][10], qr_in[22][11], qr_in[22][12], qr_in[22][13], qr_in[22][14], qr_in[22][15], qr_in[22][16], qr_in[22][17], qr_in[22][18], qr_in[22][19], qr_in[22][20], qr_in[22][21], qr_in[22][22], qr_in[22][23], qr_in[22][24]};
        qr_in_next[3] = {qr_in[21][0], qr_in[21][1], qr_in[21][2], qr_in[21][3], qr_in[21][4], qr_in[21][5], qr_in[21][6], qr_in[21][7], qr_in[21][8], qr_in[21][9], qr_in[21][10], qr_in[21][11], qr_in[21][12], qr_in[21][13], qr_in[21][14], qr_in[21][15], qr_in[21][16], qr_in[21][17], qr_in[21][18], qr_in[21][19], qr_in[21][20], qr_in[21][21], qr_in[21][22], qr_in[21][23], qr_in[21][24]};
        qr_in_next[4] = {qr_in[20][0], qr_in[20][1], qr_in[20][2], qr_in[20][3], qr_in[20][4], qr_in[20][5], qr_in[20][6], qr_in[20][7], qr_in[20][8], qr_in[20][9], qr_in[20][10], qr_in[20][11], qr_in[20][12], qr_in[20][13], qr_in[20][14], qr_in[20][15], qr_in[20][16], qr_in[20][17], qr_in[20][18], qr_in[20][19], qr_in[20][20], qr_in[20][21], qr_in[20][22], qr_in[20][23], qr_in[20][24]};
        qr_in_next[5] = {qr_in[19][0], qr_in[19][1], qr_in[19][2], qr_in[19][3], qr_in[19][4], qr_in[19][5], qr_in[19][6], qr_in[19][7], qr_in[19][8], qr_in[19][9], qr_in[19][10], qr_in[19][11], qr_in[19][12], qr_in[19][13], qr_in[19][14], qr_in[19][15], qr_in[19][16], qr_in[19][17], qr_in[19][18], qr_in[19][19], qr_in[19][20], qr_in[19][21], qr_in[19][22], qr_in[19][23], qr_in[19][24]};
        qr_in_next[6] = {qr_in[18][0], qr_in[18][1], qr_in[18][2], qr_in[18][3], qr_in[18][4], qr_in[18][5], qr_in[18][6], qr_in[18][7], qr_in[18][8], qr_in[18][9], qr_in[18][10], qr_in[18][11], qr_in[18][12], qr_in[18][13], qr_in[18][14], qr_in[18][15], qr_in[18][16], qr_in[18][17], qr_in[18][18], qr_in[18][19], qr_in[18][20], qr_in[18][21], qr_in[18][22], qr_in[18][23], qr_in[18][24]};
        qr_in_next[7] = {qr_in[17][0], qr_in[17][1], qr_in[17][2], qr_in[17][3], qr_in[17][4], qr_in[17][5], qr_in[17][6], qr_in[17][7], qr_in[17][8], qr_in[17][9], qr_in[17][10], qr_in[17][11], qr_in[17][12], qr_in[17][13], qr_in[17][14], qr_in[17][15], qr_in[17][16], qr_in[17][17], qr_in[17][18], qr_in[17][19], qr_in[17][20], qr_in[17][21], qr_in[17][22], qr_in[17][23], qr_in[17][24]};
        qr_in_next[8] = {qr_in[16][0], qr_in[16][1], qr_in[16][2], qr_in[16][3], qr_in[16][4], qr_in[16][5], qr_in[16][6], qr_in[16][7], qr_in[16][8], qr_in[16][9], qr_in[16][10], qr_in[16][11], qr_in[16][12], qr_in[16][13], qr_in[16][14], qr_in[16][15], qr_in[16][16], qr_in[16][17], qr_in[16][18], qr_in[16][19], qr_in[16][20], qr_in[16][21], qr_in[16][22], qr_in[16][23], qr_in[16][24]};
        qr_in_next[9] = {qr_in[15][0], qr_in[15][1], qr_in[15][2], qr_in[15][3], qr_in[15][4], qr_in[15][5], qr_in[15][6], qr_in[15][7], qr_in[15][8], qr_in[15][9], qr_in[15][10], qr_in[15][11], qr_in[15][12], qr_in[15][13], qr_in[15][14], qr_in[15][15], qr_in[15][16], qr_in[15][17], qr_in[15][18], qr_in[15][19], qr_in[15][20], qr_in[15][21], qr_in[15][22], qr_in[15][23], qr_in[15][24]};
        qr_in_next[10] = {qr_in[14][0], qr_in[14][1], qr_in[14][2], qr_in[14][3], qr_in[14][4], qr_in[14][5], qr_in[14][6], qr_in[14][7], qr_in[14][8], qr_in[14][9], qr_in[14][10], qr_in[14][11], qr_in[14][12], qr_in[14][13], qr_in[14][14], qr_in[14][15], qr_in[14][16], qr_in[14][17], qr_in[14][18], qr_in[14][19], qr_in[14][20], qr_in[14][21], qr_in[14][22], qr_in[14][23], qr_in[14][24]};
        qr_in_next[11] = {qr_in[13][0], qr_in[13][1], qr_in[13][2], qr_in[13][3], qr_in[13][4], qr_in[13][5], qr_in[13][6], qr_in[13][7], qr_in[13][8], qr_in[13][9], qr_in[13][10], qr_in[13][11], qr_in[13][12], qr_in[13][13], qr_in[13][14], qr_in[13][15], qr_in[13][16], qr_in[13][17], qr_in[13][18], qr_in[13][19], qr_in[13][20], qr_in[13][21], qr_in[13][22], qr_in[13][23], qr_in[13][24]};
        qr_in_next[12] = {qr_in[12][0], qr_in[12][1], qr_in[12][2], qr_in[12][3], qr_in[12][4], qr_in[12][5], qr_in[12][6], qr_in[12][7], qr_in[12][8], qr_in[12][9], qr_in[12][10], qr_in[12][11], qr_in[12][12], qr_in[12][13], qr_in[12][14], qr_in[12][15], qr_in[12][16], qr_in[12][17], qr_in[12][18], qr_in[12][19], qr_in[12][20], qr_in[12][21], qr_in[12][22], qr_in[12][23], qr_in[12][24]};
        qr_in_next[13] = {qr_in[11][0], qr_in[11][1], qr_in[11][2], qr_in[11][3], qr_in[11][4], qr_in[11][5], qr_in[11][6], qr_in[11][7], qr_in[11][8], qr_in[11][9], qr_in[11][10], qr_in[11][11], qr_in[11][12], qr_in[11][13], qr_in[11][14], qr_in[11][15], qr_in[11][16], qr_in[11][17], qr_in[11][18], qr_in[11][19], qr_in[11][20], qr_in[11][21], qr_in[11][22], qr_in[11][23], qr_in[11][24]};
        qr_in_next[14] = {qr_in[10][0], qr_in[10][1], qr_in[10][2], qr_in[10][3], qr_in[10][4], qr_in[10][5], qr_in[10][6], qr_in[10][7], qr_in[10][8], qr_in[10][9], qr_in[10][10], qr_in[10][11], qr_in[10][12], qr_in[10][13], qr_in[10][14], qr_in[10][15], qr_in[10][16], qr_in[10][17], qr_in[10][18], qr_in[10][19], qr_in[10][20], qr_in[10][21], qr_in[10][22], qr_in[10][23], qr_in[10][24]};
        qr_in_next[15] = {qr_in[9][0], qr_in[9][1], qr_in[9][2], qr_in[9][3], qr_in[9][4], qr_in[9][5], qr_in[9][6], qr_in[9][7], qr_in[9][8], qr_in[9][9], qr_in[9][10], qr_in[9][11], qr_in[9][12], qr_in[9][13], qr_in[9][14], qr_in[9][15], qr_in[9][16], qr_in[9][17], qr_in[9][18], qr_in[9][19], qr_in[9][20], qr_in[9][21], qr_in[9][22], qr_in[9][23], qr_in[9][24]};
        qr_in_next[16] = {qr_in[8][0], qr_in[8][1], qr_in[8][2], qr_in[8][3], qr_in[8][4], qr_in[8][5], qr_in[8][6], qr_in[8][7], qr_in[8][8], qr_in[8][9], qr_in[8][10], qr_in[8][11], qr_in[8][12], qr_in[8][13], qr_in[8][14], qr_in[8][15], qr_in[8][16], qr_in[8][17], qr_in[8][18], qr_in[8][19], qr_in[8][20], qr_in[8][21], qr_in[8][22], qr_in[8][23], qr_in[8][24]};
        qr_in_next[17] = {qr_in[7][0], qr_in[7][1], qr_in[7][2], qr_in[7][3], qr_in[7][4], qr_in[7][5], qr_in[7][6], qr_in[7][7], qr_in[7][8], qr_in[7][9], qr_in[7][10], qr_in[7][11], qr_in[7][12], qr_in[7][13], qr_in[7][14], qr_in[7][15], qr_in[7][16], qr_in[7][17], qr_in[7][18], qr_in[7][19], qr_in[7][20], qr_in[7][21], qr_in[7][22], qr_in[7][23], qr_in[7][24]};
        qr_in_next[18] = {qr_in[6][0], qr_in[6][1], qr_in[6][2], qr_in[6][3], qr_in[6][4], qr_in[6][5], qr_in[6][6], qr_in[6][7], qr_in[6][8], qr_in[6][9], qr_in[6][10], qr_in[6][11], qr_in[6][12], qr_in[6][13], qr_in[6][14], qr_in[6][15], qr_in[6][16], qr_in[6][17], qr_in[6][18], qr_in[6][19], qr_in[6][20], qr_in[6][21], qr_in[6][22], qr_in[6][23], qr_in[6][24]};
        qr_in_next[19] = {qr_in[5][0], qr_in[5][1], qr_in[5][2], qr_in[5][3], qr_in[5][4], qr_in[5][5], qr_in[5][6], qr_in[5][7], qr_in[5][8], qr_in[5][9], qr_in[5][10], qr_in[5][11], qr_in[5][12], qr_in[5][13], qr_in[5][14], qr_in[5][15], qr_in[5][16], qr_in[5][17], qr_in[5][18], qr_in[5][19], qr_in[5][20], qr_in[5][21], qr_in[5][22], qr_in[5][23], qr_in[5][24]};
        qr_in_next[20] = {qr_in[4][0], qr_in[4][1], qr_in[4][2], qr_in[4][3], qr_in[4][4], qr_in[4][5], qr_in[4][6], qr_in[4][7], qr_in[4][8], qr_in[4][9], qr_in[4][10], qr_in[4][11], qr_in[4][12], qr_in[4][13], qr_in[4][14], qr_in[4][15], qr_in[4][16], qr_in[4][17], qr_in[4][18], qr_in[4][19], qr_in[4][20], qr_in[4][21], qr_in[4][22], qr_in[4][23], qr_in[4][24]};
        qr_in_next[21] = {qr_in[3][0], qr_in[3][1], qr_in[3][2], qr_in[3][3], qr_in[3][4], qr_in[3][5], qr_in[3][6], qr_in[3][7], qr_in[3][8], qr_in[3][9], qr_in[3][10], qr_in[3][11], qr_in[3][12], qr_in[3][13], qr_in[3][14], qr_in[3][15], qr_in[3][16], qr_in[3][17], qr_in[3][18], qr_in[3][19], qr_in[3][20], qr_in[3][21], qr_in[3][22], qr_in[3][23], qr_in[3][24]};
        qr_in_next[22] = {qr_in[2][0], qr_in[2][1], qr_in[2][2], qr_in[2][3], qr_in[2][4], qr_in[2][5], qr_in[2][6], qr_in[2][7], qr_in[2][8], qr_in[2][9], qr_in[2][10], qr_in[2][11], qr_in[2][12], qr_in[2][13], qr_in[2][14], qr_in[2][15], qr_in[2][16], qr_in[2][17], qr_in[2][18], qr_in[2][19], qr_in[2][20], qr_in[2][21], qr_in[2][22], qr_in[2][23], qr_in[2][24]};
        qr_in_next[23] = {qr_in[1][0], qr_in[1][1], qr_in[1][2], qr_in[1][3], qr_in[1][4], qr_in[1][5], qr_in[1][6], qr_in[1][7], qr_in[1][8], qr_in[1][9], qr_in[1][10], qr_in[1][11], qr_in[1][12], qr_in[1][13], qr_in[1][14], qr_in[1][15], qr_in[1][16], qr_in[1][17], qr_in[1][18], qr_in[1][19], qr_in[1][20], qr_in[1][21], qr_in[1][22], qr_in[1][23], qr_in[1][24]};
        qr_in_next[24] = {qr_in[0][0], qr_in[0][1], qr_in[0][2], qr_in[0][3], qr_in[0][4], qr_in[0][5], qr_in[0][6], qr_in[0][7], qr_in[0][8], qr_in[0][9], qr_in[0][10], qr_in[0][11], qr_in[0][12], qr_in[0][13], qr_in[0][14], qr_in[0][15], qr_in[0][16], qr_in[0][17], qr_in[0][18], qr_in[0][19], qr_in[0][20], qr_in[0][21], qr_in[0][22], qr_in[0][23], qr_in[0][24]};
    end
    else if (state == ROTATE && UL_sum + UR_sum + LR_sum == 27) begin
        // rotate 270 deg
        qr_in_next[0] = {qr_in[24][24], qr_in[23][24], qr_in[22][24], qr_in[21][24], qr_in[20][24], qr_in[19][24], qr_in[18][24], qr_in[17][24], qr_in[16][24], qr_in[15][24], qr_in[14][24], qr_in[13][24], qr_in[12][24], qr_in[11][24], qr_in[10][24], qr_in[9][24], qr_in[8][24], qr_in[7][24], qr_in[6][24], qr_in[5][24], qr_in[4][24], qr_in[3][24], qr_in[2][24], qr_in[1][24], qr_in[0][24]};
        qr_in_next[1] = {qr_in[24][23], qr_in[23][23], qr_in[22][23], qr_in[21][23], qr_in[20][23], qr_in[19][23], qr_in[18][23], qr_in[17][23], qr_in[16][23], qr_in[15][23], qr_in[14][23], qr_in[13][23], qr_in[12][23], qr_in[11][23], qr_in[10][23], qr_in[9][23], qr_in[8][23], qr_in[7][23], qr_in[6][23], qr_in[5][23], qr_in[4][23], qr_in[3][23], qr_in[2][23], qr_in[1][23], qr_in[0][23]};
        qr_in_next[2] = {qr_in[24][22], qr_in[23][22], qr_in[22][22], qr_in[21][22], qr_in[20][22], qr_in[19][22], qr_in[18][22], qr_in[17][22], qr_in[16][22], qr_in[15][22], qr_in[14][22], qr_in[13][22], qr_in[12][22], qr_in[11][22], qr_in[10][22], qr_in[9][22], qr_in[8][22], qr_in[7][22], qr_in[6][22], qr_in[5][22], qr_in[4][22], qr_in[3][22], qr_in[2][22], qr_in[1][22], qr_in[0][22]};
        qr_in_next[3] = {qr_in[24][21], qr_in[23][21], qr_in[22][21], qr_in[21][21], qr_in[20][21], qr_in[19][21], qr_in[18][21], qr_in[17][21], qr_in[16][21], qr_in[15][21], qr_in[14][21], qr_in[13][21], qr_in[12][21], qr_in[11][21], qr_in[10][21], qr_in[9][21], qr_in[8][21], qr_in[7][21], qr_in[6][21], qr_in[5][21], qr_in[4][21], qr_in[3][21], qr_in[2][21], qr_in[1][21], qr_in[0][21]};
        qr_in_next[4] = {qr_in[24][20], qr_in[23][20], qr_in[22][20], qr_in[21][20], qr_in[20][20], qr_in[19][20], qr_in[18][20], qr_in[17][20], qr_in[16][20], qr_in[15][20], qr_in[14][20], qr_in[13][20], qr_in[12][20], qr_in[11][20], qr_in[10][20], qr_in[9][20], qr_in[8][20], qr_in[7][20], qr_in[6][20], qr_in[5][20], qr_in[4][20], qr_in[3][20], qr_in[2][20], qr_in[1][20], qr_in[0][20]};
        qr_in_next[5] = {qr_in[24][19], qr_in[23][19], qr_in[22][19], qr_in[21][19], qr_in[20][19], qr_in[19][19], qr_in[18][19], qr_in[17][19], qr_in[16][19], qr_in[15][19], qr_in[14][19], qr_in[13][19], qr_in[12][19], qr_in[11][19], qr_in[10][19], qr_in[9][19], qr_in[8][19], qr_in[7][19], qr_in[6][19], qr_in[5][19], qr_in[4][19], qr_in[3][19], qr_in[2][19], qr_in[1][19], qr_in[0][19]};
        qr_in_next[6] = {qr_in[24][18], qr_in[23][18], qr_in[22][18], qr_in[21][18], qr_in[20][18], qr_in[19][18], qr_in[18][18], qr_in[17][18], qr_in[16][18], qr_in[15][18], qr_in[14][18], qr_in[13][18], qr_in[12][18], qr_in[11][18], qr_in[10][18], qr_in[9][18], qr_in[8][18], qr_in[7][18], qr_in[6][18], qr_in[5][18], qr_in[4][18], qr_in[3][18], qr_in[2][18], qr_in[1][18], qr_in[0][18]};
        qr_in_next[7] = {qr_in[24][17], qr_in[23][17], qr_in[22][17], qr_in[21][17], qr_in[20][17], qr_in[19][17], qr_in[18][17], qr_in[17][17], qr_in[16][17], qr_in[15][17], qr_in[14][17], qr_in[13][17], qr_in[12][17], qr_in[11][17], qr_in[10][17], qr_in[9][17], qr_in[8][17], qr_in[7][17], qr_in[6][17], qr_in[5][17], qr_in[4][17], qr_in[3][17], qr_in[2][17], qr_in[1][17], qr_in[0][17]};
        qr_in_next[8] = {qr_in[24][16], qr_in[23][16], qr_in[22][16], qr_in[21][16], qr_in[20][16], qr_in[19][16], qr_in[18][16], qr_in[17][16], qr_in[16][16], qr_in[15][16], qr_in[14][16], qr_in[13][16], qr_in[12][16], qr_in[11][16], qr_in[10][16], qr_in[9][16], qr_in[8][16], qr_in[7][16], qr_in[6][16], qr_in[5][16], qr_in[4][16], qr_in[3][16], qr_in[2][16], qr_in[1][16], qr_in[0][16]};
        qr_in_next[9] = {qr_in[24][15], qr_in[23][15], qr_in[22][15], qr_in[21][15], qr_in[20][15], qr_in[19][15], qr_in[18][15], qr_in[17][15], qr_in[16][15], qr_in[15][15], qr_in[14][15], qr_in[13][15], qr_in[12][15], qr_in[11][15], qr_in[10][15], qr_in[9][15], qr_in[8][15], qr_in[7][15], qr_in[6][15], qr_in[5][15], qr_in[4][15], qr_in[3][15], qr_in[2][15], qr_in[1][15], qr_in[0][15]};
        qr_in_next[10] = {qr_in[24][14], qr_in[23][14], qr_in[22][14], qr_in[21][14], qr_in[20][14], qr_in[19][14], qr_in[18][14], qr_in[17][14], qr_in[16][14], qr_in[15][14], qr_in[14][14], qr_in[13][14], qr_in[12][14], qr_in[11][14], qr_in[10][14], qr_in[9][14], qr_in[8][14], qr_in[7][14], qr_in[6][14], qr_in[5][14], qr_in[4][14], qr_in[3][14], qr_in[2][14], qr_in[1][14], qr_in[0][14]};
        qr_in_next[11] = {qr_in[24][13], qr_in[23][13], qr_in[22][13], qr_in[21][13], qr_in[20][13], qr_in[19][13], qr_in[18][13], qr_in[17][13], qr_in[16][13], qr_in[15][13], qr_in[14][13], qr_in[13][13], qr_in[12][13], qr_in[11][13], qr_in[10][13], qr_in[9][13], qr_in[8][13], qr_in[7][13], qr_in[6][13], qr_in[5][13], qr_in[4][13], qr_in[3][13], qr_in[2][13], qr_in[1][13], qr_in[0][13]};
        qr_in_next[12] = {qr_in[24][12], qr_in[23][12], qr_in[22][12], qr_in[21][12], qr_in[20][12], qr_in[19][12], qr_in[18][12], qr_in[17][12], qr_in[16][12], qr_in[15][12], qr_in[14][12], qr_in[13][12], qr_in[12][12], qr_in[11][12], qr_in[10][12], qr_in[9][12], qr_in[8][12], qr_in[7][12], qr_in[6][12], qr_in[5][12], qr_in[4][12], qr_in[3][12], qr_in[2][12], qr_in[1][12], qr_in[0][12]};
        qr_in_next[13] = {qr_in[24][11], qr_in[23][11], qr_in[22][11], qr_in[21][11], qr_in[20][11], qr_in[19][11], qr_in[18][11], qr_in[17][11], qr_in[16][11], qr_in[15][11], qr_in[14][11], qr_in[13][11], qr_in[12][11], qr_in[11][11], qr_in[10][11], qr_in[9][11], qr_in[8][11], qr_in[7][11], qr_in[6][11], qr_in[5][11], qr_in[4][11], qr_in[3][11], qr_in[2][11], qr_in[1][11], qr_in[0][11]};
        qr_in_next[14] = {qr_in[24][10], qr_in[23][10], qr_in[22][10], qr_in[21][10], qr_in[20][10], qr_in[19][10], qr_in[18][10], qr_in[17][10], qr_in[16][10], qr_in[15][10], qr_in[14][10], qr_in[13][10], qr_in[12][10], qr_in[11][10], qr_in[10][10], qr_in[9][10], qr_in[8][10], qr_in[7][10], qr_in[6][10], qr_in[5][10], qr_in[4][10], qr_in[3][10], qr_in[2][10], qr_in[1][10], qr_in[0][10]};
        qr_in_next[15] = {qr_in[24][9], qr_in[23][9], qr_in[22][9], qr_in[21][9], qr_in[20][9], qr_in[19][9], qr_in[18][9], qr_in[17][9], qr_in[16][9], qr_in[15][9], qr_in[14][9], qr_in[13][9], qr_in[12][9], qr_in[11][9], qr_in[10][9], qr_in[9][9], qr_in[8][9], qr_in[7][9], qr_in[6][9], qr_in[5][9], qr_in[4][9], qr_in[3][9], qr_in[2][9], qr_in[1][9], qr_in[0][9]};
        qr_in_next[16] = {qr_in[24][8], qr_in[23][8], qr_in[22][8], qr_in[21][8], qr_in[20][8], qr_in[19][8], qr_in[18][8], qr_in[17][8], qr_in[16][8], qr_in[15][8], qr_in[14][8], qr_in[13][8], qr_in[12][8], qr_in[11][8], qr_in[10][8], qr_in[9][8], qr_in[8][8], qr_in[7][8], qr_in[6][8], qr_in[5][8], qr_in[4][8], qr_in[3][8], qr_in[2][8], qr_in[1][8], qr_in[0][8]};
        qr_in_next[17] = {qr_in[24][7], qr_in[23][7], qr_in[22][7], qr_in[21][7], qr_in[20][7], qr_in[19][7], qr_in[18][7], qr_in[17][7], qr_in[16][7], qr_in[15][7], qr_in[14][7], qr_in[13][7], qr_in[12][7], qr_in[11][7], qr_in[10][7], qr_in[9][7], qr_in[8][7], qr_in[7][7], qr_in[6][7], qr_in[5][7], qr_in[4][7], qr_in[3][7], qr_in[2][7], qr_in[1][7], qr_in[0][7]};
        qr_in_next[18] = {qr_in[24][6], qr_in[23][6], qr_in[22][6], qr_in[21][6], qr_in[20][6], qr_in[19][6], qr_in[18][6], qr_in[17][6], qr_in[16][6], qr_in[15][6], qr_in[14][6], qr_in[13][6], qr_in[12][6], qr_in[11][6], qr_in[10][6], qr_in[9][6], qr_in[8][6], qr_in[7][6], qr_in[6][6], qr_in[5][6], qr_in[4][6], qr_in[3][6], qr_in[2][6], qr_in[1][6], qr_in[0][6]};
        qr_in_next[19] = {qr_in[24][5], qr_in[23][5], qr_in[22][5], qr_in[21][5], qr_in[20][5], qr_in[19][5], qr_in[18][5], qr_in[17][5], qr_in[16][5], qr_in[15][5], qr_in[14][5], qr_in[13][5], qr_in[12][5], qr_in[11][5], qr_in[10][5], qr_in[9][5], qr_in[8][5], qr_in[7][5], qr_in[6][5], qr_in[5][5], qr_in[4][5], qr_in[3][5], qr_in[2][5], qr_in[1][5], qr_in[0][5]};
        qr_in_next[20] = {qr_in[24][4], qr_in[23][4], qr_in[22][4], qr_in[21][4], qr_in[20][4], qr_in[19][4], qr_in[18][4], qr_in[17][4], qr_in[16][4], qr_in[15][4], qr_in[14][4], qr_in[13][4], qr_in[12][4], qr_in[11][4], qr_in[10][4], qr_in[9][4], qr_in[8][4], qr_in[7][4], qr_in[6][4], qr_in[5][4], qr_in[4][4], qr_in[3][4], qr_in[2][4], qr_in[1][4], qr_in[0][4]};
        qr_in_next[21] = {qr_in[24][3], qr_in[23][3], qr_in[22][3], qr_in[21][3], qr_in[20][3], qr_in[19][3], qr_in[18][3], qr_in[17][3], qr_in[16][3], qr_in[15][3], qr_in[14][3], qr_in[13][3], qr_in[12][3], qr_in[11][3], qr_in[10][3], qr_in[9][3], qr_in[8][3], qr_in[7][3], qr_in[6][3], qr_in[5][3], qr_in[4][3], qr_in[3][3], qr_in[2][3], qr_in[1][3], qr_in[0][3]};
        qr_in_next[22] = {qr_in[24][2], qr_in[23][2], qr_in[22][2], qr_in[21][2], qr_in[20][2], qr_in[19][2], qr_in[18][2], qr_in[17][2], qr_in[16][2], qr_in[15][2], qr_in[14][2], qr_in[13][2], qr_in[12][2], qr_in[11][2], qr_in[10][2], qr_in[9][2], qr_in[8][2], qr_in[7][2], qr_in[6][2], qr_in[5][2], qr_in[4][2], qr_in[3][2], qr_in[2][2], qr_in[1][2], qr_in[0][2]};
        qr_in_next[23] = {qr_in[24][1], qr_in[23][1], qr_in[22][1], qr_in[21][1], qr_in[20][1], qr_in[19][1], qr_in[18][1], qr_in[17][1], qr_in[16][1], qr_in[15][1], qr_in[14][1], qr_in[13][1], qr_in[12][1], qr_in[11][1], qr_in[10][1], qr_in[9][1], qr_in[8][1], qr_in[7][1], qr_in[6][1], qr_in[5][1], qr_in[4][1], qr_in[3][1], qr_in[2][1], qr_in[1][1], qr_in[0][1]};
        qr_in_next[24] = {qr_in[24][0], qr_in[23][0], qr_in[22][0], qr_in[21][0], qr_in[20][0], qr_in[19][0], qr_in[18][0], qr_in[17][0], qr_in[16][0], qr_in[15][0], qr_in[14][0], qr_in[13][0], qr_in[12][0], qr_in[11][0], qr_in[10][0], qr_in[9][0], qr_in[8][0], qr_in[7][0], qr_in[6][0], qr_in[5][0], qr_in[4][0], qr_in[3][0], qr_in[2][0], qr_in[1][0], qr_in[0][0]};
    end
    else begin
        for (i = 0; i < 25; i = i + 1) begin
            qr_in_next[i] = qr_in[i];
        end
    end

end    

always @* begin
    case(state)
        IDLE: state_n = qr_decode_start ? MEM : IDLE; 
        MEM: state_n = read_cnt == 49 ? ROTATE : MEM; // 64 -> 32
        ROTATE: state_n = DECODE;
        DECODE: state_n = decode_cnt == text_length ? SEND_OUTPUT : DECODE;
        SEND_OUTPUT: state_n = send_output_cnt == text_length ? FINISH :SEND_OUTPUT;
        FINISH: state_n = IDLE;
        default: state_n = IDLE;
    endcase
end

always @* begin 
    if (state == SEND_OUTPUT) begin
        send_output_cnt_next = send_output_cnt + 1;
    end
    else begin
        send_output_cnt_next = send_output_cnt;
    end
end

// calculate sram read address
// always @* begin
//     sram_raddr = img_r * 32 + img_c;
// end
always @* begin
    if (state == MEM)
        read_cnt_n = read_cnt + 1;
    else
        read_cnt_n = read_cnt;
end
always @ (posedge clk) begin
    if (~srstn)
        read_cnt <= 0;
    else
        read_cnt <= read_cnt_n;
end
// always @* begin
//     if (state == MEM) begin
//         if (img_c == 40 && !find_qrcode) begin
//             img_r_next = img_r + 1;
//             img_c_next = 0;
//             read_cnt_n = read_cnt + 1;
//         end
//         else if (img_c == 63) begin
//             img_r_next = img_r + 1;
//             img_c_next = 0;
//             read_cnt_n = read_cnt + 1;
//         end
//         else begin
//             img_r_next = img_r;
//             img_c_next = img_c + 1;
//             read_cnt_n = read_cnt + 1;
//         end
//     end
//     else begin
//         img_r_next = img_r;
//         img_c_next = img_c;
//         read_cnt_n = read_cnt;
//     end
// end

// cal four sum to determine the direction 
always @* begin
    LR_sum = (qr_in[20][20] + qr_in[20][21] + qr_in[20][22] + qr_in[21][20] + qr_in[21][21] + qr_in[21][22] + qr_in[22][20] + qr_in[22][21] + qr_in[22][22]);
    LL_sum = (qr_in[20][2] + qr_in[20][3] + qr_in[20][4] + qr_in[21][2] + qr_in[21][3] + qr_in[21][4] + qr_in[22][2] + qr_in[22][3] + qr_in[22][4]);
    UL_sum = (qr_in[2][2] + qr_in[2][3] + qr_in[2][4] + qr_in[3][2] + qr_in[3][3] + qr_in[3][4] + qr_in[4][2] + qr_in[4][3] + qr_in[4][4]);
    UR_sum = (qr_in[2][20] + qr_in[2][21] + qr_in[2][22] + qr_in[3][20] + qr_in[3][21] + qr_in[3][22] + qr_in[4][20] + qr_in[4][21] + qr_in[4][22]);
end
// cal the first position of qrcode
// find one point 
// always @* begin
//     if (!find_qrcode && sram_rdata == 1) begin 
//         first_r_next = img_r;
//         first_c_next = img_c;
//         find_qrcode_next = 1;
//     end
//     else begin
//         first_r_next = first_r;
//         first_c_next = first_c;
//         find_qrcode_next = find_qrcode;
//     end
// end

// assign 3-bit demask pattern
wire [2:0] demask_pattern;
assign demask_pattern = {!qr_in[8][2], qr_in[8][3], !qr_in[8][4]};

// construct demask qrcode
always @* begin
    case (demask_pattern)
        // i stands for ROW, j stands for COLUMN
        3'b000: begin
            for (i = 0; i < QR_LEN; i = i + 1) begin
                for (j = 0; j < QR_LEN; j = j + 1) begin
                    if (i <= 7 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i <= 7 && j >= 17) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i >= 17 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if ((i + j) % 2 == 0)
                        qr_demask[i][j] = !qr_in[i][j];
                    else
                        qr_demask[i][j] = qr_in[i][j];
                end
            end
        end

        3'b001: begin
            for (i = 0; i < QR_LEN; i = i + 1) begin
                for (j = 0; j < QR_LEN; j = j + 1) begin
                    if (i <= 7 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i <= 7 && j >= 17) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i >= 17 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i % 2 == 0)
                        qr_demask[i][j] = !qr_in[i][j];
                    else
                        qr_demask[i][j] = qr_in[i][j];
                end
            end
        end

        3'b010: begin
            for (i = 0; i < QR_LEN; i = i + 1) begin
                for (j = 0; j < QR_LEN; j = j + 1) begin
                    if (i <= 7 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i <= 7 && j >= 17) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i >= 17 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (j % 3 == 0)
                        qr_demask[i][j] = !qr_in[i][j];
                    else
                        qr_demask[i][j] = qr_in[i][j];
                end
            end
        end

        3'b011: begin
            for (i = 0; i < QR_LEN; i = i + 1) begin
                for (j = 0; j < QR_LEN; j = j + 1) begin
                    if (i <= 7 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i <= 7 && j >= 17) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i >= 17 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if ((i + j) % 3 == 0)
                        qr_demask[i][j] = !qr_in[i][j];
                    else
                        qr_demask[i][j] = qr_in[i][j];
                end
            end
        end

        3'b100: begin
            for (i = 0; i < QR_LEN; i = i + 1) begin
                for (j = 0; j < QR_LEN; j = j + 1) begin
                    if (i <= 7 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i <= 7 && j >= 17) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i >= 17 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (((i / 2) + (j / 3)) % 2 == 0)
                        qr_demask[i][j] = !qr_in[i][j];
                    else
                        qr_demask[i][j] = qr_in[i][j];
                end
            end
        end

        3'b101: begin
            for (i = 0; i < QR_LEN; i = i + 1) begin
                for (j = 0; j < QR_LEN; j = j + 1) begin
                    if (i <= 7 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i <= 7 && j >= 17) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i >= 17 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (((i * j) % 2 + (i * j) % 3) == 0)
                        qr_demask[i][j] = !qr_in[i][j];
                    else
                        qr_demask[i][j] = qr_in[i][j];
                end
            end
        end

        3'b110: begin
            for (i = 0; i < QR_LEN; i = i + 1) begin
                for (j = 0; j < QR_LEN; j = j + 1) begin
                    if (i <= 7 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i <= 7 && j >= 17) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i >= 17 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (((i * j) % 2 + (i * j) % 3) % 2 == 0)
                        qr_demask[i][j] = !qr_in[i][j];
                    else
                        qr_demask[i][j] = qr_in[i][j];
                end
            end
        end

        3'b111: begin
            for (i = 0; i < QR_LEN; i = i + 1) begin
                for (j = 0; j < QR_LEN; j = j + 1) begin
                    if (i <= 7 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i <= 7 && j >= 17) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i >= 17 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (((i * j) % 3 + (i + j) % 2) % 2 == 0)
                        qr_demask[i][j] = !qr_in[i][j];
                    else
                        qr_demask[i][j] = qr_in[i][j];
                end
            end
        end

        default: begin
            // set default demasking as case 3'b000
            for (i = 0; i < QR_LEN; i = i + 1) begin
                for (j = 0; j < QR_LEN; j = j + 1) begin
                    if (i <= 7 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i <= 7 && j >= 17) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if (i >= 17 && j <= 7) 
                        qr_demask[i][j] = qr_in[i][j];
                    else if ((i + j) % 2 == 0)
                        qr_demask[i][j] = !qr_in[i][j];
                    else
                        qr_demask[i][j] = qr_in[i][j];
                end
            end
        end
    endcase
end
// Codeword Decoder table
always @* begin
    codeword_origin_next[0] = {qr_demask[24][24], qr_demask[24][23], qr_demask[23][24], qr_demask[23][23], qr_demask[22][24], qr_demask[22][23], qr_demask[21][24], qr_demask[21][23]};
    codeword_origin_next[1] = {qr_demask[24-4][24], qr_demask[24-4][23], qr_demask[23-4][24], qr_demask[23-4][23], qr_demask[22-4][24], qr_demask[22-4][23], qr_demask[21-4][24], qr_demask[21-4][23]};
    codeword_origin_next[2] = {qr_demask[24-8][24], qr_demask[24-8][23], qr_demask[23-8][24], qr_demask[23-8][23], qr_demask[22-8][24], qr_demask[22-8][23], qr_demask[21-8][24], qr_demask[21-8][23]};
    codeword_origin_next[3] = {qr_demask[24-12][24], qr_demask[24-12][23], qr_demask[23-12][24], qr_demask[23-12][23], qr_demask[22-12][24], qr_demask[22-12][23], qr_demask[21-12][24], qr_demask[21-12][23]};


    codeword_origin_next[4] = {qr_demask[21-12][22], qr_demask[21-12][21], qr_demask[22-12][22], qr_demask[22-12][21], qr_demask[23-12][22], qr_demask[23-12][21], qr_demask[24-12][22], qr_demask[24-12][21]};
    codeword_origin_next[5] = {qr_demask[21-8][22], qr_demask[21-8][21], qr_demask[22-8][22], qr_demask[22-8][21], qr_demask[23-8][22], qr_demask[23-8][21], qr_demask[24-8][22], qr_demask[24-8][21]};
    codeword_origin_next[6] = {qr_demask[21-4][22], qr_demask[21-4][21], qr_demask[22-4][22], qr_demask[22-4][21], qr_demask[23-4][22], qr_demask[23-4][21], qr_demask[24-4][22], qr_demask[24-4][21]};
    codeword_origin_next[7] = {qr_demask[21][22], qr_demask[21][21], qr_demask[22][22], qr_demask[22][21], qr_demask[23][22], qr_demask[23][21], qr_demask[24][22], qr_demask[24][21]};

    codeword_origin_next[8] = {qr_demask[24][24-4], qr_demask[24][23-4], qr_demask[23][24-4], qr_demask[23][23-4], qr_demask[22][24-4], qr_demask[22][23-4], qr_demask[21][24-4], qr_demask[21][23-4]};
    codeword_origin_next[9] = {qr_demask[24-9][24-4], qr_demask[24-9][23-4], qr_demask[23-9][24-4], qr_demask[23-9][23-4], qr_demask[22-9][24-4], qr_demask[22-9][23-4], qr_demask[21-9][24-4], qr_demask[21-9][23-4]};


    codeword_origin_next[10] = {qr_demask[11][20], qr_demask[11][19], qr_demask[10][20], qr_demask[10][19], qr_demask[9][20], qr_demask[9][19], qr_demask[9][18], qr_demask[9][17]};
    codeword_origin_next[11] = {qr_demask[10][18], qr_demask[10][17], qr_demask[11][18], qr_demask[11][17], qr_demask[12][18], qr_demask[12][17], qr_demask[13][18], qr_demask[13][17]};
    codeword_origin_next[12] = {qr_demask[10+4][18], qr_demask[10+4][17], qr_demask[11+4][18], qr_demask[11+4][17], qr_demask[12+9][18], qr_demask[12+9][17], qr_demask[13+9][18], qr_demask[13+9][17]};
    codeword_origin_next[13] = {qr_demask[23][18], qr_demask[23][17], qr_demask[24][18], qr_demask[24][17], qr_demask[24][16], qr_demask[24][15], qr_demask[23][16], qr_demask[23][15]};
    codeword_origin_next[14] = {qr_demask[22][16], qr_demask[22][15], qr_demask[21][16], qr_demask[21][15], qr_demask[20][15], qr_demask[19][15], qr_demask[18][15], qr_demask[17][15]};

    codeword_origin_next[15] = {qr_demask[16][15], qr_demask[15][16], qr_demask[15][15], qr_demask[14][16], qr_demask[14][15], qr_demask[13][16], qr_demask[13][15], qr_demask[12][16]};
    codeword_origin_next[16] = {qr_demask[16-4][15], qr_demask[15-4][16], qr_demask[15-4][15], qr_demask[14-4][16], qr_demask[14-4][15], qr_demask[13-4][16], qr_demask[13-4][15], qr_demask[12-4][16]};
    codeword_origin_next[17] = {qr_demask[8][15], qr_demask[7][16], qr_demask[7][15], qr_demask[5][16], qr_demask[5][15], qr_demask[4][16], qr_demask[4][15], qr_demask[3][16]};

    codeword_origin_next[18] = {qr_demask[3][15], qr_demask[2][16], qr_demask[2][15], qr_demask[1][16], qr_demask[1][15], qr_demask[0][16], qr_demask[0][15], qr_demask[0][14]};

    codeword_origin_next[19] = {qr_demask[0][13], qr_demask[1][14], qr_demask[1][13], qr_demask[2][14], qr_demask[2][13], qr_demask[3][14], qr_demask[3][13], qr_demask[4][14]};
    codeword_origin_next[20] = {qr_demask[4][13], qr_demask[5][14], qr_demask[5][13], qr_demask[7][14], qr_demask[7][13], qr_demask[8][14], qr_demask[8][13], qr_demask[9][14]};
    codeword_origin_next[21] = {qr_demask[0+8+1][13], qr_demask[1+8+1][14], qr_demask[1+8+1][13], qr_demask[2+8+1][14], qr_demask[2+8+1][13], qr_demask[3+8+1][14], qr_demask[3+8+1][13], qr_demask[4+8+1][14]};
    codeword_origin_next[22] = {qr_demask[0+12+1][13], qr_demask[1+12+1][14], qr_demask[1+12+1][13], qr_demask[2+12+1][14], qr_demask[2+12+1][13], qr_demask[3+12+1][14], qr_demask[3+12+1][13], qr_demask[4+12+1][14]};
    codeword_origin_next[23] = {qr_demask[0+16+1][13], qr_demask[1+16+1][14], qr_demask[1+16+1][13], qr_demask[2+16+1][14], qr_demask[2+16+1][13], qr_demask[3+16+1][14], qr_demask[3+16+1][13], qr_demask[4+16+1][14]};

    codeword_origin_next[24] = {qr_demask[21][13], qr_demask[22][14], qr_demask[22][13], qr_demask[23][14], qr_demask[23][13], qr_demask[24][14], qr_demask[24][13], qr_demask[24][12]};

    codeword_origin_next[25] = {qr_demask[24][11], qr_demask[23][12], qr_demask[23][11], qr_demask[22][12], qr_demask[22][11], qr_demask[21][12], qr_demask[21][11], qr_demask[20][12]};
    codeword_origin_next[26] = {qr_demask[24-4][11], qr_demask[23-4][12], qr_demask[23-4][11], qr_demask[22-4][12], qr_demask[22-4][11], qr_demask[21-4][12], qr_demask[21-4][11], qr_demask[20-4][12]};
    codeword_origin_next[27] = {qr_demask[24-8][11], qr_demask[23-8][12], qr_demask[23-8][11], qr_demask[22-8][12], qr_demask[22-8][11], qr_demask[21-8][12], qr_demask[21-8][11], qr_demask[20-8][12]};
end
always @(posedge clk) begin
    if(!srstn)
        for (i = 0; i < 44; i = i + 1) begin 
            codeword_origin[i] <= 0;
        end
    else
        for (i = 0; i < 44; i = i + 1) begin 
            codeword_origin[i] <= codeword_origin_next[i];
        end
end
// set decode_cnt_n
always @* begin
    if (state == DECODE) begin
        decode_cnt_n = decode_cnt + 1;
    end
    else begin
        decode_cnt_n = decode_cnt;
    end
end
always @ (posedge clk) begin
    if(~srstn)
        decode_cnt <= 0;
    else
       decode_cnt <= decode_cnt_n;
end
// set text length
always @* begin
    text_length = {codeword_origin[0][3], codeword_origin[0][2], codeword_origin[0][1], codeword_origin[0][0], codeword_origin[1][7], codeword_origin[1][6], codeword_origin[1][5], codeword_origin[1][4]};
end

//hsieh
always @* begin
    qr_decode_finish_reg = 0;
    if(sram_raddr == 10'd6) sram_raddr_reg = 10'd32;
    else if (sram_raddr == 10'd38) sram_raddr_reg = 10'd64;
    else if (sram_raddr == 10'd70) sram_raddr_reg = 10'd96;
    else if (sram_raddr == 10'd102) sram_raddr_reg = 10'd128;
    else if (sram_raddr == 10'd134) sram_raddr_reg = 10'd160;
    else if (sram_raddr == 10'd166) sram_raddr_reg = 10'd192;
    // else if (sram_raddr == 10'd200) sram_raddr_reg = sram_raddr;
    else sram_raddr_reg = sram_raddr + 10'd1;
end
always@(posedge clk) begin
    if(!srstn)
        sram_raddr <= 0;
    else
        sram_raddr <= sram_raddr_reg;
end
always @* begin
    decode_jis8_code_next = {codeword_origin[send_output_cnt + 1][3-:4], codeword_origin[send_output_cnt + 2][7-:4]};
end
always @* begin
    if (state == SEND_OUTPUT && send_output_cnt == text_length - 1) begin
        qr_decode_finish_reg = 1;
    end
    else begin
        qr_decode_finish_reg = 0;
    end
end
always @* begin
    if (state == SEND_OUTPUT) begin
        decode_valid_next = 1;
    end
    else begin
        decode_valid_next = 0;
    end
end
always @ (posedge clk) begin
    if(~srstn)
        send_output_cnt <= 0;
    else
        send_output_cnt <= send_output_cnt_next;
end
always @(posedge clk)
    if(!srstn)
        decode_jis8_code <= 0;
    else
        decode_jis8_code <= decode_jis8_code_next;
endmodule



