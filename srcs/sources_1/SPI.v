`timescale 1ns / 1ps

module SPI(
    input clk, rst, CS, REN, WEN,
    input [11:0] Addr,
    input [31:0] DataIn,
    output reg [31:0] DataOut,

    output reg spi_cs,       // Active low
    output reg spi_sclk,      
    output reg spi_mosi,     
    input spi_miso           
);

    // Memory Map:
    // 0x00: Data register
    // 0x04: Status Register 0: busy / 1: tx_done
    // 0x08: Control for start
    
    localparam SPI_CLK_DIV = 8'd10;  // 임의 설정
    
    reg [7:0] tx_data;
    

    reg [7:0] rx_data;
    reg start_tx;
    reg busy;
    reg tx_done;
    
    localparam IDLE  = 2'b00;
    localparam TRANS = 2'b01;
    localparam DONE  = 2'b10;
    
    reg [1:0] state;
    reg [7:0] clk_cnt;
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg sclk_en;
    
    // sclk
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_cnt <= 0;
            spi_sclk <= 0;
        end else begin
            if (sclk_en) begin
                if (clk_cnt == SPI_CLK_DIV - 1) begin
                    clk_cnt <= 0;
                    spi_sclk <= ~spi_sclk;
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end else begin
                clk_cnt <= 0;
                spi_sclk <= 0;
            end
        end
    end
    
    
    //SPI FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            busy <= 0;
            tx_done <= 0;
            spi_cs <= 1;
            spi_mosi <= 0;
            bit_cnt <= 0;
            shift_reg <= 0;
            rx_data <= 0;
            sclk_en <= 0;
        end else begin
            case (state)
                IDLE: begin
                    spi_cs <= 1;
                    sclk_en <= 0;
                    tx_done <= 0;
                    
                    if (start_tx && !busy) begin
                        busy <= 1;
                        shift_reg <= tx_data;
                        bit_cnt <= 0;
                        spi_cs <= 0;  
                        state <= TRANS;
                        sclk_en <= 1;
                    end else begin
                        busy <= 0;
                    end
                end
                
                TRANS: begin
                    if (clk_cnt == 0 && spi_sclk == 0) begin
                        // Rising edge - output data (MSB first)
                        spi_mosi <= shift_reg[7];
                    end
                    
                    if (clk_cnt == 0 && spi_sclk == 1) begin
                        // Falling edge - sample data
                        shift_reg <= {shift_reg[6:0], spi_miso};
                        
                        if (bit_cnt == 7) begin
                            rx_data <= {shift_reg[6:0], spi_miso};
                            state <= DONE;
                            sclk_en <= 0;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end
                
                DONE: begin
                    spi_cs <= 1;  // Deassert CS
                    tx_done <= 1;
                    busy <= 0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    //rx

    always @(*) begin
        DataOut = 32'b0;  //mux
        if (CS && REN) begin
            case (Addr[11:2])
                10'h0: DataOut = {24'b0, rx_data};
                10'h1: DataOut = {30'b0, tx_done, busy};
                default: DataOut = 32'b0;
            endcase
        end
    end
    
        always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_data <= 0;
            start_tx <= 0;
        end else begin
            start_tx <= 0; 
            
            if (CS && WEN) begin
                case (Addr[11:2])
                    10'h0: tx_data <= DataIn[7:0];
                    10'h2: begin
                        start_tx <= DataIn[0];
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule