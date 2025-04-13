`timescale 1ns / 1ps

module sdram_read(
    input                       iclk,
    input                       ireset,
    input                       ireq,
    input                       ienb,
    output                      ofin,
    
    input           [12:0]      irow,
    input            [9:0]      icolumn,
    input            [1:0]      ibank,
    output         [127:0]      odata,
    output                      read_enable,
    
    output                      DRAM_CLK,
    output                      DRAM_CKE,
    output         [12:0]       DRAM_ADDR,
    output          [1:0]       DRAM_BA,
    output                      DRAM_CAS_N,
    output                      DRAM_CS_N,
    output                      DRAM_RAS_N,
    output                      DRAM_WE_N,
    output                      DRAM_LDQM,
    output                      DRAM_UDQM,
    input           [15:0]      DRAM_DQ
);

reg      [7:0]  state       = 8'b00000001;
reg      [7:0]  next_state;

reg      [3:0]  command     = 4'h0;
reg     [12:0]  address     = 13'h0;
reg      [1:0]  bank        = 2'b00;
reg    [127:0]  data        = 128'b0;
reg      [1:0]  dqm         = 2'b11;

reg             ready       = 1'b0;
reg             read_act    = 1'b0;

assign read_enable = read_act;
assign ofin        = ready;
assign odata       = data;

assign DRAM_ADDR                                        = ienb ? address    : 13'bz;
assign DRAM_BA                                          = ienb ? bank       : 2'bz;
assign {DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N}   = ienb ? command    : 4'bz;
assign {DRAM_UDQM, DRAM_LDQM}                           = ienb ? dqm        : 2'bz;
assign DRAM_CLK                                         = ienb ? ~iclk      : 1'bz;
assign DRAM_CKE                                         = ienb ? 1'b1       : 1'bz;

reg [7:0] counter = 0;
reg ctr_reset = 0;

assign dqm_count  = (counter < 5);
assign data_count = (counter == 9);  // <-- was 7 before

always @(posedge iclk or posedge ctr_reset) begin
    if (ctr_reset)
        counter <= #1 8'h0;
    else
        counter <= #1 counter + 1'b1;
end

always @(posedge iclk) begin
    if (ireset)
        state <= #1 8'b00000001;
    else
        state <= #1 next_state;
end

always @(*) begin
    case (state)
        8'b00000001: next_state = ireq ? 8'b00000010 : 8'b00000001;
        8'b00000010: next_state = 8'b00000100;
        8'b00000100: next_state = 8'b00001000;
        8'b00001000: next_state = 8'b00010000;
        8'b00010000: next_state = 8'b00100000;
        8'b00100000: next_state = 8'b01000000;
        8'b01000000: next_state = data_count ? 8'b10000000 : 8'b01000000;
        8'b10000000: next_state = 8'b00000001;
        default:     next_state = 8'b00000001;
    endcase
end

always @(state or counter) begin
    case (state)
        8'b00000001: begin
            command     <= 4'b0111;
            address     <= 13'h0000;
            bank        <= 2'b00;
            dqm         <= 2'b11;
            ready       <= 1'b0;
            ctr_reset   <= 1'b0;
            read_act    <= 1'b0;
        end
        8'b00000010: begin
            command     <= 4'b0011;
            address     <= irow;
            bank        <= ibank;
            dqm         <= 2'b11;
            ready       <= 1'b0;
            ctr_reset   <= 1'b0;
            read_act    <= 1'b0;
        end
        8'b00000100: begin
            command     <= 4'b0111;
            address     <= 13'h0000;
            bank        <= 2'b00;
            dqm         <= 2'b11;
            ready       <= 1'b0;
            ctr_reset   <= 1'b0;
            read_act    <= 1'b0;
        end
        8'b00001000: begin
            command     <= 4'b0101;
            address     <= {3'b001, icolumn};
            bank        <= ibank;
            dqm         <= 2'b11;
            ready       <= 1'b0;
            ctr_reset   <= 1'b0;
            read_act    <= 1'b0;
        end
        8'b00010000: begin
            command     <= 4'b0111;
            address     <= 13'h0000;
            bank        <= 2'b00;
            dqm         <= 2'b00;
            ready       <= 1'b0;
            ctr_reset   <= 1'b0;
            read_act    <= 1'b0;
        end
        8'b00100000: begin
            command     <= 4'b0111;
            address     <= 13'h0000;
            bank        <= 2'b00;
            dqm         <= 2'b00;
            ready       <= 1'b0;
            ctr_reset   <= 1'b1;
            read_act    <= 1'b1;
        end
        8'b01000000: begin
            command     <= 4'b0111;
            address     <= 13'h0000;
            bank        <= 2'b00;
            dqm         <= dqm_count ? 2'b00 : 2'b11;
            ctr_reset   <= 1'b0;
            ready       <= 1'b0;
            read_act    <= 1'b1;

            case (counter)
                1: data[127:112] <= DRAM_DQ;
                2: data[111:96]  <= DRAM_DQ;
                3: data[95:80]   <= DRAM_DQ;
                4: data[79:64]   <= DRAM_DQ;
                5: data[63:48]   <= DRAM_DQ;
                6: data[47:32]   <= DRAM_DQ;
                7: data[31:16]   <= DRAM_DQ;
                8: data[15:0]    <= DRAM_DQ;
            endcase
            $display("[sdram_read] Burst[%0d] <= %h @ %0t", counter, DRAM_DQ, $time);
        end
        8'b10000000: begin
            command     <= 4'b0111;
            address     <= 13'h0000;
            bank        <= 2'b00;
            dqm         <= 2'b11;
            ready       <= 1'b1;
            ctr_reset   <= 1'b0;
            read_act    <= 1'b0;
        end
    endcase
end

endmodule
