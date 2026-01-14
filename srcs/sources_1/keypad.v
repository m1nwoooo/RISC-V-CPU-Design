module Keypad(
    input clk, rst, CS,
    input [11:0] Addr,
    output reg [31:0] DataOut
    );
    
    // tb로만 검증

    reg [3:0] key_val_reg; 
    reg key_pressed_reg;  
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            key_val_reg <= 4'b0;
            key_pressed_reg <= 1'b0;
        end
        
    end

    // read memory map - Registered
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            DataOut <= 32'b0;
        end else if (CS) begin
            if (Addr[3:0] == 4'h0)
                DataOut <= {28'b0, key_val_reg};
            else if (Addr[3:0] == 4'h4)
                DataOut <= {31'b0, key_pressed_reg};
            else
                DataOut <= 32'b0;
        end else begin
            DataOut <= 32'b0;
        end
    end
endmodule