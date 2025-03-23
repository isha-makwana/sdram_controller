
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

    // Very small mock memory: 2 banks x 8 rows x 16 cols
    reg [15:0] mem [0:1][0:7][0:15];

    reg [12:0] active_row [0:1];
    reg [3:0]  col_latched;
    reg [2:0]  burst_counter = 0;

    reg [15:0] dq_out = 16'hzzzz;
    reg        dq_drive_en = 0;
    reg        reading = 0;

    assign dq = dq_drive_en ? dq_out : 16'bz;

    always @(posedge clk) begin
        if (!cs_n) begin
            // ACTIVE command
            if (!ras_n && cas_n && we_n) begin
                active_row[ba] <= addr;
                reading <= 0;
                dq_drive_en <= 0;
            end

            // WRITE command
            else if (!ras_n && !cas_n && !we_n) begin
                col_latched <= addr[3:0];
                reading <= 0;
                dq_drive_en <= 0;
                burst_counter <= 0;
            end

            // READ command
            else if (!ras_n && !cas_n && we_n) begin
                col_latched <= addr[3:0];
                reading <= 1;
                dq_drive_en <= 1;
                burst_counter <= 0;
                $display("[mock_sdram] READ triggered at time %0t", $time);
            end
        end

        // On each clock, either drive DQ (read) or latch it (write)
        if (reading) begin
            dq_out <= mem[ba][active_row[ba]][col_latched + burst_counter];
            burst_counter <= burst_counter + 1;
        end
        else begin
            dq_drive_en <= 0;
            if (!cs_n && !ras_n && !cas_n && !we_n) begin
                mem[ba][active_row[ba]][col_latched + burst_counter] <= dq;
                burst_counter <= burst_counter + 1;
                $display("[mock_sdram] WRITE data[%0d]: %h at time %0t", burst_counter, dq, $time);
            end
        end
    end

endmodule
