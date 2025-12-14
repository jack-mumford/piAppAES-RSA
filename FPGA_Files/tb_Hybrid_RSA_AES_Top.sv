`timescale 1ns/1ps

module tb_Hybrid_RSA_AES_Top;

  // Clock and reset
  logic clk;
  logic rst_n;

  // "UART RX" style inputs to the hybrid module
  logic [7:0] rx_data;
  logic       rx_valid;

  // Outputs from the hybrid module
  logic [127:0] plaintext;
  logic         plaintext_valid;

  // 100 MHz clock
  initial clk = 0;
  always #5 clk = ~clk;

  // ------------------------------------------------------------
  // Use your known AES test vectors from the earlier example
  // ------------------------------------------------------------

  // AES key (what RSA should output)
  localparam logic [127:0] AES_KEY = 
      128'h12345678987654321234567898765432;

  // Ciphertext produced by your C one-round AES encrypt
  localparam logic [127:0] AES_CIPHERTEXT =
      128'h08938A533D49A4F5DD8C42A3717876DA;

  // Expected plaintext
  localparam logic [127:0] PLAINTEXT_EXPECTED =
      128'hABCDEF01020304050607080900000000;

  // ------------------------------------------------------------
  // DUT: Hybrid RSA + AES
  // NOTE: For this test, we configure RSA to be an "identity"
  //       decrypt: exponent D = 1, modulus N is large.
  //       So result = base^1 mod N = base.
  //       We then feed AES_KEY as the "RSA ciphertext".
  // ------------------------------------------------------------

  Hybrid_RSA_AES_Top #(
      .RSA_WIDTH(128),
      .RSA_D(128'h0000_0000_0000_0000_0000_0000_0000_0001), // d = 1
      .RSA_N(128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF)  // big modulus
  ) dut (
      .clk            (clk),
      .rst_n          (rst_n),
      .rx_data        (rx_data),
      .rx_valid       (rx_valid),
      .plaintext      (plaintext),
      .plaintext_valid(plaintext_valid)
  );

  // ------------------------------------------------------------
  // Task: send one byte as if it came from UART RX
  //   - rx_valid = 1 for one clock with rx_data stable
  // ------------------------------------------------------------
  task automatic send_byte(input logic [7:0] b);
    begin
      @(posedge clk);
      rx_data  <= b;
      rx_valid <= 1'b1;
      @(posedge clk);
      rx_valid <= 1'b0;
    end
  endtask

  // ------------------------------------------------------------
  // Initial block: apply reset, then send 32 bytes:
  //   16 bytes: "RSA ciphertext" of AES key
  //   16 bytes: AES ciphertext block
  //
  // Because RSA_D = 1, RSA just returns the base, so we send:
  //   first 16 bytes  = AES_KEY (MSB first)
  //   next  16 bytes  = AES_CIPHERTEXT (MSB first)
  // ------------------------------------------------------------
  integer i;

  initial begin
    // init
    rst_n    = 0;
    rx_data  = 8'd0;
    rx_valid = 1'b0;

    // hold reset a few cycles
    repeat (4) @(posedge clk);
    rst_n = 1;

    // Small delay before sending data
    repeat (2) @(posedge clk);

    // --- Send 16 bytes of "RSA-encrypted AES key"
    //     In this test, that's just AES_KEY itself.
    //     Hybrid module expects MSB-first, because it packs:
    //       aes_key_cipher[127 - 8*j -: 8] = rx_data;
    $display("Sending 16 bytes of AES key as RSA ciphertext...");
    for (i = 0; i < 16; i++) begin
      send_byte(AES_KEY[127 - 8*i -: 8]);
    end

    // --- Send 16 bytes of AES ciphertext block (also MSB-first)
    $display("Sending 16 bytes of AES ciphertext block...");
    for (i = 0; i < 16; i++) begin
      send_byte(AES_CIPHERTEXT[127 - 8*i -: 8]);
    end

    // Now wait for plaintext_valid from the DUT
    $display("Waiting for decrypted plaintext...");
    wait (plaintext_valid == 1'b1);
    @(posedge clk); // sample on next clock

    $display("-----------------------------------------------------");
    $display(" Decrypted plaintext = %032h", plaintext);
    $display(" Expected plaintext  = %032h", PLAINTEXT_EXPECTED);

    if (plaintext === PLAINTEXT_EXPECTED)
      $display(" TEST PASSED ✓");
    else begin
      $display(" TEST FAILED ✗");
      $display("   Got      = %032h", plaintext);
      $display("   Expected = %032h", PLAINTEXT_EXPECTED);
    end
    $display("-----------------------------------------------------");

    #20;
    $finish;
  end

endmodule
