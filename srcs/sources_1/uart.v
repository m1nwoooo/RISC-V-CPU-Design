module UART(
    input clk, rst, CS, REN, WEN,
    input [11:0] Addr,
    input [31:0] DataIn,
    output reg [31:0] DataOut, //For load instruction, I choose register
    output tx, input rx
);

    localparam CLK_DIV = 87; 

    reg [10:0] clk_cnt;
    wire tick = (clk_cnt == CLK_DIV - 1);
    
    always @(posedge clk or posedge rst) begin
        if (rst) clk_cnt <= 0;
        else clk_cnt <= (tick) ? 0 : clk_cnt + 1;
    end


    wire tx_fifo_full, tx_fifo_empty;
    wire tx_fifo_wr_en;      
    reg  tx_fifo_rd_en;      
    wire [7:0] tx_fifo_out;  
    
    reg tx_busy;
    reg [3:0] tx_bit_cnt;
    reg [9:0] tx_shift_reg;
    
    // TX FIFO
    FIFO #(.DATA_WIDTH(8), .ADDR_WIDTH(4)) u_tx_fifo (
        .clk(clk), .rst(rst),
        .wr_en(tx_fifo_wr_en), .din(DataIn[7:0]),
        .rd_en(tx_fifo_rd_en), .dout(tx_fifo_out),
        .full(tx_fifo_full),   .empty(tx_fifo_empty)
    );
    
    assign tx_fifo_wr_en = (CS && WEN && (Addr[11:2] == 10'h0));
    assign tx = (tx_busy) ? tx_shift_reg[0] : 1'b1; 

    // TX FSM
    localparam TX_IDLE = 2'b00;
    localparam TX_LOAD = 2'b01;
    localparam TX_BUSY = 2'b10;
    reg [1:0] tx_state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_bit_cnt <= 0;
            tx_shift_reg <= 10'b1111111111;
            tx_fifo_rd_en <= 0;
            tx_busy <= 0;
        end else begin
            tx_fifo_rd_en <= 0;
            
            case (tx_state)
                TX_IDLE: begin
                    tx_busy <= 0;
                    if (!tx_fifo_empty) begin
                        tx_fifo_rd_en <= 1;
                        tx_state <= TX_LOAD;
                    end
                end
                TX_LOAD: begin
                    tx_shift_reg <= {1'b1, tx_fifo_out, 1'b0};
                    tx_bit_cnt <= 0;
                    tx_busy <= 1;
                    tx_state <= TX_BUSY;
                end
                TX_BUSY: begin
                    if (tick) begin
                        if (tx_bit_cnt < 9) begin
                            tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};
                            tx_bit_cnt <= tx_bit_cnt + 1;
                        end else begin
                            tx_state <= TX_IDLE;
                        end
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end


    wire rx_fifo_full, rx_fifo_empty;
    reg  rx_fifo_wr_en;      
    wire rx_fifo_rd_en;      
    wire [7:0] rx_fifo_out;  
    
    reg rx_sync1, rx_sync2;
    reg [7:0] rx_temp_reg; 
    reg [10:0] rx_cnt;      
    reg [2:0] rx_bit_idx;   

    // RX FSM State
    localparam RX_IDLE  = 2'b00;
    localparam RX_START = 2'b01;
    localparam RX_DATA  = 2'b10;
    localparam RX_STOP  = 2'b11;
    reg [1:0] rx_state;
    
    // RX Status for Debug
    wire rx_busy_flag = (rx_state != RX_IDLE);

    // RX FIFO
    FIFO #(.DATA_WIDTH(8), .ADDR_WIDTH(4)) u_rx_fifo (
        .clk(clk), .rst(rst),
        .wr_en(rx_fifo_wr_en), .din(rx_temp_reg),
        .rd_en(rx_fifo_rd_en), .dout(rx_fifo_out),
        .full(rx_fifo_full),   .empty(rx_fifo_empty)
    );

    assign rx_fifo_rd_en = (CS && REN && (Addr[11:2] == 10'h0));

    // RX Synchronizer
    always @(posedge clk or posedge rst) begin
        if (rst) begin rx_sync1 <= 1; rx_sync2 <= 1; end
        else begin rx_sync1 <= rx; rx_sync2 <= rx_sync1; end
    end

    // RX FSM Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_cnt <= 0;
            rx_bit_idx <= 0;
            rx_temp_reg <= 0;
            rx_fifo_wr_en <= 0;
        end else begin
            rx_fifo_wr_en <= 0; 

            case (rx_state)
                RX_IDLE: begin
                    rx_cnt <= 0;
                    rx_bit_idx <= 0;
                    if (rx_sync2 == 0) begin // Start bit ¡Æ¡§??
                        rx_state <= RX_START;
                    end
                end

                RX_START: begin
                    if (rx_cnt == CLK_DIV / 2) begin // ¨¬?¨¡¢ç?? ?¢´?©¬¨ú?(50%) ???¢®
                        if (rx_sync2 == 0) begin     
                            rx_cnt <= 0;
                            rx_state <= RX_DATA;
                        end else begin
                    
                            rx_state <= RX_IDLE; 
                            rx_cnt <= 0;
                        end
                    end else begin
                        rx_cnt <= rx_cnt + 1;
                    end
                end

                RX_DATA: begin
                    if (rx_cnt == CLK_DIV - 1) begin
                        rx_cnt <= 0;
                        if (rx_bit_idx == 7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 1;
                        end
                    end else begin
                        rx_cnt <= rx_cnt + 1;
                        if (rx_cnt == CLK_DIV / 2) begin
                            rx_temp_reg[rx_bit_idx] <= rx_sync2; // LSB First
                        end
                    end
                end

                RX_STOP: begin
                    if (rx_cnt == CLK_DIV - 1) begin
                        rx_state <= RX_IDLE;
                        rx_cnt <= 0;
                        if (!rx_fifo_full) begin 
                            rx_fifo_wr_en <= 1; 
                        end
                    end else begin
                        rx_cnt <= rx_cnt + 1;
                    end
                end
                
                default: rx_state <= RX_IDLE;
            endcase
        end
    end

   
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            DataOut <= 32'b0;
        end else if (CS && REN) begin
            case (Addr[11:2])
                10'h0: DataOut <= {24'b0, rx_fifo_out};
                10'h1: DataOut <= {29'b0, tx_busy, rx_fifo_empty, tx_fifo_full};
                default: DataOut <= 32'b0;
            endcase
        end else begin
            DataOut <= 32'b0;
        end
    end
    

endmodule