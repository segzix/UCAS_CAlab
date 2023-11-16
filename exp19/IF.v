//??????next_pc??inst?????
module IF_stage(
    input wire clk,
    input wire reset,
    input wire ID_allow,
    input wire [32:0] branch_bus,
    
    input wire WB_exception,
    input wire ertn_flush,
    input wire wb_reinst,
    input wire wb_tlbr,
    input wire [31:0] ertn_entry,
    input wire [31:0] ex_entry,
    input wire [31:0] tlbr_entry,
    input wire [31:0] WB_pc,
    
    output wire IF_to_ID_valid,
    output wire [68:0] IF_to_ID_bus,
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
    
    input  wire       ID_br_stall,

    output wire [31:0] next_pc,
    input  wire [31:0] next_pc_true_addr,

    input  wire        to_PreIF_ex_ade,
    input  wire        to_PreIF_ex_tlbr,
    input  wire        to_PreIF_ex_pif,
    input  wire        to_PreIF_ex_ppi
);
    wire        branch_valid;
    wire        branch_judge;//�ۺ�branch_valid��ID_br_stall����??

    assign      branch_judge = branch_valid && ~ID_br_stall;

    wire        pre_IF_exception;
    wire [3:0]  pre_IF_exception_bus;
    reg  [3:0]  pre_IF_exception_bus_r;
    reg  [3:0]  pre_IF_block_exception_bus_r;
    reg  [3:0]  IF_exception_bus_r;

    assign pre_IF_exception_bus = {to_PreIF_ex_ade , to_PreIF_ex_tlbr , to_PreIF_ex_pif , to_PreIF_ex_ppi};
