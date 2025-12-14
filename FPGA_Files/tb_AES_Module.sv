`timescale 1ns/1ps

module tb_AES_Module;

  logic clk;
  logic rst_n;
  logic start;

  logic [127:0] ciphertext;
  logic [127:0] key;
  logic [127:0] plaintext;
  logic         done;

  // Instantiate one-round AES decrypt module
  AES_Module dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .start     (start),
    .ciphertext(ciphertext),
    .key       (key),
    .plaintext (plaintext),
    .done      (done)
  );

  // 100 MHz clock
  initial clk = 0;
  always #5 clk = ~clk;

  // -------- Test values from your C program --------
  //
  // C flow (encryption one round):
  //   state0 = ABCDEF01020304050607080900000000
  //   key    = 12345678987654321234567898765432
  //   after Sub+Shift+Mix+XOR -> 08938A533D49A4F5DD8C42A3717876DA
  //
  // So for decrypt:
  //   ciphertext = 08938A533D49A4F5DD8C42A3717876DA
  //   key        = same as above
  //   expected plaintext = ABCDEF01020304050607080900000000

  localparam logic [127:0] CIPHERTEXT_CONST =
      128'h08938A533D49A4F5DD8C42A3717876DA;

  localparam logic [127:0] KEY_CONST =
      128'h12345678987654321234567898765432;

  localparam logic [127:0] PLAINTEXT_EXPECTED =
      128'hABCDEF01020304050607080900000000;

  initial begin
    rst_n      = 0;
    start      = 0;
    ciphertext = '0;
    key        = '0;

    // reset
    repeat (4) @(posedge clk);
    rst_n = 1;

    // apply inputs
    @(posedge clk);
    ciphertext = CIPHERTEXT_CONST;
    key        = KEY_CONST;

    // pulse start
    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;

    // wait for done
    wait (done == 1);
    @(posedge clk);

    $display("---------------------------------------------------");
    $display(" Decrypted output = %032h", plaintext);
    $display(" Expected output  = %032h", PLAINTEXT_EXPECTED);

    if (plaintext === PLAINTEXT_EXPECTED)
      $display(" TEST PASSED ✓");
    else begin
      $display(" TEST FAILED ✗");
      $display("   Got      = %032h", plaintext);
      $display("   Expected = %032h", PLAINTEXT_EXPECTED);
    end

    $display("---------------------------------------------------");

    #20;
    $finish;
  end

endmodule
