`timescale 1ns / 1ps

module sdram_controller(
    input               iclk,
    input               ireset,

    input               iwrite_req,
    input      [21:0]   iwrite_address,
    input     [127:0]   iwrite_data,
    output              owrite_ack,

    input               iread_req,
    input      [21:0]   iread_address,
    output    [127:0]   oread_data,
    output              oread_ack,

    output              oinit_done,

    output     [12:0]   DRAM_ADDR,
    output      [1:0]   DRAM_BA,
    output              DRAM_CAS_N,
    output              DRAM_CKE,
    output              DRAM_CLK,
    output              DRAM_CS_N,
    inout      [15:0]   DRAM_DQ,
    output              DRAM_LDQM,
    output              DRAM_RAS_N,
    output              DRAM_UDQM,
    output              DRAM_WE_N
);

// FSM State Encoding
localparam S_INIT       = 4'd0,
           S_WAIT_INIT  = 4'd1,
           S_IDLE       = 4'd2,
           S_WRITE_REQ  = 4'd3,
           S_WRITE_WAIT = 4'd4,
           S_WRITE_ACK  = 4'd5,
           S_READ_REQ   = 4'd6,
           S_READ_WAIT  = 4'd7,
           S_READ_ACK   = 4'd8;

reg  [3:0] state, next_state;

// FSM control
reg init_ireq, write_ireq, read_ireq;
reg write_ack, read_ack;
reg [2:0] mul_state;  // 001=init, 010=write, 100=read

// Init, Read, Write done signals
wire init_fin;
wire write_fin;
wire read_fin;

// Tristate / data control signals
wire [15:0] sdram_write_data;
wire        sdram_write_enable;
wire	    read_enable;

assign {read_ienb, write_ienb, init_ienb} = mul_state;
assign oinit_done = init_fin;
assign owrite_ack = write_ack;
assign oread_ack  = read_ack;

// Address Decode
wire [1:0] write_ibank, read_ibank;
wire [12:0] write_irow, read_irow;
wire [9:0] write_icolumn = 10'd0, read_icolumn = 10'd0;
assign {write_ibank, write_irow} = iwrite_address;
assign {read_ibank,  read_irow}  = iread_address;

// Tri-state
assign DRAM_DQ = sdram_write_enable ? sdram_write_data :
                 read_enable        ? 16'bz : 16'bz;

// FSM sequential logic
always @(posedge iclk)
    if (ireset)
        state <= S_INIT;
    else
        state <= next_state;

// FSM combinational logic
always @(*) begin
    case (state)
        S_INIT:         next_state = S_WAIT_INIT;
        S_WAIT_INIT:    next_state = init_fin ? S_IDLE : S_WAIT_INIT;
        S_IDLE: begin
            if (iwrite_req)       next_state = S_WRITE_REQ;
            else if (iread_req)  next_state = S_READ_REQ;
            else                 next_state = S_IDLE;
        end
        S_WRITE_REQ:    next_state = S_WRITE_WAIT;
        S_WRITE_WAIT:   next_state = write_fin ? S_WRITE_ACK : S_WRITE_WAIT;
        S_WRITE_ACK:    next_state = iread_req ? S_READ_REQ : (iwrite_req ? S_WRITE_REQ : S_IDLE);
        S_READ_REQ:     next_state = S_READ_WAIT;
        S_READ_WAIT:    next_state = read_fin ? S_READ_ACK : S_READ_WAIT;
        S_READ_ACK:     next_state = iwrite_req ? S_WRITE_REQ : (iread_req ? S_READ_REQ : S_IDLE);
        default:        next_state = S_INIT;
    endcase
end

// FSM output logic
always @(*) begin
    // Defaults
    init_ireq = 0; write_ireq = 0; read_ireq = 0;
    write_ack = 0; read_ack = 0;
    mul_state = 3'b000;

    case (state)
        S_INIT: begin
            init_ireq = 1;
            mul_state = 3'b001;
        end
        S_WAIT_INIT: begin
            mul_state = 3'b001;
        end
        S_IDLE: begin
            mul_state = 3'b001;
        end
        S_WRITE_REQ: begin
            write_ireq = 1;
            mul_state  = 3'b010;
        end
        S_WRITE_WAIT, S_WRITE_ACK: begin
            mul_state  = 3'b010;
            if (state == S_WRITE_ACK) write_ack = 1;
        end
        S_READ_REQ: begin
            read_ireq  = 1;
            mul_state  = 3'b100;
        end
        S_READ_WAIT, S_READ_ACK: begin
            mul_state  = 3'b100;
            if (state == S_READ_ACK) read_ack = 1;
        end
    endcase
end

// SDRAM Submodules
sdram_initalize sdram_init (
    .iclk(iclk), .ireset(ireset),
    .ireq(init_ireq), .ienb(init_ienb),
    .ofin(init_fin),
    .DRAM_ADDR(DRAM_ADDR), .DRAM_BA(DRAM_BA), .DRAM_CAS_N(DRAM_CAS_N),
    .DRAM_CKE(DRAM_CKE), .DRAM_CLK(DRAM_CLK), .DRAM_CS_N(DRAM_CS_N),
    .DRAM_DQ(DRAM_DQ), .DRAM_LDQM(DRAM_LDQM), .DRAM_RAS_N(DRAM_RAS_N),
    .DRAM_UDQM(DRAM_UDQM), .DRAM_WE_N(DRAM_WE_N)
);

sdram_write sdram_write (
    .iclk(iclk), .ireset(ireset),
    .ireq(write_ireq), .ienb(write_ienb),
    .irow(write_irow), .icolumn(write_icolumn), .ibank(write_ibank),
    .idata(iwrite_data), .ofin(write_fin),
    .write_data_out(sdram_write_data), .write_enable(sdram_write_enable),
    .DRAM_ADDR(DRAM_ADDR), .DRAM_BA(DRAM_BA), .DRAM_CAS_N(DRAM_CAS_N),
    .DRAM_CKE(DRAM_CKE), .DRAM_CLK(DRAM_CLK), .DRAM_CS_N(DRAM_CS_N),
    .DRAM_DQ(DRAM_DQ), .DRAM_LDQM(DRAM_LDQM), .DRAM_RAS_N(DRAM_RAS_N),
    .DRAM_UDQM(DRAM_UDQM), .DRAM_WE_N(DRAM_WE_N)
);

sdram_read sdram_read (
    .iclk(iclk), .ireset(ireset),
    .ireq(read_ireq), .ienb(read_ienb),
    .irow(read_irow), .icolumn(read_icolumn), .ibank(read_ibank),
    .odata(oread_data), .ofin(read_fin), .read_enable(read_enable),
    .DRAM_ADDR(DRAM_ADDR), .DRAM_BA(DRAM_BA), .DRAM_CAS_N(DRAM_CAS_N),
    .DRAM_CKE(DRAM_CKE), .DRAM_CLK(DRAM_CLK), .DRAM_CS_N(DRAM_CS_N),
    .DRAM_DQ(DRAM_DQ), .DRAM_LDQM(DRAM_LDQM), .DRAM_RAS_N(DRAM_RAS_N),
    .DRAM_UDQM(DRAM_UDQM), .DRAM_WE_N(DRAM_WE_N)
);

endmodule
