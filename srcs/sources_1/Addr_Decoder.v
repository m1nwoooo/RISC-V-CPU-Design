module Addr_Decoder(
        input [31:0] addr,
        output reg cs_mem,
        output reg cs_gpio,
        output reg cs_keypad,
        output reg cs_uart,
        output reg cs_spi
        );
        
    always @* begin
        if (addr[31:13] == 19'h0) begin // 0x00000000-0x00001FFF
            cs_mem = 1'b1; 
            cs_gpio = 1'b0;
            cs_keypad = 1'b0;
            cs_uart = 1'b0;  
            cs_spi = 1'b0;
        end
        else if (addr[31:12] == 20'hFFFF1) begin // 0xFFFF1000-0xFFFF1FFF (Keypad)
            cs_mem = 1'b0; 
            cs_gpio = 1'b0;
            cs_keypad = 1'b1;
            cs_uart = 1'b0;  
            cs_spi = 1'b0;
        end
        else if (addr[31:12] == 20'hFFFF2) begin // 0xFFFF2000-0xFFFF2FFF (GPIO)
            cs_mem = 1'b0; 
            cs_gpio = 1'b1;
            cs_keypad = 1'b0;
            cs_uart = 1'b0;   
            cs_spi = 1'b0;         
        end
        else if (addr[31:12] == 20'hFFFF3) begin // 0xFFFF3000-0xFFFF3FFF (UART)
            cs_mem = 1'b0; 
            cs_gpio = 1'b0;
            cs_keypad = 1'b0;
            cs_uart = 1'b1;
            cs_spi = 1'b0;
            end
        else if (addr[31:12] == 20'hFFFF4) begin // 0xFFFF4000-0xFFFF4FFF (SPI)
            cs_mem = 1'b0; 
            cs_gpio = 1'b0;
            cs_keypad= 1'b0;
            cs_uart = 1'b0;
            cs_spi = 1'b1;
        end
        else begin
            cs_mem = 1'b0;
            cs_gpio = 1'b0;
            cs_keypad = 1'b0;
            cs_uart = 1'b0;
            cs_spi = 1'b0;
        end
    end
         
endmodule