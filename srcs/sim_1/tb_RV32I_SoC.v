`timescale 1ns / 1ps

module tb_RV32I_SoC();
reg     clk_125mhz, btn; 
wire    [3:0] leds;
wire    [7:0] seg_data;
wire    [5:0] seg_com;
wire    uart_tx;
reg     uart_rx;
wire    spi_cs, spi_sclk, spi_mosi;
reg     spi_miso;

RV32I_SoC DUT (
    .clk_125mhz(clk_125mhz), 
    .btn(btn), 
    .leds(leds), 
    .seg_data(seg_data), 
    .seg_com(seg_com), 
    .uart_tx(uart_tx), 
    .uart_rx(uart_rx),
    .spi_cs(spi_cs),
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso)
); 

initial begin
    clk_125mhz = 1'b0; 
    uart_rx = 1'b1;
    spi_miso = 1'b0;
    btn = 1'b0;
    
    $display("Start Test: Tx = (Rx + 1)\n");
    

    // Reset
    #1000;
    btn = 1'b1;
    //Start Test
    #3000;
    btn = 1'b0;
    
    #20000000;
    $display("Test Finished");
    $stop;
end

// TB Slave
reg [7:0] slave_tx_data;
reg [7:0] slave_rx_data;
reg [7:0] prev_rx_data; //prev value is compared by tx_data now
integer slave_bit_idx;
integer spi_transaction_count;

initial begin
    spi_transaction_count = 0;
    slave_tx_data = 8'h00;
    prev_rx_data = 8'h00;
end

always @(negedge spi_cs) begin
    slave_rx_data = 8'h00;
    slave_bit_idx = 0;
    spi_transaction_count = spi_transaction_count + 1;
    
    $display("[TB] Transaction #%0d: Sending 0x%02X to CPU", 
             spi_transaction_count, slave_tx_data);
end

always @(posedge spi_sclk) begin
    if (!spi_cs) begin
        slave_rx_data = {slave_rx_data[6:0], spi_mosi};// bit shift 지속적으로
        slave_bit_idx = slave_bit_idx + 1;
    end
end

always @(posedge spi_cs) begin //After Transition
    if (spi_transaction_count > 0) begin
        $display("Transaction #%0d: Received 0x%02X from CPU", 
                 spi_transaction_count, slave_rx_data);
        
        if (slave_rx_data == prev_rx_data + 1) begin
            $display("PASS: CPU sent (prev + 1) = 0x%02X\n", slave_rx_data);
        end else begin
            $display("FAIL: Expected 0x%02X but got 0x%02X\n", 
                     prev_rx_data + 1, slave_rx_data);
        end
        
        prev_rx_data = slave_tx_data;
        slave_tx_data = slave_tx_data + 8'h10;//Incremented 0x10
    end
    
    spi_miso = 1'b0;
end


always @(negedge spi_sclk or negedge spi_cs) begin
    if (!spi_cs) begin
        spi_miso = slave_tx_data[7 - slave_bit_idx];
    end
end

always begin
    #4; clk_125mhz = ~clk_125mhz;
end

endmodule