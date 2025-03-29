`timescale 1ns / 1ps

module mock_sdram (
    input         clk,
    input         cs_n,
    input         ras_n,
    input         cas_n,
    input         we_n,
    input  [1:0]  ba,
    input  [12:0] addr,
    inout  [15:0] dq,
    input         ldqm,
    input         udqm,
    input         init_done
);

    reg [15:0] mem [0:1][0:7][0:15];  // [bank][row][col]

    reg [12:0] active_row [0:1];
    reg [3:0]  col_latched;
    reg [3:0]  burst_counter = 0;

    reg [15:0] dq_out = 16'hzzzz;
    reg        dq_drive_en = 0;
    reg        reading = 0;
    reg        writing = 0;
    reg        delay_read = 0;
    reg [1:0]  cas_latency_counter = 0;

    reg        last_cas_n;
    reg        last_we_n;
    reg [15:0] dq_latched;

    assign dq = dq_drive_en ? dq_out : 16'bz;

    always @(posedge clk) begin
        dq_latched <= dq;
        $display("[mock_sdram] DQ_capture <= %h (latched: %h) @ bank=%0d row=%0d col=%0d @ %0t", dq, dq_latched, ba, active_row[ba], col_latched + burst_counter, $time);

        last_cas_n <= cas_n;
        last_we_n  <= we_n;

        if (!cs_n) begin
            // ACTIVE command
            if (!ras_n && cas_n && we_n) begin
                active_row[ba] <= addr;
                reading <= 0;
                writing <= 0;
                dq_drive_en <= 0;
                delay_read <= 0;
                cas_latency_counter <= 0;
                $display("[mock_sdram] ACTIVE: row=%0d bank=%0d @ %0t", addr, ba, $time);
            end

            // WRITE command
            else if (ras_n && !cas_n && !we_n) begin
                col_latched <= addr[3:0];
                burst_counter <= 0;
                writing <= 1;
                reading <= 0;
                dq_drive_en <= 0;
                delay_read <= 0;
                $display("[mock_sdram] WRITE CMD: Preparing to write to bank=%0d row=%0d col=%0d @ %0t", ba, active_row[ba], addr[3:0], $time);
            end

            // READ command (rising edge detect)
            else if (ras_n && !cas_n && we_n && (last_cas_n || !last_we_n)) begin
                col_latched <= addr[3:0];
                burst_counter <= 0;
                cas_latency_counter <= 2;  // CAS latency = 2 cycles
                reading <= 0;
                writing <= 0;
                dq_drive_en <= 0;
                $display("[mock_sdram] READ CMD: bank=%0d row=%0d col=%0d @ %0t", ba, active_row[ba], addr[3:0], $time);
            end
        end

        // Perform write
        if (writing) begin
            mem[ba][active_row[ba]][col_latched + burst_counter] <= dq_latched;
            $display("[mock_sdram] WRITE[%0d] <= %h @ bank=%0d row=%0d col=%0d @ %0t", burst_counter, dq_latched, ba, active_row[ba], col_latched + burst_counter, $time);
            burst_counter <= burst_counter + 1;
            if (burst_counter == 7) begin
                writing <= 0;
            end
        end

        // Wait for CAS latency
        if (cas_latency_counter > 0) begin
            cas_latency_counter <= cas_latency_counter - 1;
            if (cas_latency_counter == 1) begin
                reading <= 1;
                dq_drive_en <= 1;
            end
        end

        // READ burst
        if (reading && dq_drive_en) begin
            dq_out <= mem[ba][active_row[ba]][col_latched + burst_counter];
            $display("[mock_sdram] READ[%0d] = %h from bank=%0d row=%0d col=%0d @ %0t",
                     burst_counter,
                     mem[ba][active_row[ba]][col_latched + burst_counter],
                     ba, active_row[ba], col_latched + burst_counter, $time);
            burst_counter <= burst_counter + 1;

            if (burst_counter == 8) begin
                reading <= 0;
                dq_drive_en <= 0;
                dq_out <= 16'hzzzz;
                $display("[mock_sdram] END of burst ? releasing DQ @ %0t", $time);
            end
        end
    end

endmodule
