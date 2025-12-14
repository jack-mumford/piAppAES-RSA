`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/04/2025 08:06:45 PM
// Design Name: 
// Module Name: RSA_Module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns/1ps

module RSA_Module #(
    parameter WIDTH = 32   // bit-width of n, base, exponent, result
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 start,

    input  logic [WIDTH-1:0]     base,      // ciphertext or message
    input  logic [WIDTH-1:0]     exponent,  // d or e
    input  logic [WIDTH-1:0]     modulus,   // n

    output logic [WIDTH-1:0]     result,    // base^exponent mod modulus
    output logic                 done
);

    // Internal registers
    typedef enum logic [1:0] {
        S_IDLE,
        S_RUN,
        S_DONE
    } state_t;

    state_t          state, state_next;

    logic [WIDTH-1:0] base_reg, base_next;
    logic [WIDTH-1:0] exp_reg, exp_next;
    logic [WIDTH-1:0] mod_reg;             // fixed after start
    logic [WIDTH-1:0] res_reg, res_next;

    // For multiply, we use a double-width intermediate
    logic [2*WIDTH-1:0] mul_tmp;
    logic [WIDTH-1:0]   mul_mod;          // (a*b) mod mod_reg

    // ---------------------------------------------------------
    // Sequential state update
    // ---------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            base_reg <= '0;
            exp_reg  <= '0;
            mod_reg  <= '0;
            res_reg  <= '0;
        end else begin
            state    <= state_next;
            base_reg <= base_next;
            exp_reg  <= exp_next;
            res_reg  <= res_next;

            // modulus only loaded at start
            if (state == S_IDLE && start) begin
                mod_reg <= modulus;
            end
        end
    end

    // ---------------------------------------------------------
    // Combinational multiply-mod helper
    // (a * b) mod mod_reg
    // ---------------------------------------------------------
    function automatic logic [WIDTH-1:0] mulmod(
        input logic [WIDTH-1:0] a,
        input logic [WIDTH-1:0] b,
        input logic [WIDTH-1:0] m
    );
        logic [2*WIDTH-1:0] prod;
        prod   = a * b;
        mulmod = prod % m;
    endfunction

    // ---------------------------------------------------------
    // Next-state logic
    // ---------------------------------------------------------
    always_comb begin
        // defaults
        state_next = state;
        base_next  = base_reg;
        exp_next   = exp_reg;
        res_next   = res_reg;
        done       = 1'b0;

        case (state)
            S_IDLE: begin
                if (start) begin
                    // initialize algorithm
                    // res = 1 mod n
                    res_next  = {{(WIDTH-1){1'b0}}, 1'b1} % modulus;
                    base_next = base % modulus;
                    exp_next  = exponent;
                    state_next = S_RUN;
                end
            end

            S_RUN: begin
                if (exp_reg == '0) begin
                    // exponent finished
                    state_next = S_DONE;
                end else begin
                    // if LSB of exponent is 1: res = (res * base) mod n
                    if (exp_reg[0] == 1'b1) begin
                        res_next = mulmod(res_reg, base_reg, mod_reg);
                    end else begin
                        res_next = res_reg;
                    end

                    // base = (base * base) mod n
                    base_next = mulmod(base_reg, base_reg, mod_reg);

                    // shift exponent right by 1 bit
                    exp_next = exp_reg >> 1;
                end
            end

            S_DONE: begin
                done       = 1'b1;
                state_next = S_IDLE;  // ready for next operation
            end
        endcase
    end

    assign result = res_reg;

endmodule
