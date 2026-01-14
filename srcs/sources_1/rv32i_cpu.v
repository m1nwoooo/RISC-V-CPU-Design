`define OP_LUI      7'b0110111
`define OP_AUIPC    7'b0010111
`define OP_JAL      7'b1101111
`define OP_JALR     7'b1100111
`define OP_B        7'b1100011
`define OP_I_LOAD   7'b0000011
`define OP_S        7'b0100011
`define OP_I_ARITH  7'b0010011
`define OP_R        7'b0110011

module rv32i_cpu(
        input   clk, 
        input   rst,
        output reg [31:0]  pc, //program counter (address for instruction)
        input   [31:0]  inst, //instruction from memory
        output  MemWen, 	
        output  [31:0]  MemAddr, 
        output  [31:0]  MemWdata, 
        input   [31:0]  MemRdata 
    );

    wire [6:0] opcode; 
    wire [4:0] rs1, rs2, rd;
    wire [31:0] rs1_data, rs2_data, rd_data;     
    wire [6:0] funct7; 
    wire [2:0] funct3;

    reg [31:0] alusrc1, alusrc2;    
    wire [31:0] aluout; 
    reg [4:0] alucontrol;   
    reg alusrc, regwrite, lui, memwrite;
    
    // Immediate values
    reg [31:0] imm_i, imm_s, imm_u, imm_b, imm_j;
    
    // Branch/Jump control
    reg branch_taken;
    reg [31:0] next_pc;
    reg [31:0] branch_target;
    reg is_jal, is_jalr;

    wire Nflag, Zflag, Cflag, Vflag; 


// Program Counter with branch/jump support
    always @ (posedge clk, posedge rst)
    begin
        if (rst)
            pc <= 0; 
        else
            pc <= next_pc;// Default: pc <= pc + 4;
    end
    
    // pc ¡Æ???
    always @(*) begin
        if (is_jal) begin
            // JAL
            // RISC-V¢¥? ¨¡?????¡Æ? ???? PC ¡¾??¨ª?¢¬¡¤? ¢¯?????¢¥?(not ??¢¥???¨ù?)
            next_pc = pc + imm_j;
        end
        else if (is_jalr) begin
            // JALR: PC = (rs1 + imm_i) & ~1
            // rv32i¢¥? LSB¡Æ¢® 0
            next_pc = (rs1_data + imm_i) & 32'hFFFFFFFE;
        end
        else if (branch_taken) begin
            // Branch: PC = PC + imm_b
            next_pc = pc + imm_b;
        end
        else begin
            // Default: PC + 4
            next_pc = pc + 4;
        end
    end
           
    // register file
    regfile regfile_inst( 
        .clk(clk), 
        .we(regwrite),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .rd_data(rd_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );  
  

    assign rs1 = inst[19:15]; 
    assign rs2 = inst[24:20];
    assign rd = inst[11:7];
  
    assign opcode = inst[6:0];
    assign funct7 = inst[31:25];
    assign funct3 = inst[14:12];
    
    // immediate ¡Æ¨£, 32bit sign-extended
    always @(*) begin
        // I-type immediate (ADDI, JALR, LOAD)
        imm_i = {{20{inst[31]}}, inst[31:20]};
        
        // S-type immediate (STORE)
        imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
        
        // B-type immediate (BRANCH)
        imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
        
        // U-type immediate (LUI, AUIPC)
        imm_u = {inst[31:12], 12'b0};//MemRdata[11:0]
        
        // J-type immediate (JAL)
        imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
    end
    
    // Branch condition
    always @(*) begin
        branch_taken = 0;
        if (opcode == `OP_B) begin
            case(funct3)
                3'b000: branch_taken = Zflag;           // BEQ (rs1 == rs2)
                3'b001: branch_taken = ~Zflag;          // BNE (rs1 != rs2)
                3'b100: branch_taken = Nflag ^ Vflag;   // BLT (rs1 < rs2, signed) ¢¯?©ö???¡¤?¢¯?(V) ¡Æ?¡¤?
                3'b101: branch_taken = ~(Nflag ^ Vflag); // BGE (rs1 >= rs2, signed)
                3'b110: branch_taken = ~Cflag;          // BLTU (rs1 < rs2, unsigned)
                3'b111: branch_taken = Cflag;           // BGEU (rs1 >= rs2, unsigned)
                default: branch_taken = 0;
            endcase
        end
    end
     
    //generate constrol signal for alu

    //generate various control signals according to opcode

    always @(*) begin
        // Default values
        alusrc = 0;
        regwrite = 0;
        lui = 0;
        memwrite = 0;
        alucontrol = 5'b00000;  // ADD
        is_jal = 0;
        is_jalr = 0;
        
        case(opcode)
            `OP_I_ARITH: begin  // ADDI, SLTI, XORI, ORI, ANDI, SLLI, SRLI, SRAI
                alusrc = 1;      // Use immediate
                regwrite = 1;
                case(funct3)
                    3'b000: alucontrol = 5'b00000;  // ADDI
                    3'b010: alucontrol = 5'b00011;  // SLTI
                    3'b011: alucontrol = 5'b00100;  // SLTIU
                    3'b100: alucontrol = 5'b00101;  // XORI
                    3'b110: alucontrol = 5'b01000;  // ORI
                    3'b111: alucontrol = 5'b01001;  // ANDI
                    3'b001: alucontrol = 5'b00010;  // SLLI
                    3'b101: begin
                        if (funct7[5])
                            alucontrol = 5'b00111;  // SRAI
                        else
                            alucontrol = 5'b00110;  // SRLI
                    end
                    default: alucontrol = 5'b00000;
                endcase
            end
            
            `OP_LUI: begin  // LUI
                alusrc = 1;
                regwrite = 1;
                lui = 1;
                alucontrol = 5'b00000;  // ADD (0 + immediate)
            end
            
            `OP_AUIPC: begin  // AUIPC
                alusrc = 1;
                regwrite = 1;
                alucontrol = 5'b00000;  // ADD (pc + immediate)
            end
            
            `OP_JAL: begin  // JAL
                regwrite = 1;
                is_jal = 1; // no need alu operation(?¡× ¡¤??¡À¢¯¢®¨ù¡© ?©ø¢¬¢ç)
            end
            
            `OP_JALR: begin  // JALR
                alusrc = 1;
                regwrite = 1;
                is_jalr = 1;
                //alucontrol = 5'b00000;  // no need alu operation(?¡× ¡¤??¡À¢¯¢®¨ù¡© ?©ø¢¬¢ç)
            end
            
            `OP_B: begin  // Branch instructions
                alusrc = 0;      // Use rs2 for comparison
                alucontrol = 5'b00001;  // SUB for comparison
            end
            
            `OP_I_LOAD: begin  // LW, LH, LB, LHU, LBU
                alusrc = 1;      // Use immediate for address
                regwrite = 1;
                alucontrol = 5'b00000;  // ADD
            end
            
            `OP_S: begin  // SW, SH, SB
                alusrc = 1;      // Use immediate for address calculation
                memwrite = 1;
                alucontrol = 5'b00000;  // ADD
            end
            
            `OP_R: begin  // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
                alusrc = 0;      // Use rs2
                regwrite = 1;
                case(funct3)
                    3'b000: begin
                        if (funct7[5])
                            alucontrol = 5'b00001;  // SUB
                        else
                            alucontrol = 5'b00000;  // ADD
                    end
                    3'b001: alucontrol = 5'b00010;  // SLL
                    3'b010: alucontrol = 5'b00011;  // SLT
                    3'b011: alucontrol = 5'b00100;  // SLTU
                    3'b100: alucontrol = 5'b00101;  // XOR
                    3'b101: begin
                        if (funct7[5])
                            alucontrol = 5'b00111;  // SRA
                        else
                            alucontrol = 5'b00110;  // SRL
                    end
                    3'b110: alucontrol = 5'b01000;  // OR
                    3'b111: alucontrol = 5'b01001;  // AND
                    default: alucontrol = 5'b00000;
                endcase
            end
            
            default: begin
                alusrc = 0;
                regwrite = 0;
                lui = 0;
                memwrite = 0;
                alucontrol = 5'b00000;
                is_jal = 0;
                is_jalr = 0;
            end
        endcase
    end
    
    // ALU source selection
    always @(*) begin
        // First operand
        if (opcode == `OP_AUIPC)
            alusrc1 = pc;
        else if (lui)
            alusrc1 = 32'd0;
        else
            alusrc1 = rs1_data;
            
        // Second operand
        if (alusrc) begin
            if (opcode == `OP_LUI || opcode == `OP_AUIPC)
                alusrc2 = imm_u;
            else if (opcode == `OP_S)
                alusrc2 = imm_s;
            else
                alusrc2 = imm_i;
        end else begin
            alusrc2 = rs2_data;
        end
    end
    
    // ALU instantiation        
    alu alu_inst(
          .a(alusrc1), 
          .b(alusrc2),
          .control(alucontrol),
          .result(aluout),
          .N(Nflag),
          .Z(Zflag),
          .C(Cflag),
          .V(Vflag)
    );   
    // Stores
        reg [31:0] store_data;
        
        always @(*) begin
            store_data = 32'h0;
            if (opcode == `OP_S) begin
                case(funct3)
                    3'b000: begin // SB 
                        case(aluout[1:0])
                            2'b00: store_data = {24'h0, rs2_data[7:0]};
                            2'b01: store_data = {16'h0, rs2_data[7:0], 8'h0};
                            2'b10: store_data = {8'h0, rs2_data[7:0], 16'h0};
                            2'b11: store_data = {rs2_data[7:0], 24'h0};
                        endcase
                    end
                    3'b001: begin // SH
                        if (aluout[1] == 0)
                            store_data = {16'h0, rs2_data[15:0]};
                        else
                            store_data = {rs2_data[15:0], 16'h0};
                    end
                    3'b010: store_data = rs2_data; // SW 
                    default: store_data = 32'h0;
                endcase
            end
        end
        
        assign MemWen = memwrite;
        assign MemAddr = aluout;
        assign MemWdata = store_data;
        
        // WB
        reg [31:0] load_data;//Timing problem now => Solved by  Uart Dout reg
        
        always @(*) begin
            load_data = 32'h0;
            if (opcode == `OP_I_LOAD) begin
                case(funct3)
                    3'b000: begin // LB
                        case(aluout[1:0])
                            2'b00: load_data = {{24{MemRdata[7]}}, MemRdata[7:0]};
                            2'b01: load_data = {{24{MemRdata[15]}}, MemRdata[15:8]};
                            2'b10: load_data = {{24{MemRdata[23]}}, MemRdata[23:16]};
                            2'b11: load_data = {{24{MemRdata[31]}}, MemRdata[31:24]};
                        endcase
                    end
                    3'b001: begin // LH
                        if (aluout[1] == 0)
                            load_data = {{16{MemRdata[15]}}, MemRdata[15:0]};
                        else
                            load_data = {{16{MemRdata[31]}}, MemRdata[31:16]};
                    end
                    3'b010: load_data = MemRdata; // LW
                    3'b100: begin // LBU
                        case(aluout[1:0])
                            2'b00: load_data = {24'h0, MemRdata[7:0]};
                            2'b01: load_data = {24'h0, MemRdata[15:8]};
                            2'b10: load_data = {24'h0, MemRdata[23:16]};
                            2'b11: load_data = {24'h0, MemRdata[31:24]};
                        endcase
                    end
                    3'b101: begin // LHU
                        if (aluout[1] == 0)
                            load_data = {16'h0, MemRdata[15:0]};
                        else
                            load_data = {16'h0, MemRdata[31:16]};
                    end
                    default: load_data = 32'h0;
                endcase
            end
        end
        
        assign rd_data = (is_jal || is_jalr) ? (pc + 4) :      // Return address
                         (opcode == `OP_I_LOAD) ? load_data :   // Load from memory
                         aluout;                                 // ALU result
   
endmodule