`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/04/2025 08:09:41 PM
// Design Name: 
// Module Name: AES_Module
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


module AES_Module (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,

    input  logic [127:0] ciphertext,  // input state
    input  logic [127:0] key,         // single 128-bit round key

    output logic [127:0] plaintext,   // output state
    output logic         done
);

    import AES_package::*;  // must contain state_t, InvShiftRows, InvSubBytes, InvMixColumns, AddRoundKey

    // Internal state as 16 bytes
    state_t state;

    // Simple FSM
    typedef enum logic [1:0] {
        S_IDLE,
        S_RUN,
        S_DONE
    } dec_state_t;

    dec_state_t curr, next;

 // unpack: 128-bit bus -> state[0..15] where state[0] is first hex byte
function automatic state_t unpack(input logic [127:0] v);
    state_t tmp;
    for (int j = 0; j < 16; j++) begin
        tmp[j] = v[127 - 8*j -: 8];  // take bytes from MSB downwards
    end
    return tmp;
endfunction

// pack: state[0..15] -> 128-bit bus, state[0] goes to MSB
function automatic logic [127:0] pack(input state_t s);
    logic [127:0] v;
    for (int j = 0; j < 16; j++) begin
        v[127 - 8*j -: 8] = s[j];
    end
    return v;
endfunction


function automatic state_t do_one_round_dec(
    input state_t       s_in,
    input logic [127:0] key128
);
    state_t s, k;
    s = s_in;

    // unpack key into bytes (MSB first, like C)
    for (int j = 0; j < 16; j++) begin
        k[j] = key128[127 - 8*j -: 8];
    end

    // Correct decryption order for your C example:
    AddRoundKey(s, k);   // XOR first
    InvMixColumns(s);
    InvShiftRows(s);
    InvSubBytes(s);

    return s;
endfunction


    // sequential FSM + state update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr  <= S_IDLE;
            state <= '{default:8'h00};
        end else begin
            curr <= next;

            case (curr)
                S_IDLE: begin
                    if (start) begin
                        state <= unpack(ciphertext);
                    end
                end

                S_RUN: begin
                    state <= do_one_round_dec(state, key);
                end

                S_DONE: begin
                    // nothing; output is driven from 'state'
                end
            endcase
        end
    end

    // next-state + done logic
    always_comb begin
        next = curr;
        done = 1'b0;

        case (curr)
            S_IDLE: begin
                if (start) begin
                    next = S_RUN;
                end
            end

            S_RUN: begin
                next = S_DONE;
            end

            S_DONE: begin
                done = 1'b1;
                next = S_IDLE;
            end
        endcase
    end

    // output
    assign plaintext = pack(state);

endmodule
