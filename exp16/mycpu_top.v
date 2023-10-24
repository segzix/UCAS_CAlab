module mycpu_top(
    input  wire        clk,
    input  wire        resetn,

    output wire [ 3:0]  arid   ,
    output wire [31:0]  araddr ,
    output wire [ 7:0]  arlen  ,
    output wire [ 2:0]  arsize ,
    output wire [ 1:0]  arburst,
    output wire [ 1:0]  arlock ,
    output wire [ 3:0]  arcache,
    output wire [ 2:0]  arprot ,
    output wire         arvalid,
    input  wire         arready,
                
    input  wire [ 3:0]  rid   ,
    input  wire [31:0]  rdata ,
    input  wire [ 1:0]  rresp ,
    input  wire         rlast ,
    input  wire         rvalid,
    output wire         rready,
               
    output wire [ 3:0]  awid   ,
    output wire [31:0]  awaddr ,
    output wire [ 7:0]  awlen  ,
    output wire [ 2:0]  awsize ,
    output wire [ 1:0]  awburst,
    output wire [ 1:0]  awlock ,
    output wire [ 3:0]  awcache,
    output wire [ 2:0]  awprot ,
    output wire         awvalid,
    input  wire         awready,
    
    output wire [ 3:0]  wid   ,
    output wire [31:0]  wdata ,
    output wire [ 3:0]  wstrb ,
    output wire         wlast ,
    output wire         wvalid,
    input  wire         wready,
    
    input  wire [ 3:0]   bid   ,
    input  wire [ 1:0]   bresp ,
    input  wire         bvalid,
    output wire         bready,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    reg reset;
    always @(posedge clk) reset <= ~resetn;
    wire ID_allow;
    wire EXE_allow;
    wire MEM_allow;
    wire WB_allow;
    wire IF_to_ID_valid;
    wire ID_to_EXE_valid;
    wire EXE_to_MEM_valid;
    wire MEM_to_WB_valid;
    wire [64:0] IF_to_ID_bus;
    wire [250:0] ID_to_EXE_bus;
    wire [165:0] EXE_to_MEM_bus;
    wire [190:0] MEM_to_WB_bus;
    wire [37:0] write_back_bus;
    wire [32:0] branch_bus;
    
    wire [4:0] EXE_dest_bus;
    wire [4:0] MEM_dest_bus;
    wire [4:0] WB_dest_bus;
    wire [31:0] EXE_value_bus;
    wire [31:0] MEM_value_bus;
    wire [31:0] WB_value_bus;
    wire EXE_load_bus;
    wire EXE_res_from_mul_bus;
    
    wire [31:0] WB_pc;
    wire        csr_re;
    wire [13:0] csr_num;
    wire [31:0] csr_rvalue;
    wire        csr_we;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    wire [31:0] ex_entry;
    wire [31:0] ertn_entry;
    wire        has_int;
    wire        ertn_flush;
    wire        MEM_exception;
    wire        WB_exception;
    wire [ 5:0] wb_ecode;
    wire [ 8:0] wb_esubcode;
    wire EXE_csr_re_bus;
    wire MEM_csr_re_bus;
    wire [32:0] WB_vaddr;
    wire ID_br_stall;
    wire MEM_mem_req;
    wire wb_ex;
    //IF

     //inst sram interface
    wire         inst_sram_req;
    wire         inst_sram_wr;
    wire [ 1:0]  inst_sram_size;
    wire [ 3:0]  inst_sram_wstrb;
    wire [31:0]  inst_sram_addr;
    wire [31:0]  inst_sram_wdata;
    wire         inst_sram_addr_ok;
    wire         inst_sram_data_ok;
    wire [31:0]  inst_sram_rdata;
    // data sram interface
    wire         data_sram_req;
    wire         data_sram_wr;
    wire [ 1:0]  data_sram_size;
    wire [ 3:0]  data_sram_wstrb;
    wire [31:0]  data_sram_addr;
    wire [31:0]  data_sram_wdata;
    wire         data_sram_addr_ok;
    wire         data_sram_data_ok;
    wire [31:0]  data_sram_rdata;

    IF_stage IF_stage(
        .clk (clk),
        .reset (reset),
        .ID_allow (ID_allow),
        .branch_bus (branch_bus),
        .IF_to_ID_valid (IF_to_ID_valid),
        .IF_to_ID_bus (IF_to_ID_bus),
        .inst_sram_req(inst_sram_req),
        .inst_sram_wr(inst_sram_wr),
        .inst_sram_size(inst_sram_size),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),
        .inst_sram_rdata(inst_sram_rdata),
        
        .WB_exception (WB_exception),
        .ertn_flush (ertn_flush),
        .ex_entry (ex_entry),
        .ertn_entry (ertn_entry),
        
        .ID_br_stall(ID_br_stall)
    );
    //ID
    ID_stage ID_stage(
        .clk (clk),
        .reset (reset),
        .EXE_allow (EXE_allow),
        .ID_allow (ID_allow),
        .IF_to_ID_valid (IF_to_ID_valid),
        .IF_to_ID_bus (IF_to_ID_bus),
        .ID_to_EXE_valid (ID_to_EXE_valid),
        .ID_to_EXE_bus (ID_to_EXE_bus),
        .branch_bus (branch_bus),
        .write_back_bus (write_back_bus),
        .EXE_dest_bus (EXE_dest_bus),
        .MEM_dest_bus (MEM_dest_bus),
        .WB_dest_bus (WB_dest_bus),
        .EXE_value_bus (EXE_value_bus),
        .MEM_value_bus (MEM_value_bus),
        .WB_value_bus (WB_value_bus),
        .EXE_load_bus (EXE_load_bus),
        .EXE_res_from_mul_bus (EXE_res_from_mul_bus),
        
        .EXE_csr_re_bus (EXE_csr_re_bus),
        .MEM_csr_re_bus (MEM_csr_re_bus),
        .WB_exception (WB_exception | ertn_flush),
        .has_int (has_int),
        
        .ID_br_stall(ID_br_stall),
        .data_sram_data_ok(data_sram_data_ok),
        .MEM_mem_req(MEM_mem_req) 
    ); 
    //EXE
    EXE_stage EXE_stage(
        .clk (clk),
        .reset (reset),
        .MEM_allow (MEM_allow),
        .EXE_allow (EXE_allow),
        .ID_to_EXE_valid (ID_to_EXE_valid),
        .ID_to_EXE_bus (ID_to_EXE_bus),
        .EXE_to_MEM_valid (EXE_to_MEM_valid),
        .EXE_to_MEM_bus (EXE_to_MEM_bus),
        
        .data_sram_req(data_sram_req),
        .data_sram_wr(data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr(data_sram_addr),
        .data_sram_addr_ok(data_sram_addr_ok),
        
        .EXE_dest_bus (EXE_dest_bus),
        .EXE_value_bus (EXE_value_bus),
        .EXE_load_bus (EXE_load_bus),
        .EXE_res_from_mul_bus (EXE_res_from_mul_bus),
        
        .EXE_csr_re_bus (EXE_csr_re_bus),
        .MEM_exception (MEM_exception),
        .WB_exception (WB_exception | ertn_flush)
    );
    //MEM
    MEM_stage MEM_stage(
        .clk (clk),
        .reset (reset),
        .WB_allow (WB_allow),
        .MEM_allow (MEM_allow),
        .EXE_to_MEM_valid (EXE_to_MEM_valid),
        .EXE_to_MEM_bus (EXE_to_MEM_bus),
        .MEM_to_WB_valid (MEM_to_WB_valid),
        .MEM_to_WB_bus (MEM_to_WB_bus),
        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata (data_sram_rdata),
        
        .MEM_dest_bus (MEM_dest_bus),
        .MEM_value_bus (MEM_value_bus),
        .MEM_mem_req(MEM_mem_req),
        
        .MEM_csr_re_bus (MEM_csr_re_bus),
        .MEM_exception (MEM_exception),
        .WB_exception (WB_exception | ertn_flush)
    );
    //WB
    WB_stage WB_stage(
        .clk (clk),
        .reset (reset),
        .WB_allow (WB_allow),
        .MEM_to_WB_valid (MEM_to_WB_valid),
        .MEM_to_WB_bus (MEM_to_WB_bus),
        .write_back_bus (write_back_bus),
        .debug_wb_pc (debug_wb_pc),
        .debug_wb_rf_we (debug_wb_rf_we),
        .debug_wb_rf_wnum (debug_wb_rf_wnum),
        .debug_wb_rf_wdata (debug_wb_rf_wdata),
        .WB_dest_bus (WB_dest_bus),
        .WB_value_bus (WB_value_bus),
        
        .csr_re (csr_re),
        .csr_num (csr_num),
        .csr_rvalue (csr_rvalue),
        .csr_we (csr_we),
        .csr_wmask (csr_wmask ),
        .csr_wvalue (csr_wvalue),
        .ertn_flush (ertn_flush),
        .WB_exception (WB_exception),
        .wb_ecode (wb_ecode),
        .wb_esubcode(wb_esubcode),
        .WB_pc (WB_pc),
        .WB_vaddr (WB_vaddr),
        .wb_ex(wb_ex)
    );
    csr_regfile u_csr(
        .clk (clk),
        .reset (reset),
        .csr_re (csr_re),
        .csr_num (csr_num),
        .csr_rvalue (csr_rvalue),
        .csr_we (csr_we),
        .csr_wmask (csr_wmask),
        .csr_wvalue (csr_wvalue),
        .has_int (has_int),
        .ex_entry (ex_entry),
        .ertn_entry (ertn_entry),
        .ertn_flush (ertn_flush),
        .wb_ex (wb_ex),
        .wb_pc (WB_pc),
        .wb_ecode (wb_ecode),
        .wb_esubcode (wb_esubcode),
        .wb_vaddr (WB_vaddr)
    );

    axi_sram_bridge u_bridge(
    .clk(clk),
    .reset(reset),

    .arid(arid)   ,//
    .araddr(araddr) ,//
    .arlen(arlen)  ,//
    .arsize(arsize) ,//
    .arburst(arburst),//
    .arlock(arlock) ,//
    .arcache(arcache),//
    .arprot(arprot) ,//
    .arvalid(arvalid),//
    .arready(arready),
                
    .rid(rid)   ,
    .rdata(rdata) ,
    .rresp(rresp) ,
    .rlast(rlast) ,
    .rvalid(rvalid),
    .rready(rready),//
               
    .awid(awid)   ,//
    .awaddr(awaddr) ,//
    .awlen(awlen)  ,//
    .awsize(awsize),//
    .awburst(awburst),//
    .awlock(awlock) ,//
    .awcache(awcache),//
    .awprot(awprot) ,//
    .awvalid(awvalid),//
    .awready(awready),
    
    .wid(wid)   ,//
    .wdata(wdata) ,//
    .wstrb(wstrb) ,//
    .wlast(wlast) ,//
    .wvalid(wvalid),//
    .wready(wready),
    
    .bid(bid)   ,
    .bresp(bresp) ,
    .bvalid(bvalid),
    .bready(bready),//
    //axi_master

    //inst sram interface(类sram_slave)
    .inst_sram_req(inst_sram_req),
    .inst_sram_wr(inst_sram_wr),
    .inst_sram_size(inst_sram_size),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),//
    .inst_sram_data_ok(inst_sram_data_ok),//
    .inst_sram_rdata(inst_sram_rdata),//
    // data sram interface(类sram_slave)
    .data_sram_req(data_sram_req),
    .data_sram_wr(data_sram_wr),
    .data_sram_size(data_sram_size),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),//
    .data_sram_data_ok(data_sram_data_ok),//
    .data_sram_rdata(data_sram_rdata)//
);
endmodule
