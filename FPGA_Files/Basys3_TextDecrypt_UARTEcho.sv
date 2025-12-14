`timescale 1ns/1ps

module Basys3_TextDecrypt_UARTEcho (
    input  logic clk,       // 100 MHz Basys3 clock
    input  logic btnC,      // center button (active-high reset)
    input  logic uart_rx,   // from PC
    output logic uart_tx    // to PC
);

    // ----------------------------------------------------------------
    // Reset: active-low for internal logic, derived from btnC
    // ----------------------------------------------------------------
    logic rst_n;
    assign rst_n = ~btnC;   // when button pressed, rst_n = 0 (reset)

    // ----------------------------------------------------------------
    // Parameters for UART
    // ----------------------------------------------------------------
    localparam int CLOCK_FREQ = 100_000_000;
    localparam int BAUD_RATE  = 115200;

    // ----------------------------------------------------------------
    // UART RX signals
    // ----------------------------------------------------------------
    logic [7:0] rx_data;
    logic       rx_valid;

    // ----------------------------------------------------------------
    // UART TX signals
    // ----------------------------------------------------------------
    logic [7:0] tx_data;
    logic       tx_start;
    logic       tx_busy;

    // ----------------------------------------------------------------
    // Decrypted plaintext block from hybrid core
    // ----------------------------------------------------------------
    logic [127:0] plaintext;
    logic         plaintext_valid;

    // ----------------------------------------------------------------
    // UART RX instance
    // ----------------------------------------------------------------
    UART_RX #(
        .CLK_FREQ (CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_rx_u (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_serial(uart_rx),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

    // ----------------------------------------------------------------
    // Hybrid RSA + AES decrypt core
    // For now: RSA acts as identity (d = 1, n = 0xFFFF...FFFF)
    // so that the "RSA ciphertext" is just the AES key in sim.
    // ----------------------------------------------------------------
    Hybrid_RSA_AES_Top #(
        .RSA_WIDTH(128),
        .RSA_D(128'h00000000000000000000000000000001), // d = 1
        .RSA_N(128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)  // large modulus
    ) hybrid_u (
        .clk            (clk),
        .rst_n          (rst_n),
        .rx_data        (rx_data),
        .rx_valid       (rx_valid),
        .plaintext      (plaintext),
        .plaintext_valid(plaintext_valid)
    );

    // ----------------------------------------------------------------
    // UART TX instance
    // ----------------------------------------------------------------
    UART_TX #(
        .CLK_FREQ (CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_u (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .tx_serial(uart_tx),
        .tx_busy  (tx_busy)
    );

    // ----------------------------------------------------------------
    // TX FSM: when plaintext_valid goes high, send 16 bytes of
    // plaintext back over UART (MSB first).
    // ----------------------------------------------------------------

    typedef enum logic [1:0] {
        TX_IDLE,
        TX_LOAD,
        TX_SEND_BYTE,
        TX_WAIT_BYTE
    } tx_state_t;

    tx_state_t   tx_state, tx_state_next;
    logic [3:0]  byte_idx, byte_idx_next;    // 0..15
    logic [127:0] plaintext_buf, plaintext_buf_next;
    logic        tx_start_next;
    logic [7:0]  tx_data_next;

    // Sequential registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state       <= TX_IDLE;
            byte_idx       <= 4'd0;
            plaintext_buf  <= 128'd0;
            tx_data        <= 8'd0;
            tx_start       <= 1'b0;
        end else begin
            tx_state       <= tx_state_next;
            byte_idx       <= byte_idx_next;
            plaintext_buf  <= plaintext_buf_next;
            tx_data        <= tx_data_next;
            tx_start       <= tx_start_next;
        end
    end

    // Next-state logic
    always_comb begin
        tx_state_next       = tx_state;
        byte_idx_next       = byte_idx;
        plaintext_buf_next  = plaintext_buf;
        tx_start_next       = 1'b0;   // default: no start pulse
        tx_data_next        = tx_data;

        case (tx_state)

            // Wait for a decrypted block
            TX_IDLE: begin
                if (plaintext_valid) begin
                    plaintext_buf_next = plaintext;
                    byte_idx_next      = 4'd0;
                    tx_state_next      = TX_LOAD;
                end
            end

            // Load next byte and start UART transmit
            TX_LOAD: begin
                // Send MSB-first: plaintext[127:120] first
                tx_data_next  = plaintext_buf[127 - 8*byte_idx -: 8];
                tx_start_next = 1'b1;
                tx_state_next = TX_SEND_BYTE;
            end

            // Wait for TX to acknowledge start (busy goes high)
            TX_SEND_BYTE: begin
                if (tx_busy) begin
                    tx_state_next = TX_WAIT_BYTE;
                end
            end

            // Wait for TX to finish current byte (busy goes low)
            TX_WAIT_BYTE: begin
                if (!tx_busy) begin
                    if (byte_idx == 4'd15) begin
                        // All 16 bytes sent
                        tx_state_next = TX_IDLE;
                    end else begin
                        byte_idx_next = byte_idx + 1;
                        tx_state_next = TX_LOAD;
                    end
                end
            end

            default: tx_state_next = TX_IDLE;
        endcase
    end

endmodule


