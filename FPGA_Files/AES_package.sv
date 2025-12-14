package AES_package;

  // Basic types
  typedef logic [7:0] byte_t;
  typedef byte_t state_t [0:15];   // state[0..15], same as your uint8_t state[16]

  // Column-major index: IDX(r,c) = c * 4 + r
  function automatic int idx(input int r, input int c);
    idx = c*4 + r;
  endfunction

  // ============================================================
  // Inverse S-box table (from your aes_tables.h)
  // INV_SBOX[x] = byte
  // ============================================================
  localparam byte_t INV_SBOX [0:255] = '{
    8'h52,8'h09,8'h6A,8'hD5,8'h30,8'h36,8'hA5,8'h38,
    8'hBF,8'h40,8'hA3,8'h9E,8'h81,8'hF3,8'hD7,8'hFB,
    8'h7C,8'hE3,8'h39,8'h82,8'h9B,8'h2F,8'hFF,8'h87,
    8'h34,8'h8E,8'h43,8'h44,8'hC4,8'hDE,8'hE9,8'hCB,
    8'h54,8'h7B,8'h94,8'h32,8'hA6,8'hC2,8'h23,8'h3D,
    8'hEE,8'h4C,8'h95,8'h0B,8'h42,8'hFA,8'hC3,8'h4E,
    8'h08,8'h2E,8'hA1,8'h66,8'h28,8'hD9,8'h24,8'hB2,
    8'h76,8'h5B,8'hA2,8'h49,8'h6D,8'h8B,8'hD1,8'h25,
    8'h72,8'hF8,8'hF6,8'h64,8'h86,8'h68,8'h98,8'h16,
    8'hD4,8'hA4,8'h5C,8'hCC,8'h5D,8'h65,8'hB6,8'h92,
    8'h6C,8'h70,8'h48,8'h50,8'hFD,8'hED,8'hB9,8'hDA,
    8'h5E,8'h15,8'h46,8'h57,8'hA7,8'h8D,8'h9D,8'h84,
    8'h90,8'hD8,8'hAB,8'h00,8'h8C,8'hBC,8'hD3,8'h0A,
    8'hF7,8'hE4,8'h58,8'h05,8'hB8,8'hB3,8'h45,8'h06,
    8'hD0,8'h2C,8'h1E,8'h8F,8'hCA,8'h3F,8'h0F,8'h02,
    8'hC1,8'hAF,8'hBD,8'h03,8'h01,8'h13,8'h8A,8'h6B,
    8'h3A,8'h91,8'h11,8'h41,8'h4F,8'h67,8'hDC,8'hEA,
    8'h97,8'hF2,8'hCF,8'hCE,8'hF0,8'hB4,8'hE6,8'h73,
    8'h96,8'hAC,8'h74,8'h22,8'hE7,8'hAD,8'h35,8'h85,
    8'hE2,8'hF9,8'h37,8'hE8,8'h1C,8'h75,8'hDF,8'h6E,
    8'h47,8'hF1,8'h1A,8'h71,8'h1D,8'h29,8'hC5,8'h89,
    8'h6F,8'hB7,8'h62,8'h0E,8'hAA,8'h18,8'hBE,8'h1B,
    8'hFC,8'h56,8'h3E,8'h4B,8'hC6,8'hD2,8'h79,8'h20,
    8'h9A,8'hDB,8'hC0,8'hFE,8'h78,8'hCD,8'h5A,8'hF4,
    8'h1F,8'hDD,8'hA8,8'h33,8'h88,8'h07,8'hC7,8'h31,
    8'hB1,8'h12,8'h10,8'h59,8'h27,8'h80,8'hEC,8'h5F,
    8'h60,8'h51,8'h7F,8'hA9,8'h19,8'hB5,8'h4A,8'h0D,
    8'h2D,8'hE5,8'h7A,8'h9F,8'h93,8'hC9,8'h9C,8'hEF,
    8'hA0,8'hE0,8'h3B,8'h4D,8'hAE,8'h2A,8'hF5,8'hB0,
    8'hC8,8'hEB,8'hBB,8'h3C,8'h83,8'h53,8'h99,8'h61,
    8'h17,8'h2B,8'h04,8'h7E,8'hBA,8'h77,8'hD6,8'h26,
    8'hE1,8'h69,8'h14,8'h63,8'h55,8'h21,8'h0C,8'h7D
  };

  // Look up from the table
  function automatic byte_t aes_inv_sbox(input byte_t x);
    aes_inv_sbox = INV_SBOX[x];
  endfunction

  // ============================================================
  // InvSubBytes: state[i] = INV_SBOX[state[i]]
  // ============================================================
  function automatic void InvSubBytes(inout state_t state);
    for (int i = 0; i < 16; i++) begin
      state[i] = aes_inv_sbox(state[i]);
    end
  endfunction

  // ============================================================
  // InvShiftRows: right rotate each row by row index
  //   Row 0: no shift
  //   Row 1: right by 1
  //   Row 2: right by 2
  //   Row 3: right by 3
  // Same column-major layout as your IDX macro.
  // ============================================================
  function automatic void InvShiftRows(inout state_t state);
    byte_t row[0:3];

    // Row 0: no shift

    // Rows 1..3: right-rotate by r positions
    for (int r = 1; r < 4; r++) begin
      // Load row r (columns 0..3)
      row[0] = state[idx(r, 0)];
      row[1] = state[idx(r, 1)];
      row[2] = state[idx(r, 2)];
      row[3] = state[idx(r, 3)];

      // Right rotate row r by r positions:
      // state(r,c) = row[(c + 4 - r) % 4]
      state[idx(r, 0)] = row[(0 + 4 - r) % 4];
      state[idx(r, 1)] = row[(1 + 4 - r) % 4];
      state[idx(r, 2)] = row[(2 + 4 - r) % 4];
      state[idx(r, 3)] = row[(3 + 4 - r) % 4];
    end
  endfunction

  // ============================================================
  // xtime: multiply by 0x02 in GF(2^8) (same as your C helper)
  // ============================================================
  function automatic byte_t xtime(input byte_t x);
    if (x[7]) begin
      xtime = {x[6:0], 1'b0} ^ 8'h1B;
    end else begin
      xtime = {x[6:0], 1'b0};
    end
  endfunction

  // ============================================================
  // mul9 / mul11 / mul13 / mul14
  // Based on your comments:
  //   9  = 2*2*2 + 1   = 8x + x
  //   11 = 2*2*2 + 2 + 1 = 8x + 2x + x
  //   13 = 2*2*2 + 2*2 + 1 = 8x + 4x + x
  //   14 = 2*2*2 + 2*2 + 2 = 8x + 4x + 2x
  // ============================================================
  function automatic byte_t mul9(input byte_t x);
    byte_t x2, x4, x8;
    x2 = xtime(x);
    x4 = xtime(x2);
    x8 = xtime(x4);
    mul9 = x8 ^ x;               // 8x + x
  endfunction

  function automatic byte_t mul11(input byte_t x);
    byte_t x2, x4, x8;
    x2 = xtime(x);
    x4 = xtime(x2);
    x8 = xtime(x4);
    mul11 = x8 ^ x2 ^ x;         // 8x + 2x + x
  endfunction

  function automatic byte_t mul13(input byte_t x);
    byte_t x2, x4, x8;
    x2 = xtime(x);
    x4 = xtime(x2);
    x8 = xtime(x4);
    mul13 = x8 ^ x4 ^ x;         // 8x + 4x + x
  endfunction

  function automatic byte_t mul14(input byte_t x);
    byte_t x2, x4, x8;
    x2 = xtime(x);
    x4 = xtime(x2);
    x8 = xtime(x4);
    mul14 = x8 ^ x4 ^ x2;        // 8x + 4x + 2x
  endfunction

  // ============================================================
  // InvMixColumns: multiply each column by the inverse matrix
  //   [0E 0B 0D 09;
  //    09 0E 0B 0D;
  //    0D 09 0E 0B;
  //    0B 0D 09 0E]
  // ============================================================
  function automatic void InvMixColumns(inout state_t state);
    byte_t s0, s1, s2, s3;
    byte_t s0p, s1p, s2p, s3p;

    for (int c = 0; c < 4; c++) begin
      s0 = state[idx(0, c)];
      s1 = state[idx(1, c)];
      s2 = state[idx(2, c)];
      s3 = state[idx(3, c)];

      s0p = mul14(s0) ^ mul11(s1) ^ mul13(s2) ^ mul9(s3);
      s1p = mul9(s0)  ^ mul14(s1) ^ mul11(s2) ^ mul13(s3);
      s2p = mul13(s0) ^ mul9(s1)  ^ mul14(s2) ^ mul11(s3);
      s3p = mul11(s0) ^ mul13(s1) ^ mul9(s2)  ^ mul14(s3);

      state[idx(0, c)] = s0p;
      state[idx(1, c)] = s1p;
      state[idx(2, c)] = s2p;
      state[idx(3, c)] = s3p;
    end
  endfunction

  // ============================================================
  // AddRoundKey: same for encryption and decryption
  // state[i] ^= roundKey[i]
  // ============================================================
  function automatic void AddRoundKey(
    inout state_t state,
    input  state_t roundKey
  );
    for (int i = 0; i < 16; i++) begin
      state[i] = state[i] ^ roundKey[i];
    end
  endfunction

endpackage : AES_package
