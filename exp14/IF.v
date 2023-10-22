//设置了next_pc与inst的缓存
module IF_stage(
    input wire clk,
    input wire reset,
    input wire ID_allow,
    input wire [32:0] branch_bus,
    
    input wire WB_exception,
    input wire ertn_flush,
    input wire [31:0] ertn_entry,
    input wire [31:0] ex_entry,
    
    output wire IF_to_ID_valid,
    output wire [64:0] IF_to_ID_bus,
    /**
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata
    **/
    output wire       inst_sram_req,
    output wire       inst_sram_wr,
    output wire [1:0] inst_sram_size,
    output wire [3:0] inst_sram_wstrb,
    output wire [31:0]inst_sram_addr,
    output wire [31:0]inst_sram_wdata,
    input  wire       inst_sram_addr_ok,
    input  wire       inst_sram_data_ok,
    input  wire [31:0]inst_sram_rdata,
    
    input  wire       ID_br_stall
);
    wire        branch_valid;
    wire        branch_judge;//当br_stall拉低，且branch_valid拉高时，判断为真正的有效分支跳转信号；此时branch_judge拉高

    assign      branch_judge = branch_valid && ~ID_br_stall;


//pre-IF

    wire        preIF_go;
    wire        preIF_to_IF_valid;
    wire        addr_succ;
    wire [31:0] pc_4;
    wire [31:0] branch_pc;
    wire [31:0] next_pc;

    assign addr_succ = inst_sram_req & inst_sram_addr_ok;
    assign pc_4 = next_pc_r + 3'd4;
    assign next_pc = (WB_exception && !ertn_flush) ? ex_entry:
                      ertn_flush ? ertn_entry:
                      branch_judge ? branch_pc : pc_4;
//exp14 reg
    reg [31:0]  next_pc_r;
    reg         next_pc_has_r;
    always @(posedge clk) begin
        if(reset) begin
            next_pc_r <= IF_pc + 3'd4;
        end else if(WB_exception || ertn_flush || branch_judge || addr_succ) begin//注意这里只需要在地址成功握手那一拍更新，后面不用管了
            next_pc_r <= next_pc;
        end
    end   
    always @(posedge clk) begin
        if(reset) begin
            next_pc_has_r <= 1'd0;
        end else begin
            next_pc_has_r <= 1'd1;
        end
    end   

    reg [31:0]  pre_IF_inst_pc;
    reg         pre_IF_inst_pc_has_r;

    always @(posedge clk) begin
        if(reset) begin
            pre_IF_inst_pc <= 32'd0;
            pre_IF_inst_pc_has_r <= 1'd0;
        end else if(addr_succ && ~IF_allow) begin
            pre_IF_inst_pc <= next_pc_r;
            pre_IF_inst_pc_has_r <= 1'd1;
        end else if(pre_IF_inst_pc_has_r && IF_allow) begin
            pre_IF_inst_pc <= 32'd0;
            pre_IF_inst_pc_has_r <= 1'd0;
        end
    end

    assign preIF_go  = addr_succ || pre_IF_inst_pc_has_r || (WB_exception || ertn_flush || branch_judge);//握手成功或pc缓存有数据
    assign preIF_to_IF_valid = preIF_go && ~(WB_exception || ertn_flush || branch_judge);//只要不跳转或异常就有效

