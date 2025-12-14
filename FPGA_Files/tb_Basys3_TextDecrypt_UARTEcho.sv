`timescale 1ns/1ps

module tb_Basys3_TextDecrypt_UARTEcho;

  // 100 MHz clock, like Basys3
  logic clk;
  initial clk = 0;
  always #5 clk = ~clk;   // 10 ns period -> 100 MHz

  // DUT I/O
  logic btnC;      // reset button (active high)
  logic uart_rx;   // testbench -> DUT
  logic uart_tx;   // DUT -> testbench

  // UART timing constants
  localparam integer BAUD_TICKS = 100_000_000 / 115200; // 868

  // Known AES test vectors
  localparam logic [127:0] AES_KEY = 
      128'h12345678987654321234567898765432;

  localparam logic [127:0] AES_CIPHERTEXT =
      128'h08938A533D49A4F5DD8C42A3717876DA;

  localparam logic [127:0] PLAINTEXT_EXPECTED =
      128'hABCDEF01020304050607080900000000;

  // UART "receiver" buffer in TB
  logic [7:0] rx_buf [0:15];
  integer     rx_count = 0;
  logic       done_receiving = 0;

  // Shared temporaries for loops / capture
  integer      i;
  integer      k;
  logic [7:0]  byte_recv;
  logic [127:0] plaintext_recv;

  // Instantiate the top-level Basys3 design
  Basys3_TextDecrypt_UARTEcho dut (
      .clk    (clk),
      .btnC   (btnC),
      .uart_rx(uart_rx),
      .uart_tx(uart_tx)
  );

  // ----------------------------------------------------------------
  // UART "transmitter model" in the TESTBENCH
  //   - Drives uart_rx to send bytes *into* the DUT
  //   - 8-N-1 framing: 1 start, 8 data (LSB first), 1 stop
  // ----------------------------------------------------------------
  task automatic uart_send_byte(input logic [7:0] b);
    begin
    $display("[TB] Sending byte %0d at time %0t", k, $time);
      // Ensure idle high for at least 1 bit time
      uart_rx = 1'b1;
      repeat (BAUD_TICKS) @(posedge clk);

      // Start bit (low)
      uart_rx = 1'b0;
      repeat (BAUD_TICKS) @(posedge clk);

      // Data bits (LSB first)
      for (i = 0; i < 8; i++) begin
        uart_rx = b[i];
        repeat (BAUD_TICKS) @(posedge clk);
      end

      // Stop bit (high)
      uart_rx = 1'b1;
      repeat (BAUD_TICKS) @(posedge clk);
    end
  endtask

  // ----------------------------------------------------------------
  // UART "receiver model" in the TESTBENCH
  //   - Monitors uart_tx and reconstructs bytes sent by the DUT
  //   - Stores up to 16 bytes (one AES block)
  // ----------------------------------------------------------------
  initial begin : UART_MONITOR
    // Initialize
    for (i = 0; i < 16; i++) rx_buf[i] = 8'h00;
    rx_count       = 0;
    done_receiving = 0;

    // Wait for global reset deassert
    @(negedge btnC); // reset goes low in main initial block

    // Wait forever for start bits
    forever begin
      // Wait for start bit: line goes low
      @(negedge uart_tx);
      // Align sampling to middle of start bit
      repeat (BAUD_TICKS/2) @(posedge clk);

      // Now sample 8 data bits, 1 bit per BAUD_TICKS
      for (i = 0; i < 8; i++) begin
        repeat (BAUD_TICKS) @(posedge clk);
        byte_recv[i] = uart_tx;   // LSB first
      end

      // Sample (and ignore) stop bit
      repeat (BAUD_TICKS) @(posedge clk);

      // Store the byte
      if (rx_count < 16) begin
        rx_buf[rx_count] = byte_recv;
        rx_count = rx_count + 1;
        if (rx_count == 16) begin
          done_receiving = 1'b1;
          disable UART_MONITOR; // stop after first block
        end
      end
    end
  end

  // ----------------------------------------------------------------
  // Main stimulus: reset, then send 32 "UART bytes" into UART_RX:
  //   - First 16 bytes: RSA ciphertext of AES key
  //       For now we use AES_KEY directly, and configure RSA with D=1
  //   - Next 16 bytes: AES_CIPHERTEXT
  // DUT should:
  //   - use RSA to "decrypt" key (identity)
  //   - use AES to decrypt block
  //   - send plaintext bytes out on uart_tx
  // ----------------------------------------------------------------
  initial begin
    // Initial conditions
    btnC    = 1'b1; // assert reset (active high)
    uart_rx = 1'b1; // idle line high

    // Wait a bit
    repeat (20) @(posedge clk);
    btnC = 1'b0;   // deassert reset

    // Wait a few cycles after reset
    repeat (20) @(posedge clk);

    $display("[TB] Sending 16 bytes of AES_KEY as RSA ciphertext...");
    for (k = 0; k < 16; k++) begin
      // MSB-first, matches Hybrid_RSA_AES_Top packing
      uart_send_byte(AES_KEY[127 - 8*k -: 8]);
    end

    $display("[TB] Sending 16 bytes of AES_CIPHERTEXT...");
    for (k = 0; k < 16; k++) begin
      uart_send_byte(AES_CIPHERTEXT[127 - 8*k -: 8]);
    end

    // Now wait until we've captured 16 bytes from uart_tx
    wait (done_receiving == 1'b1);

    // Reassemble the received bytes into a 128-bit word
    plaintext_recv = '0;
    for (k = 0; k < 16; k++) begin
      plaintext_recv[127 - 8*k -: 8] = rx_buf[k];
    end

    $display("-------------------------------------------------------------");
    $display(" Received plaintext over UART = %032h", plaintext_recv);
    $display(" Expected plaintext           = %032h", PLAINTEXT_EXPECTED);

    if (plaintext_recv === PLAINTEXT_EXPECTED)
      $display(" BASYS3 UART DECRYPT TEST PASSED ✓");
    else begin
      $display(" BASYS3 UART DECRYPT TEST FAILED ✗");
      for (k = 0; k < 16; k++) begin
        $display("  Byte %0d: got %02h  expected %02h",
                 k, rx_buf[k], PLAINTEXT_EXPECTED[127 - 8*k -: 8]);
      end
    end
    $display("-------------------------------------------------------------");

    #5_000_000;
    $finish;
  end

endmodule