//pre-IF

    wire        preIF_go;
    wire        preIF_to_IF_valid;
    wire        addr_succ;
    wire [31:0] pc_4;
    wire [31:0] branch_pc;

    assign addr_succ = inst_sram_req & inst_sram_addr_ok;
    assign pc_4 = next_pc_r + 3'd4;
    assign next_pc = (WB_exception && !ertn_flush && !wb_reinst && !wb_tlbr) ? ex_entry:
                      wb_reinst ? (WB_pc + 3'd4) :
                      ertn_flush ? ertn_entry :
                      wb_tlbr ? tlbr_entry :
                      branch_judge ? branch_pc : pc_4;
//exp14 reg
    reg [31:0]  next_pc_r;
    reg [31:0]  next_pc_true_addr_r;//�������next_pc_true_addr
    reg         next_pc_has_r;
    always @(posedge clk) begin
        if(reset) begin
            next_pc_r <= IF_pc + 3'd4;
            next_pc_true_addr_r <= IF_pc + 3'd4;
            pre_IF_exception_bus_r <= 4'd0;
        end else if(WB_exception || ertn_flush || branch_judge || addr_succ) begin//�����쳣��ȡָ�ɹ�ȡ��ָ��͸���pc
            next_pc_r <= next_pc;
            next_pc_true_addr_r <= (pre_IF_exception ? (32'h1c000000) : next_pc_true_addr);//�����mmu�쳣����ʹ��true_addr
            pre_IF_exception_bus_r <= pre_IF_exception_bus;//�����mmu�쳣����ʹ��true_addr
        end
    end 

    //next_pc_rֻ�е�����go��ʱ��Ż����ȡָ
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
            pre_IF_block_exception_bus_r <= 4'd0;
        end else if(WB_exception || ertn_flush || branch_judge) begin//�����has_rҲ�൱����valid�ź�
            pre_IF_inst_pc <= 32'd0;
            pre_IF_inst_pc_has_r <= 1'd0;
            pre_IF_block_exception_bus_r <= 4'd0;
        end else if(addr_succ && ~IF_allow) begin
            pre_IF_inst_pc <= next_pc_r;
            pre_IF_inst_pc_has_r <= 1'd1;
            pre_IF_block_exception_bus_r <= pre_IF_exception_bus_r;
        end else if(pre_IF_inst_pc_has_r && IF_allow) begin
            pre_IF_inst_pc <= 32'd0;
            pre_IF_inst_pc_has_r <= 1'd0;
            pre_IF_block_exception_bus_r <= 4'd0;
        end
    end

    assign preIF_go  = addr_succ || pre_IF_inst_pc_has_r;//ֻҪ�ɹ��������˾���??ǰ��
    assign preIF_to_IF_valid = preIF_go;//ע�⣬��������쳣������ת��������������е���valid����Ϊÿ??���ĵ�???����Ȼ����Ϊ������е�??

//IF
    wire [31:0]     get_true_inst;//cancel_count��Ϊ0ʱ��ȡ������ָ��Ĭ��Ϊȫ??
    wire            data_succ;//data�ɹ�ȡ������
    reg  [31:0]     IF_pc;
    reg  [3:0]      cancel_cnt_r;//��¼??Ҫȡ����ָ������
    reg             IF_valid;
    wire            IF_go;
    wire            IF_allow;

    wire [31:0]     IF_inst;

    assign data_succ = inst_sram_data_ok && (cancel_cnt_r == 2'd0);
    assign get_true_inst = {32{!cancel_cnt_r}} & inst_sram_rdata;
    always @(posedge clk) begin
        if(reset) begin
            IF_valid <= 1'd0;
        end else if(WB_exception || ertn_flush || branch_judge) begin
            IF_valid <= 1'd0;
        end else if(IF_allow) begin
            IF_valid <= preIF_to_IF_valid;
        end

        if(reset) begin
            IF_pc <= 32'h1bfffffc;
            IF_exception_bus_r <= 4'd0;
        end else if(preIF_to_IF_valid && IF_allow && pre_IF_inst_pc_has_r) begin
            IF_pc <= pre_IF_inst_pc;
            IF_exception_bus_r <= pre_IF_block_exception_bus_r;
        end else if(preIF_to_IF_valid && IF_allow && !pre_IF_inst_pc_has_r) begin
            IF_pc <= next_pc_r;
            IF_exception_bus_r <= pre_IF_exception_bus_r;
        end
    end

    ////IF
    reg  [1:0]      IF_inst_fifo_addr;
    reg  [31:0]     IF_inst_fifo [1:0];
    reg             IF_inst_fifo_valid [1:0];
    wire            write_fifo;
    wire            read_fifo;
    wire            addr_valid;
    
    wire [31:0]     IF_inst_r;//IF���Ļ���ָ��
    wire            IF_inst_has_r;//IF���Ƿ���ָ���
    
    assign write_fifo = data_succ && (~ID_allow || IF_inst_has_r);
    assign read_fifo = IF_inst_has_r && ID_allow;
     always @(posedge clk) begin
        if(reset) begin
            IF_inst_fifo_valid[0] <= 1'd0;
        end else if(WB_exception || ertn_flush || branch_judge) begin
            IF_inst_fifo_valid[0] <= 1'd0;
        end else if(write_fifo && IF_inst_fifo_addr[1]) begin
            IF_inst_fifo_valid[0] <= 1'd1;
        end else if(!(write_fifo && IF_inst_fifo_valid[1]) && read_fifo && IF_inst_fifo_addr[0]) begin//��fifo�ҵ�??Ϊ�ң�������??��û����������дfifo
            IF_inst_fifo_valid[0] <= 1'd0;
        end
    end
    
    always @(posedge clk) begin
        if(reset) begin
            IF_inst_fifo_valid[1] <= 1'd0;
        end else if(WB_exception || ertn_flush || branch_judge) begin
            IF_inst_fifo_valid[1] <= 1'd0;
        end else if(write_fifo && IF_inst_fifo_addr[0]) begin//��fifo�ҵ�??Ϊ�ң�������??��û����������дfifo
            IF_inst_fifo_valid[1] <= 1'd1;
        end else if(!(write_fifo && IF_inst_fifo_valid[0]) && read_fifo && IF_inst_fifo_addr[1]) begin
            IF_inst_fifo_valid[1] <= 1'd0;
        end
    end
    
    assign addr_valid = ((IF_inst_fifo_addr & {IF_inst_fifo_valid[1],IF_inst_fifo_valid[0]}) != 2'd0);
    always @(posedge clk) begin
        if(reset) begin
            IF_inst_fifo_addr <= 2'd1;
        end else if((write_fifo && !addr_valid) || (read_fifo && addr_valid) ) begin
            IF_inst_fifo_addr <= {IF_inst_fifo_addr[0],IF_inst_fifo_addr[1]};
        end
    end
    
    always @(posedge clk) begin
        if(reset) begin
            IF_inst_fifo[0] <= 32'd0;
        end else if(write_fifo && IF_inst_fifo_addr[1] && !IF_inst_fifo_valid[0]) begin
            IF_inst_fifo[0] <= get_true_inst;
        end else if(write_fifo && IF_inst_fifo_addr[0] &&  IF_inst_fifo_valid[1]) begin
            IF_inst_fifo[0] <= get_true_inst;
        end
    end
    
     always @(posedge clk) begin
        if(reset) begin
            IF_inst_fifo[1] <= 32'd0;
        end else if(write_fifo && IF_inst_fifo_addr[0] && !IF_inst_fifo_valid[1]) begin
            IF_inst_fifo[1] <= get_true_inst;
        end else if(write_fifo && IF_inst_fifo_addr[1] &&  IF_inst_fifo_valid[0]) begin
            IF_inst_fifo[1] <= get_true_inst;
        end
    end
    //дfifo����??��Ϊ�Ҳ�������Ч����Ȼ��������д�����ߵ�??Ϊ�ҵ��Ǳ�����Ч����ô�ҿ϶�Ҳ��Ч�����дҲҪ��������д
    
    assign IF_inst_has_r = IF_inst_fifo_valid[0] || IF_inst_fifo_valid[1];
    assign IF_inst_r     = {32{IF_inst_fifo_addr[0]}} & IF_inst_fifo[0] | 
                           {32{IF_inst_fifo_addr[1]}} & IF_inst_fifo[1] ;
    /////////
    wire [3:0]  add_cancel_cnt;
    wire [3:0]  sub_cancel_cnt;
    wire [3:0]  next_cancel_cnt;
    wire [3:0]  true_cancel_cnt;
    assign add_cancel_cnt   = (addr_succ || pre_IF_inst_pc_has_r) + IF_valid;
    assign sub_cancel_cnt   = inst_sram_data_ok + IF_inst_fifo_valid[0] + IF_inst_fifo_valid[1];
    assign next_cancel_cnt  = cancel_cnt_r + add_cancel_cnt - sub_cancel_cnt;
    assign true_cancel_cnt  = (cancel_cnt_r + add_cancel_cnt < sub_cancel_cnt) ? cancel_cnt_r : next_cancel_cnt;
    always @(posedge clk) begin
        if(reset) begin
            cancel_cnt_r <= 2'd0;
        end else if((WB_exception || ertn_flush || branch_judge))begin//
            cancel_cnt_r <= true_cancel_cnt;
        end else if(!(WB_exception || ertn_flush || branch_judge) && inst_sram_data_ok && cancel_cnt_r != 2'd0) begin
            cancel_cnt_r <= cancel_cnt_r - 2'd1;
        end
    end

    assign IF_go = IF_inst_has_r || data_succ;
    assign IF_allow = ~IF_valid || IF_go && ID_allow;
    assign IF_to_ID_valid = IF_valid && IF_go && ~branch_judge;

    wire   IF_pc_except;
    assign IF_pc_adef = (|IF_pc[1:0]) & IF_valid;
    assign pre_IF_exception = (to_PreIF_ex_ade || to_PreIF_ex_tlbr || to_PreIF_ex_pif || to_PreIF_ex_ppi);
    //�����������mmu�쳣�����������0x1c000000һ���Ϸ���ַ
    
    assign IF_inst = IF_inst_has_r ? IF_inst_r : get_true_inst;//
    assign {branch_valid,branch_pc} = branch_bus;
    assign IF_to_ID_bus = {IF_inst,IF_pc,IF_pc_adef,IF_exception_bus_r};
    
    assign inst_sram_size   = 2'b10;
    assign inst_sram_req    = ~pre_IF_inst_pc_has_r && next_pc_has_r;//next_pc_r����ȡָ����
    assign inst_sram_wr     = 1'd0;
    assign inst_sram_wstrb  = 4'd0;
    assign inst_sram_addr   = next_pc_true_addr_r;
    assign inst_sram_wdata  = 32'd0;
endmodule
