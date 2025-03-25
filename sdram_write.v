`timescale 1ns / 1ps

module sdram_write(
    input                       iclk,
    input                       ireset,
    input                       ireq,
    input                       ienb,
    output                      ofin,

    input           [12:0]      irow,
    input           [9:0]       icolumn,
    input           [1:0]       ibank,
    input           [127:0]     idata,

    output                      DRAM_CLK,
    output                      DRAM_CKE,
    output      [12:0]          DRAM_ADDR,
    output       [1:0]          DRAM_BA,
    output                      DRAM_CAS_N,
    output                      DRAM_CS_N,
    output                      DRAM_RAS_N,
    output                      DRAM_WE_N,
    output                      DRAM_LDQM,
    output                      DRAM_UDQM,
    output      [15:0]          DRAM_DQ,
    output      [15:0]          write_data_out,
    output                      write_enable
);

// FSM States
localparam IDLE        = 5'b00001,
           ACTIVE      = 5'b00010,
           WRITE_CMD   = 5'b00100,
           BURST       = 5'b01000,
           POST_NOP    = 5'b10000;

reg [4:0] state       = IDLE;
reg [4:0] next_state;

reg [3:0] command     = 4'h0;
reg [12:0] address    = 13'h0;
reg [1:0] bank        = 2'b00;
reg [127:0] data      = 128'h0;
reg [1:0] dqm         = 2'b11;
reg ready             = 1'b0;

reg [7:0] counter     = 8'h0;
reg ctr_reset         = 0;

assign write_data_out = data[127:112];
assign write_enable   = ienb && (state == BURST);
assign DRAM_DQ        = ienb ? data[127:112] : 16'bz;
assign DRAM_CLK       = ienb ? ~iclk         : 1'bz;
assign DRAM_CKE       = ienb ? 1'b1          : 1'bz;
assign DRAM_ADDR      = ienb ? address       : 13'bz;
assign DRAM_BA        = ienb ? bank          : 2'bz;
assign {DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N} = ienb ? command : 4'bz;
assign {DRAM_UDQM, DRAM_LDQM} = ienb ? dqm    : 2'bz;
assign ofin           = ready;

assign data_count     = (counter == 5);

always @(posedge iclk or posedge ctr_reset) begin
    if (ctr_reset)
        counter <= #1 8'h0;
    else
        counter <= #1 counter + 1;
end

always @(posedge iclk) begin
    if (ireset)
        state <= #1 IDLE;
    else
        state <= #1 next_state;
end

always @(*) begin
    case (state)
        IDLE:       next_state = ireq ? ACTIVE    : IDLE;
        ACTIVE:     next_state = WRITE_CMD;
        WRITE_CMD:  next_state = BURST;
        BURST:      next_state = data_count ? POST_NOP : BURST;
        POST_NOP:   next_state = IDLE;
        default:    next_state = IDLE;
    endcase
end

always @(posedge iclk) begin
    case (state)
        IDLE: begin
            command   <= 4'b0111;
            address   <= 13'h0000;
            bank      <= 2'b00;
            dqm       <= 2'b11;
            ready     <= 1'b0;
            ctr_reset <= 1'b0;
            $display("[sdram_write] State: IDLE @ %0t", $time);
        end
        ACTIVE: begin
            command   <= 4'b0011;
            address   <= irow;
            bank      <= ibank;
            data      <= idata;
            dqm       <= 2'b11;
            ready     <= 1'b0;
            ctr_reset <= 1'b0;
            $display("[sdram_write] State: ACTIVE, issuing ACTIVE cmd for row=%0d bank=%0d @ %0t", irow, ibank, $time);
        end
        WRITE_CMD: begin
            command   <= 4'b0100;
            address   <= {3'b001, icolumn};
            bank      <= ibank;
            dqm       <= 2'b00;
            ready     <= 1'b0;
            ctr_reset <= 1'b1;
            $display("[sdram_write] State: WRITE_CMD, issuing WRITE for col=%0d bank=%0d @ %0t", icolumn, ibank, $time);
        end
        BURST: begin
            command   <= 4'b0111;
            address   <= 13'h0000;
            bank      <= 2'b00;
            dqm       <= 2'b00;
            ready     <= 1'b0;
 	    data      <= data << 16;
            ctr_reset <= 1'b0;
            $display("[sdram_write] State: BURST, driving data=%h @ %0t", data[127:112], $time);
            
	end
        POST_NOP: begin
            command   <= 4'b0111;
            address   <= 13'h0000;
            bank      <= 2'b00;
            dqm       <= 2'b11;
            ready     <= 1'b1;
            ctr_reset <= 1'b0;
            $display("[sdram_write] State: POST_NOP, write complete @ %0t", $time);
        end
    endcase
end

// Shift data after BURST state completes a cycle


endmodule
