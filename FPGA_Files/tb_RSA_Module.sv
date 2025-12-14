`timescale 1ns/1ps

module tb_RSA_Module;

  localparam int WIDTH = 12;  // 3233 fits in 12 bits (2^12=4096)

  logic                 clk;
  logic                 rst_n;
  logic                 start;
  logic [WIDTH-1:0]     base;
  logic [WIDTH-1:0]     exponent;
  logic [WIDTH-1:0]     modulus;

  logic [WIDTH-1:0]     result;
  logic                 done;

  // Instantiate DUT
  RSA_Module #(.WIDTH(WIDTH)) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .start   (start),
    .base    (base),
    .exponent(exponent),
    .modulus (modulus),
    .result  (result),
    .done    (done)
  );

  // clock
  initial clk = 0;
  always #5 clk = ~clk;

  // RSA test vector:
  //
  // n = 3233 (0xCA1)
  // e = 17   (0x11)
  // d = 2753 (0xAC1)
  // m = 65   (0x41)
  // c = 2790 (0xAE6)
  localparam logic [WIDTH-1:0] N  = 12'd3233;  // 0xCA1
  localparam logic [WIDTH-1:0] E  = 12'd17;    // 0x011
  localparam logic [WIDTH-1:0] D  = 12'd2753;  // 0xAC1
  localparam logic [WIDTH-1:0] M  = 12'd65;    // message
  localparam logic [WIDTH-1:0] C  = 12'd2790;  // ciphertext

  initial begin
    rst_n   = 0;
    start   = 0;
    base    = '0;
    exponent= '0;
    modulus = '0;

    repeat (4) @(posedge clk);
    rst_n = 1;

    // ---------- Test 1: Encrypt m with e (m^e mod n should be C) ----------
    @(posedge clk);
    base     = M;
    exponent = E;
    modulus  = N;
    start    = 1;
    @(posedge clk);
    start    = 0;

    wait (done);
    @(posedge clk);
    $display("Encrypt: m^e mod n = %0d (0x%0h), expected %0d (0x%0h)", 
              result, result, C, C);

    // ---------- Test 2: Decrypt c with d (c^d mod n should be M) ----------
    @(posedge clk);
    base     = C;
    exponent = D;
    modulus  = N;
    start    = 1;
    @(posedge clk);
    start    = 0;

    wait (done);
    @(posedge clk);
    $display("Decrypt: c^d mod n = %0d (0x%0h), expected %0d (0x%0h)", 
              result, result, M, M);

    if (result === M)
      $display("RSA TEST PASSED ✓");
    else
      $display("RSA TEST FAILED ✗");

    #20;
    $finish;
  end

endmodule

