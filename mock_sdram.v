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
    input         udqm
);

    reg [3:0]  col_latched;
    reg [3:0]  burst_counter = 0;

    reg [15:0] dq_out = 16'hzzzz;
    reg        dq_drive_en = 0;
    reg        reading = 0;
    reg        delay_read = 0;

    reg        last_cas_n;
    reg        last_we_n;

    assign dq = dq_drive_en ? dq_out : 16'bz;

    always @(posedge clk) begin
        last_cas_n <= cas_n;
        last_we_n  <= we_n;

        if (!cs_n) begin
            // ACTIVE command
            if (!ras_n && cas_n && we_n) begin
                reading <= 0;
                dq_drive_en <= 0;
                delay_read <= 0;
                $display("[mock_sdram] ACTIVE command at %0t", $time);
            end

            // WRITE command ? do nothing, just print
            else if (!ras_n && !cas_n && !we_n) begin
                $display("[mock_sdram] WRITE command at %0t", $time);
            end

            // READ command - rising edge detect
            else if (ras_n && !cas_n && we_n && (last_cas_n || !last_we_n)) begin
                col_latched <= addr[3:0];
                burst_counter <= 0;
                delay_read <= 1;
                dq_out <= 16'hABCD;  // preload with known value
                $display("[mock_sdram] READ command detected. Preparing to drive DQ @ %0t", $time);
            end
        end

        // Delay to simulate CAS latency
        if (delay_read) begin
            dq_drive_en <= 1;
            reading <= 1;
            delay_read <= 0;
        end else if (!reading) begin
            dq_drive_en <= 0;
        end

        // Mock burst read (8-beat limit)
        if (reading && dq_drive_en) begin
            dq_out <= 16'hABCD + burst_counter;
            $display("[mock_sdram] Driving DQ = %h (burst %0d) @ %0t", dq_out, burst_counter, $time);
            burst_counter <= burst_counter + 1;

            if (burst_counter == 8) begin
                reading <= 0;
                dq_drive_en <= 0;
                dq_out <= 16'hzzzz;
                $display("[mock_sdram] End of 8-beat burst. Releasing DQ @ %0t", $time);
            end
        end
    end

endmodule
