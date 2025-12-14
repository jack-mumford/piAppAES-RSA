`timescale 1ns/1ps

module UART_RX #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic clk,
    input  logic rst_n,
    input  logic rx_serial,       // incoming UART line

    output logic [7:0] rx_data,   // received byte
    output logic       rx_valid   // 1-cycle pulse when byte ready
);

    // Number of clocks per bit
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // Synchronize input (avoid metastability)
    logic rx_sync_0, rx_sync_1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
        end else begin
            rx_sync_0 <= rx_serial;
            rx_sync_1 <= rx_sync_0;
        end
    end
    wire rx = rx_sync_1;

    // FSM
    typedef enum logic [2:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP,
        RX_CLEANUP
    } rx_state_t;

    rx_state_t state;
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] rx_shift;

    // Outputs
    assign rx_data = rx_shift;

    // Main RX logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= RX_IDLE;
            clk_count  <= '0;
            bit_index  <= 3'd0;
            rx_shift   <= 8'd0;
            rx_valid   <= 1'b0;
        end else begin
            rx_valid <= 1'b0;   // default

            case (state)

                // Wait for start bit (line goes low)
                RX_IDLE: begin
                    clk_count <= '0;
                    bit_index <= 3'd0;
                    if (rx == 1'b0) begin
                        state <= RX_START;
                    end
                end

                // Validate start bit in the middle of the bit period
                RX_START: begin
                    if (clk_count == (CLKS_PER_BIT/2)-1) begin
                        if (rx == 1'b0) begin
                            // valid start
                            clk_count <= '0;
                            state     <= RX_DATA;
                        end else begin
                            // false start, go back to idle
                            state <= RX_IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                // Receive 8 data bits (LSB first)
                RX_DATA: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;
                        rx_shift[bit_index] <= rx;  // sample
                        if (bit_index == 3'd7) begin
                            state     <= RX_STOP;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                // Receive stop bit
                RX_STOP: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        // ignore value; assume correct stop bit
                        rx_valid  <= 1'b1; // one-cycle pulse
                        clk_count <= '0;
                        state     <= RX_CLEANUP;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                RX_CLEANUP: begin
                    // one-cycle cleanup, then back to idle
                    state <= RX_IDLE;
                end

                default: state <= RX_IDLE;
            endcase
        end
    end

endmodule

