module alu(
    input   [31:0]  a, b,
    input   [4:0]   control,
    output  reg [31:0]  result,
    output  N,
    output  Z,
    output  C,
    output  V
    );
    
// Internal signals for addition/subtraction
    wire [31:0] sum;
    wire [32:0] c;  // carry chain
    wire sub;       // subtraction control
    
    // Subtraction control: 1 for SUB, 0 for ADD
    assign sub = control[0];  // control[0] = 1 for SUB
    
    // 32-bit adder/subtractor using full adder chain
    assign c[0] = sub;  // carry in for subtraction (2's complement)
    
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : adder_chain
            assign {c[i+1], sum[i]} = a[i] + (b[i] ^ sub) + c[i];
        end
    endgenerate
    
    // ALU operations
    always @(*) begin
        case(control)
            5'b00000: result = sum;                    // ADD
            5'b00001: result = sum;                    // SUB
            5'b00010: result = a << b[4:0];           // SLL (Shift Left Logical)
            5'b00011: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;  // SLT
            5'b00100: result = (a < b) ? 32'd1 : 32'd0;  // SLTU
            5'b00101: result = a ^ b;                  // XOR
            5'b00110: result = a >> b[4:0];           // SRL (Shift Right Logical)
            5'b00111: result = $signed(a) >>> b[4:0]; // SRA (Shift Right Arithmetic)
            5'b01000: result = a | b;                  // OR
            5'b01001: result = a & b;                  // AND
            default:  result = 32'd0;
        endcase
    end
    
    // Status flags
    assign N = sum[31];           // Negative flag
    assign Z = (sum == 32'b0);    // Zero flag
    assign C = c[32];             // Carry out
    assign V = c[31] ^ c[32];     // Overflow flag
    
endmodule