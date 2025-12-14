`timescale 1ns/1ps

module UART_TX #(
    parameter integer CLK_FREQ  = 100_000_000,
    parameter integer BAUD_RATE = 115200
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic [7:0] tx_data,    // byte to send
    input  logic       tx_start,   // 1-cycle pulse to start transmit

    output logic       tx_serial,  // UART TX line
    output logic       tx_busy     // 1 while transmitting a frame
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    typedef enum logic [2:0] {
        TX_IDLE,
        TX_START_BIT,
        TX_DATA_BITS,
        TX_STOP_BIT,
        TX_CLEANUP
    } tx_state_t;

    tx_state_t state;
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= TX_IDLE;
            clk_count <= '0;
            bit_index <= 3'd0;
            shift_reg <= 8'd0;
            tx_serial <= 1'b1;    // idle high
            tx_busy   <= 1'b0;
        end else begin
            case (state)

                TX_IDLE: begin
                    tx_serial <= 1'b1;
                    tx_busy   <= 1'b0;
                    clk_count <= '0;
                    bit_index <= 3'd0;

                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tx_busy   <= 1'b1;
                        state     <= TX_START_BIT;
                    end
                end

                TX_START_BIT: begin
                    tx_serial <= 1'b0; // start bit
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;
                        state     <= TX_DATA_BITS;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                TX_DATA_BITS: begin
                    tx_serial <= shift_reg[bit_index]; // LSB first
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= TX_STOP_BIT;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                TX_STOP_BIT: begin
                    tx_serial <= 1'b1;  // stop bit
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;
                        state     <= TX_CLEANUP;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                TX_CLEANUP: begin
                    tx_serial <= 1'b1;
                    tx_busy   <= 1'b0;
                    state     <= TX_IDLE;
                end

                default: state <= TX_IDLE;
            endcase
        end
    end

endmodule