//IF
    wire [31:0]     get_true_inst;//与cancel_count与，记录真正得到的指令
    wire            data_succ;//data握手信号
    reg  [31:0]     IF_pc;
    reg  [1:0]      cancel_cnt_r;//计数器，记录取消几条指令
    reg             IF_valid;
    wire            IF_go;
    wire            IF_allow;

    wire [31:0]     IF_inst;

    assign data_succ = inst_sram_data_ok && (cancel_cnt_r == 2'd0);
    assign get_true_inst = {32{!cancel_cnt_r}} & inst_sram_rdata;
    always @(posedge clk) begin
        if(reset) begin
            IF_valid <= 1'd0;
        end else if(IF_allow) begin
            IF_valid <= preIF_to_IF_valid;
        end
        if(reset) begin
            IF_pc <= 32'h1bfffffc;
        end else if(preIF_go && IF_allow && pre_IF_inst_pc_has_r) begin
            IF_pc <= pre_IF_inst_pc;
        end else if(preIF_go && IF_allow && !pre_IF_inst_pc_has_r) begin
            IF_pc <= next_pc_r;
        end
    end
    ////IF第一级缓存寄存器
    reg  [1:0]      IF_inst_fifo_addr;
    reg  [31:0]     IF_inst_fifo [1:0];
    reg             IF_inst_fifo_valid [1:0];
    wire            write_fifo;
    wire            read_fifo;
    wire            addr_valid;
    
    wire [31:0]     IF_inst_r;//IF级指令缓存
    wire            IF_inst_has_r;//IF级指令缓存是否有效
    
    assign write_fifo = data_succ && (~ID_allow || IF_inst_has_r);
    assign read_fifo = IF_inst_has_r && ID_allow;
     always @(posedge clk) begin
        if(reset) begin
            IF_inst_fifo_valid[0] <= 1'd0;
        end else if(write_fifo && IF_inst_fifo_addr[1]) begin
            IF_inst_fifo_valid[0] <= 1'd1;
        end else if(!(write_fifo && IF_inst_fifo_valid[1]) && read_fifo && IF_inst_fifo_addr[0]) begin//需要考虑这个时候写fifo，并且必须要写到这个寄存器里面，因为另一个是有效的
            IF_inst_fifo_valid[0] <= 1'd0;
        end
    end
    
    always @(posedge clk) begin
        if(reset) begin
            IF_inst_fifo_valid[1] <= 1'd0;
        end else if(write_fifo && IF_inst_fifo_addr[0]) begin//成功拿到数据并且不让走，而且当前是往此处写数据，则必然有效；假设队头始终不能写数据，写完之后队头指向谁再定
            IF_inst_fifo_valid[1] <= 1'd1;
        end else if(!(write_fifo && IF_inst_fifo_valid[0]) && read_fifo && IF_inst_fifo_addr[1]) begin
            IF_inst_fifo_valid[1] <= 1'd0;
        end
    end
    
    assign addr_valid = ((IF_inst_fifo_addr & {IF_inst_fifo_valid[1],IF_inst_fifo_valid[0]}) != 2'd0);
    always @(posedge clk) begin
        if(reset) begin
            IF_inst_fifo_addr <= 2'd1;
        end else if((write_fifo && !addr_valid) || (read_fifo && addr_valid) ) begin//(写fifo&&本位无效)||(放fifo&&本位有效）
            IF_inst_fifo_addr <= {IF_inst_fifo_addr[0],IF_inst_fifo_addr[1]};
        end
    end
    
    always @(posedge clk) begin
        if(reset) begin
            IF_inst_fifo[0] <= 32'd0;
        end else if(write_fifo && IF_inst_fifo_addr[1] && !IF_inst_fifo_valid[0]) begin//成功拿到数据并且不让走，而且当前是往此处写数据，则必然有效；假设队头始终不能写数据，写完之后队头指向谁再定
            IF_inst_fifo[0] <= get_true_inst;
        end else if(write_fifo && IF_inst_fifo_addr[0] &&  IF_inst_fifo_valid[1]) begin
            IF_inst_fifo[0] <= get_true_inst;
        end
    end
    
     always @(posedge clk) begin
        if(reset) begin
            IF_inst_fifo[1] <= 32'd0;
        end else if(write_fifo && IF_inst_fifo_addr[0] && !IF_inst_fifo_valid[1]) begin//成功拿到数据并且不让走，而且当前是往此处写数据，则必然有效；假设队头始终不能写数据，写完之后队头指向谁再定
            IF_inst_fifo[1] <= get_true_inst;//必须要注意前提是我这里是无效的，不让将会覆盖
        end else if(write_fifo && IF_inst_fifo_addr[1] &&  IF_inst_fifo_valid[0]) begin
            IF_inst_fifo[1] <= get_true_inst;
        end
    end
    //就两点，指向别人，要往这里写，必须要求自己当前不有效；指向自己，要往这里写，必须要求别人有效（导致装不下）
    
    assign IF_inst_has_r = IF_inst_fifo_valid[0] || IF_inst_fifo_valid[1];
    assign IF_inst_r     = {32{IF_inst_fifo_addr[0]}} & IF_inst_fifo[0] | 
                           {32{IF_inst_fifo_addr[1]}} & IF_inst_fifo[1] ;
    /////////
    
    always @(posedge clk) begin
        if(reset) begin
            cancel_cnt_r <= 2'd0;
        end else if((WB_exception | ertn_flush | branch_judge) && (addr_succ || pre_IF_inst_pc_has_r) && (~(inst_sram_data_ok ||IF_inst_has_r) && IF_valid))begin//
            cancel_cnt_r <= cancel_cnt_r + 2'd2;
        end else if((WB_exception | ertn_flush | branch_judge) && (~(inst_sram_data_ok ||IF_inst_has_r) && IF_valid))begin
            cancel_cnt_r <= cancel_cnt_r + 2'd1;
        end else if((WB_exception | ertn_flush | branch_judge) && (addr_succ || pre_IF_inst_pc_has_r)) begin
            cancel_cnt_r <= cancel_cnt_r + 2'd1;
        end else if(inst_sram_data_ok && cancel_cnt_r != 2'd0) begin
            cancel_cnt_r <= cancel_cnt_r - 2'd1;
        end
    end

    assign IF_go = ((IF_inst_has_r || data_succ) && (cancel_cnt_r == 2'd0)) || (branch_judge || ertn_flush || WB_exception);
    //能走的条件：已经取到数据或者当前数据握上手；当前渠道的指令并没有被取消；出现跳转或者异常
    assign IF_allow = ~IF_valid || IF_go && ID_allow || (branch_judge || ertn_flush || WB_exception);
    //assign IF_to_ID_valid = IF_valid && IF_go && ~branch_judge;
    assign IF_to_ID_valid = IF_valid && IF_go && ~(branch_judge || ertn_flush || WB_exception);
    
    
    wire   IF_pc_except;
    assign IF_pc_adef = (|IF_pc[1:0]) & IF_valid;
    
    assign IF_inst = IF_inst_has_r ? IF_inst_r : get_true_inst;//
    assign {branch_valid,branch_pc} = branch_bus;
    assign IF_to_ID_bus = {IF_inst,IF_pc,IF_pc_adef};
    
    assign inst_sram_req    = ~pre_IF_inst_pc_has_r && ~reset && next_pc_has_r;//next_pc_r有效才可以发
    assign inst_sram_wr     = 1'd0;
    assign inst_sram_wstrb  = 4'd0;
    assign inst_sram_addr   = next_pc_r;
    assign inst_sram_wdata  = 32'd0;
endmodule
