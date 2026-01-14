module FIFO #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4  
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  wr_en, 
    input  wire [DATA_WIDTH-1:0] din,   
    input  wire                  rd_en, 
    output wire [DATA_WIDTH-1:0] dout,  
    output wire                  full,  
    output wire                  empty  
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    
    // ptr
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   cnt;  

    // Write
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= din;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read Logic

    assign #1 dout = mem[rd_ptr];
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_ptr <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end
//Full/Empty
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: cnt <= cnt + 1;
                2'b01: cnt <= cnt - 1; 
                2'b11: cnt <= cnt;     // R/W
            endcase
        end
    end

    assign empty = (cnt == 0);
    assign full  = (cnt == (1 << ADDR_WIDTH));

endmodule