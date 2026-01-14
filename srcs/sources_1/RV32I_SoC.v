`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Design Name: RV32I_SoC with Keypad
// Module Name: RV32I_SoC
// Description: Added Keypad Interface
//////////////////////////////////////////////////////////////////////////////////

module RV32I_SoC(
    input   clk_125mhz, 
    input   btn,    // active high rst when button is pressed
    output [3:0] leds,  

/************** For 7 Seg LED Array (6 HEX)***************/
    output reg [7:0]   seg_data, 
    output reg [5:0]   seg_com,
    
/**********************************************************/
    output uart_tx,
    input uart_rx,
    
        
/**********************************************************/
    output spi_cs,
    output spi_sclk,
    output spi_mosi,
    input spi_miso
    );
    
    wire clk, clk90, clk180;
    reg rst;
    wire [31:0] fetch_addr, data_addr, inst, write_data;
    wire [31:0] read_data_mem, read_data_gpio, read_data_keypad, read_data_uart,read_data_spi; 
    reg [31:0] read_data;  
    wire cs_mem, cs_gpio, cs_keypad,cs_uart, data_we, locked; 
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    reg [15:0] seg_cnt;
    
    
    // Block RAM (Instruction & Data Memory)
    ram_2port_2048x32 iMEM (
        .clka (clk90), 
        .ena (1'b1), 
        .wea (1'b0), 
        .addra (fetch_addr[12:2]),
        .dina (32'b0), 
        .douta (inst), 
        .clkb (clk180), 
        .enb (cs_mem), 
        .web ({4{data_we}}),
        .addrb(data_addr[12:2]), 
        .dinb (write_data), 
        .doutb (read_data_mem)
    );
  
    // PLL for clock generation
    clk_wiz_0 iPLL ( 
        .clk0(clk), 
        .clk90(clk90),
        .clk180(clk180), 
        .reset(btn),        //active high 
        .locked(locked),    //'1' after clock becomes stable
        .clk_in1(clk_125mhz)
    );
   
    // Reset generation
    always @ (posedge clk_125mhz) begin
        rst <= (~locked) | btn; //'1' when clock is not stable or btn is pressed. 
    end       
    
    rv32i_cpu iCPU(
        .clk(clk),  
        .rst(rst),         //active high reset
        .pc(fetch_addr),  
        .inst(inst), 
        .MemWen(data_we), 
        .MemAddr(data_addr), 
        .MemWdata(write_data),  
        .MemRdata(read_data) 
    );
    
    always @* begin
        if (cs_gpio) read_data = read_data_gpio;
        else if (cs_keypad) read_data = read_data_keypad;
        else if (cs_uart) read_data = read_data_uart;
        else if (cs_spi) read_data = read_data_spi;
        else read_data = read_data_mem;
    end
    

    
    // Address Decoder
    Addr_Decoder iDec(
        .addr(data_addr), 
        .cs_mem(cs_mem),
        .cs_gpio(cs_gpio),
        .cs_keypad(cs_keypad),
        .cs_uart(cs_uart), 
        .cs_spi(cs_spi)
    );
    
    // GPIO Module
    GPIO iGPIO(
        .clk(clk), 
        .rst(rst), 
        .CS(cs_gpio),
        .REN(~data_we),
        .WEN(data_we),
        .Addr(data_addr[11:0]),  
        .DataIn(write_data),
        .DataOut(read_data_gpio),
        .HEX0(HEX0), .HEX1(HEX1),        
        .HEX2(HEX2), .HEX3(HEX3),        
        .HEX4(HEX4), .HEX5(HEX5),
        .LEDS(leds)        
    );

    Keypad iKeypad(
        .clk(clk),
        .rst(rst),
        .CS(cs_keypad),
        .Addr(data_addr[11:0]),
        .DataOut(read_data_keypad)
    );
    
    UART iUART(
            .clk(clk),
            .rst(rst),
            .CS(cs_uart),
            .REN(~data_we),
            .WEN(data_we),
            .Addr(data_addr[11:0]),
            .DataIn(write_data),
            .DataOut(read_data_uart),
            .tx(uart_tx), 
            .rx(uart_rx)  
        );
        
    SPI iSPI(
            .clk(clk),
            .rst(rst),
            .CS(cs_spi),
            .REN(~data_we),
            .WEN(data_we),
            .Addr(data_addr[11:0]),
            .DataIn(write_data),
            .DataOut(read_data_spi),
            .spi_cs(spi_cs),
            .spi_sclk(spi_sclk),
            .spi_mosi(spi_mosi),
            .spi_miso(spi_miso)
        );

    // 7-Segment LED multiplexing
    always @ (posedge clk, posedge rst)
    begin  
        if (rst) seg_cnt <= 0; 
        else if (seg_cnt[15] == 1'b1) seg_cnt <= 0; 
        else seg_cnt <= seg_cnt + 1; 
    end

    always @ (posedge clk, posedge rst)
    begin  
        if (rst) seg_com <= 6'b100000;
        else if (seg_cnt[3] == 1'b1) seg_com <= {seg_com[0], seg_com[5:1]};//default: seg_cnt[15]
    end
        
    always @* begin
        case (seg_com)
            6'b000001 : seg_data = {HEX0, 1'b0};           
            6'b000010 : seg_data = {HEX1, 1'b0};
            6'b000100 : seg_data = {HEX2, 1'b0};
            6'b001000 : seg_data = {HEX3, 1'b0};
            6'b010000 : seg_data = {HEX4, 1'b0};
            6'b100000 : seg_data = {HEX5, 1'b0};
            default: seg_data = 8'b0;       
        endcase
    end
            
endmodule