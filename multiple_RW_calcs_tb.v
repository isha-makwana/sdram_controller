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

time write_start_time, write_end_time;
time read_start_time, read_end_time;
real write_latency, read_latency;
real write_bandwidth, read_bandwidth;

  // SDRAM interface
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
  wire        oinit_done;

  // Clock generation (100 MHz)
  always #5 iclk = ~iclk;

  // Instantiate DUT
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
    .oinit_done(oinit_done),
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

  // Instantiate mock SDRAM
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
    .udqm(DRAM_UDQM),
    .init_done(oinit_done)
  );

  // Monitor SDRAM commands
  always @(posedge iclk) begin
    $display("[%0t] TB Monitor: CS_N=%b RAS_N=%b CAS_N=%b WE_N=%b ADDR=%h",
              $time, DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N, DRAM_ADDR);
  end

  // Test variables
  reg [127:0] test_data [0:3];
  reg [21:0]  test_addr [0:3];
  integer i;
  

  // Test sequence
  initial begin
    $display("[%0t] Starting testbench...", $time);
    // Init signals
    ireset         = 1;
    iwrite_req     = 0;
    iread_req      = 0;
    iwrite_address = 22'd0;
    iread_address  = 22'd0;
    iwrite_data    = 128'd0;
    i = 0;

    // Sample patterns and addresses
    test_data[0] = 128'hDEADBEEFCAFEBABE123456789ABCDEF0;
    test_data[1] = 128'h0123456789ABCDEFFEDCBA9876543210;
    test_data[2] = 128'hAAAAAAAA55555555FFFFFFFF00000000;
    test_data[3] = 128'hFACEFACEFACEFACEFACEFACEFACEFACE;

    test_addr[0] = 22'h000001;
    test_addr[1] = 22'h000002;
    test_addr[2] = 22'h000003;
    test_addr[3] = 22'h000004;


    #50 ireset = 0;

    $display("[%0t] Waiting for SDRAM initialization to complete...", $time);
    wait (oinit_done == 1);
    $display("[%0t] SDRAM initialization complete.", $time);
    #50;
    
    $display("[%0t] Issuing write request.", $time);
// WRITE loop
    for (i = 0; i < 4; i = i + 1) begin
      iwrite_address = test_addr[i];
      iwrite_data    = test_data[i];
      $display("[%0t] WRITE[%0d]: %h -> %h", $time, i, test_data[i], test_addr[i]);
      
      write_start_time = $time;
      iwrite_req = 1;
      #10 iwrite_req = 0;
      wait (owrite_ack == 1);
      $display("[%0t] Write acknowledged.", $time);
      write_end_time = $time;

      write_latency = (write_end_time - write_start_time) ;  // ps
      write_bandwidth = 128.0 / write_latency;               // bits/ns

      $display("WRITE Latency: %0t ps, Bandwidth: %0.2f MBps", write_latency, write_bandwidth * 125);

      #10; // keep minimal delay
    end

// READ + VERIFY loop
    for (i = 0; i < 4; i = i + 1) begin
      iread_address = test_addr[i];
      $display("[%0t] READ[%0d] from addr = %h", $time, i, test_addr[i]);
      
      read_start_time = $time;
      iread_req = 1;
      #10 iread_req = 0;
      wait (oread_ack == 1);
      $display("[%0t] Read acknowledged.", $time);
      read_end_time = $time;

      read_latency = (read_end_time - read_start_time);  // ns
      read_bandwidth = 128.0 / read_latency;             // bits/ns

      if (oread_data !== test_data[i])
        $display("[%0t] MISMATCH at addr %h: Expected %h, Got %h", $time, test_addr[i], test_data[i], oread_data);
      else
        $display("[%0t] MATCH at addr %h: %h", $time, test_addr[i], oread_data);

      $display("READ Latency: %0t ps, Bandwidth: %0.2f MBps", read_latency, read_bandwidth * 125);

      #10;

    end
      $display("[%0t] All tests completed!", $time);
      $finish;
  end
endmodule