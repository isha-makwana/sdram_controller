`timescale 1ns / 1ps

module sdram_controller_tb;

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

  // Timing metrics
  time op_start_time, op_end_time;
  real latency;
  real bandwidth;

  time total_start_time, total_end_time;
  real total_bandwidth;

  // SDRAM interface
  wire [12:0] DRAM_ADDR;
  wire [1:0]  DRAM_BA;
  wire        DRAM_CAS_N, DRAM_CKE, DRAM_CLK, DRAM_CS_N;
  wire [15:0] DRAM_DQ;
  wire        DRAM_LDQM, DRAM_RAS_N, DRAM_UDQM, DRAM_WE_N;
  wire        oinit_done;

  // Clock generation
  always #5 iclk = ~iclk; // 100 MHz

  // DUT
  sdram_controller dut (
    .iclk(iclk), .ireset(ireset),
    .iwrite_req(iwrite_req), .iwrite_address(iwrite_address), .iwrite_data(iwrite_data), .owrite_ack(owrite_ack),
    .iread_req(iread_req), .iread_address(iread_address), .oread_data(oread_data), .oread_ack(oread_ack),
    .oinit_done(oinit_done),
    .DRAM_ADDR(DRAM_ADDR), .DRAM_BA(DRAM_BA), .DRAM_CAS_N(DRAM_CAS_N), .DRAM_CKE(DRAM_CKE), .DRAM_CLK(DRAM_CLK),
    .DRAM_CS_N(DRAM_CS_N), .DRAM_DQ(DRAM_DQ), .DRAM_LDQM(DRAM_LDQM), .DRAM_RAS_N(DRAM_RAS_N),
    .DRAM_UDQM(DRAM_UDQM), .DRAM_WE_N(DRAM_WE_N)
  );

  // Mock SDRAM
  mock_sdram sdram_chip (
    .clk(iclk), .cs_n(DRAM_CS_N), .ras_n(DRAM_RAS_N), .cas_n(DRAM_CAS_N), .we_n(DRAM_WE_N),
    .ba(DRAM_BA), .addr(DRAM_ADDR), .dq(DRAM_DQ), .ldqm(DRAM_LDQM), .udqm(DRAM_UDQM), .init_done(oinit_done)
  );

  // Test vectors
  reg [127:0] test_data [0:3];
  reg [21:0]  test_addr [0:3];
  integer i;

  initial begin
    ireset = 1;
    iwrite_req = 0; iread_req = 0;
    iwrite_address = 0; iread_address = 0;
    iwrite_data = 0;

    test_data[0] = 128'hDEADBEEFCAFEBABE123456789ABCDEF0;
    test_data[1] = 128'h0123456789ABCDEFFEDCBA9876543210;
    test_data[2] = 128'hAAAAAAAA55555555FFFFFFFF00000000;
    test_data[3] = 128'hFACEFACEFACEFACEFACEFACEFACEFACE;

    test_addr[0] = 22'h000001;
    test_addr[1] = 22'h000002;
    test_addr[2] = 22'h000003;
    test_addr[3] = 22'h000004;

    #50 ireset = 0;
    $display("[%0t] Waiting for SDRAM init...", $time);
    wait(oinit_done == 1);
    $display("[%0t] SDRAM ready!", $time);
    #10;

      total_start_time = $time;
    // Interleaved Write-Read Ops
    for (i = 0; i < 4; i = i + 1) begin
      // Write

      $display("[%0t] Issuing write request.", $time);
      iwrite_address = test_addr[i];
      iwrite_data = test_data[i];
      op_start_time = $time;
      iwrite_req = 1;
      #10 iwrite_req = 0;
      wait(owrite_ack == 1);
      op_end_time = $time;

      latency = (op_end_time - op_start_time);
      bandwidth = 128.0 / latency;
      $display("WRITE[%0d] to %h @ %0t | Latency: %0t ns, Bandwidth: %0.2f MBps", i, test_addr[i], $time, latency, bandwidth * 125);

      // Immediately follow with a Read
      $display("[%0t] Issuing read request.", $time);
      iread_address = test_addr[i];
      op_start_time = $time;
      iread_req = 1;
      #10 iread_req = 0;
      wait(oread_ack == 1);
      op_end_time = $time;

      latency = (op_end_time - op_start_time);
      bandwidth = 128.0 / latency;
      if (oread_data !== test_data[i])
        $display("READ[%0d] from %h @ %0t | MISMATCH! Expected: %h, Got: %h", i, test_addr[i], $time, test_data[i], oread_data);
      else
        $display("READ[%0d] from %h @ %0t | MATCHED: %h", i, test_addr[i], $time, oread_data);

      $display("READ Latency: %0t ns, Bandwidth: %0.2f MBps", latency, bandwidth * 125);

      #10;
    end
    total_end_time = $time;
    total_bandwidth = (8 * 128.0) / (total_end_time - total_start_time);  // 4 writes + 4 reads
    $display("Total Time: %0t ns", total_end_time - total_start_time);
    $display("Average Bandwidth: %0.2f MBps", total_bandwidth * 125);
    $display("[%0t] Interleaved test complete.", $time);
    $finish;
  end

endmodule