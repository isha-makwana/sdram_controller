`timescale 1ns / 1ps

module sdram_controller_tb;

  // Clock and reset
  reg iclk = 0;
  reg ireset;

  // Write interface
  reg iwrite_req;
  reg [21:0] iwrite_address;
  reg [127:0] iwrite_data;
  wire owrite_ack;

  // Read interface
  reg iread_req;
  reg [21:0] iread_address;
  wire [127:0] oread_data;
  wire oread_ack;

  // SDRAM interface (not connected to real memory in this sim)
  wire [12:0] DRAM_ADDR;
  wire [1:0]  DRAM_BA;
  wire        DRAM_CAS_N;
  wire        DRAM_CKE;
  wire        DRAM_CLK;
  wire        DRAM_CS_N;
  wire [15:0] DRAM_DQ;
  wire        DRAM_LDQM;
  wire        DRAM_RAS_N;
  wire        DRAM_UDQM;
  wire        DRAM_WE_N;

  // New signal to check SDRAM init complete
  wire oinit_done;

  // Instantiate the DUT
  sdram_controller dut (
    .iclk(iclk),
    .ireset(ireset),
    .iwrite_req(iwrite_req),
    .iwrite_address(iwrite_address),
    .iwrite_data(iwrite_data),
    .owrite_ack(owrite_ack),
    .iread_req(iread_req),
    .iread_address(iread_address),
    .oread_data(oread_data),
    .oread_ack(oread_ack),
    .oinit_done(oinit_done),  // <-- new connection

    .DRAM_ADDR(DRAM_ADDR),
    .DRAM_BA(DRAM_BA),
    .DRAM_CAS_N(DRAM_CAS_N),
    .DRAM_CKE(DRAM_CKE),
    .DRAM_CLK(DRAM_CLK),
    .DRAM_CS_N(DRAM_CS_N),
    .DRAM_DQ(DRAM_DQ),
    .DRAM_LDQM(DRAM_LDQM),
    .DRAM_RAS_N(DRAM_RAS_N),
    .DRAM_UDQM(DRAM_UDQM),
    .DRAM_WE_N(DRAM_WE_N)
  );


//sdram chip called here (new addition after commit)
  mock_sdram sdram_chip (
    .clk(iclk),
    .cs_n(DRAM_CS_N),
    .ras_n(DRAM_RAS_N),
    .cas_n(DRAM_CAS_N),
    .we_n(DRAM_WE_N),
    .ba(DRAM_BA),
    .addr(DRAM_ADDR),
    .dq(DRAM_DQ),
    .ldqm(DRAM_LDQM),
    .udqm(DRAM_UDQM)
  );

  // Clock generation (100 MHz)
  always #5 iclk = ~iclk;

  // Test sequence
  initial begin
    $display("[%0t] Starting testbench...", $time);
    
    ireset = 1;
    iwrite_req = 0;
    iread_req = 0;
    iwrite_address = 22'h000001;
    iread_address = 22'h000001;
    iwrite_data = 128'hDEADBEEFCAFEBABE123456789ABCDEF0;

    #50;
    ireset = 0;

    // Wait for SDRAM initialization to complete
    $display("[%0t] Waiting for SDRAM initialization to complete...", $time);
    wait (oinit_done == 1);
    $display("[%0t] SDRAM initialization complete.", $time);

    #50;

    // Write to SDRAM
    $display("[%0t] Issuing write request.", $time);
    iwrite_req = 1;
    #10 iwrite_req = 0;

    // Wait for write ack
    wait (owrite_ack == 1);
    $display("[%0t] Write acknowledged.", $time);

    #100;

    // Read from SDRAM
    $display("[%0t] Issuing read request.", $time);
    iread_req = 1;
    #10 iread_req = 0;

    // Wait for read ack
    wait (oread_ack == 1);
    $display("[%0t] Read acknowledged.", $time);
    $display("[%0t] Read data: %h", $time, oread_data);

    #200;

    $display("[%0t] Test complete.", $time);
    $finish;
  end

endmodule