`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/09 21:50:37
// Design Name: 
// Module Name: csr_regfile
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module csr_regfile(
    input  wire          clk       ,
    input  wire          reset     ,
    // ���˿�
    input  wire          csr_re    ,
    input  wire [13:0]   csr_num   ,
    output wire [31:0]   csr_rvalue,
    // д�˿�
    input  wire          csr_we    ,
    input  wire [31:0]   csr_wmask ,
    input  wire [31:0]   csr_wvalue,
    // ��Ӳ����·�����Ľӿ��ź�
    output wire [31:0]   ex_entry  , //�쳣��ڵ�ַ
    output wire [31:0]   ertn_entry, //������ڵ�ַ
    output wire          has_int   , //�ж���Ч�ź�
    input  wire          ertn_flush, //ertnָ��ִ����Ч�ź�
    input  wire          wb_ex     , //�쳣�������ź�
    input  wire [ 5:0]   wb_ecode  , //�쳣����
    input  wire [ 8:0]   wb_esubcode,//�쳣���͸�����
    input  wire [31:0]   wb_vaddr   ,//�ô��ַ
    input  wire [31:0]   wb_pc       //д�صķ��ص�ַ
);
    wire [ 7: 0] hw_int_in;
    wire         ipi_int_in;
    //��ǰģʽ��Ϣ
    wire [31: 0] csr_crmd_data;
    reg  [ 1: 0] csr_crmd_plv;      
    reg          csr_crmd_ie;
    reg          csr_crmd_da;
    reg          csr_crmd_pg;
    reg  [ 6: 5] csr_crmd_datf;
    reg  [ 8: 7] csr_crmd_datm;
    //����ǰģʽ��Ϣ
    wire [31: 0] csr_prmd_data;
    reg  [ 1: 0] csr_prmd_pplv;     //CRMD��PLV���ֵ
    reg          csr_prmd_pie;      //CRMD��IE���ֵ
    // �������
    wire [31: 0] csr_ecfg_data;     
    reg  [12: 0] csr_ecfg_lie;      
    // ����״̬
    wire [31: 0] csr_estat_data;    
    reg  [12: 0] csr_estat_is;      //�����жϵ�״̬λ
    reg  [ 5: 0] csr_estat_ecode;   
    reg  [ 8: 0] csr_estat_esubcode;
    // ���ⷵ�ص�ַERA
    reg  [31: 0] csr_era_data;  
    // ������ڵ�ַeentry
    wire [31: 0] csr_eentry_data;
    reg  [25: 0] csr_eentry_va;     //�����ж���ڸ�λ��ַ
    //���������
    reg  [31: 0] csr_save0_data;
    reg  [31: 0] csr_save1_data;
    reg  [31: 0] csr_save2_data;
    reg  [31: 0] csr_save3_data;
    //�������ַ
    wire         wb_ex_addr_err;
    reg  [31: 0] csr_badv_vaddr;
    wire [31: 0] csr_badv_data;
    //��ʱ����� 
    wire [31: 0] csr_tid_data;
    reg  [31: 0] csr_tid_tid;
    //��ʱ������
    wire [31: 0] csr_tcfg_data;
    reg          csr_tcfg_en;
    reg          csr_tcfg_periodic;
    reg  [29: 0] csr_tcfg_initval;
    wire [31: 0] tcfg_next_value;
    //��ʱ����ֵ
    wire [31: 0] csr_tval_data;
    reg  [31: 0] timer_cnt;
    //��ʱ���ж����
    wire [31: 0] csr_ticlr_data;
    assign has_int = (|(csr_estat_is[11:0] & csr_ecfg_lie[11:0])) & csr_crmd_ie;
    assign ex_entry = csr_eentry_data;
    assign ertn_entry = csr_era_data;
    //CRMD  PLV��IE
    always @(posedge clk) begin
        if (reset) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end
        else if (wb_ex) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end
        else if (ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie  <= csr_prmd_pie;
        end
        else if (csr_we && csr_num == 14'h00) begin
            csr_crmd_plv <= csr_wmask[1:0] & csr_wvalue[1:0]
                          | ~csr_wmask[1:0] & csr_crmd_plv;
            csr_crmd_ie  <= csr_wmask[2] & csr_wvalue[2]
                          | ~csr_wmask[2] & csr_crmd_ie;
        end
    end
    //CRMD  DA��PG��DATF��DATM
    always @(posedge clk) begin
        if(reset) begin
            csr_crmd_da   <= 1'b1;
            csr_crmd_pg   <= 1'b0;
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end
        else if(csr_we &&  wb_ecode == 6'h3f) begin
            csr_crmd_da   <= 1'b1;
            csr_crmd_pg   <= 1'b1;
        end
        else if (csr_we && csr_estat_ecode == 6'h3f) begin
            csr_crmd_da   <= 1'b0;
            csr_crmd_pg   <= 1'b1;
            csr_crmd_datf <= 2'b01;
            csr_crmd_datm <= 2'b01;            
        end
    end

    //PRMD  PPLV��PIE
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end
        else if (csr_we && csr_num == 14'h01) begin
            csr_prmd_pplv <=  csr_wmask[1:0] & csr_wvalue[1:0]
                           | ~csr_wmask[1:0] & csr_prmd_pplv;
            csr_prmd_pie  <=  csr_wmask[2] & csr_wvalue[2]
                           | ~csr_wmask[2] & csr_prmd_pie;
        end
    end

    //ECFG LIE
    always @(posedge clk) begin
        if(reset)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we && csr_num == 14'h04)
            csr_ecfg_lie <= csr_wmask[12:0] & csr_wvalue[12:0]
                        |  ~csr_wmask[12:0] & csr_ecfg_lie;
    end
    //ESTAT IS
    assign hw_int_in = 8'b0;
    assign ipi_int_in= 1'b0;
    always @(posedge clk) begin
        if (reset) begin
            csr_estat_is[1:0] <= 2'b0;
        end
        else if (csr_we && (csr_num == 14'h05)) begin
            csr_estat_is[1:0] <= ( csr_wmask[1:0] & csr_wvalue[1:0])
                               | (~csr_wmask[1:0] & csr_estat_is[1:0]          );
        end

        csr_estat_is[9:2] <= hw_int_in[7:0];
        csr_estat_is[10] <= 1'b0;

        if (timer_cnt[31:0] == 32'b0) begin
            csr_estat_is[11] <= 1'b1;
        end
        else if (csr_we && csr_num == 14'h44 && csr_wmask[0] 
                && csr_wvalue[0]) 
            csr_estat_is[11] <= 1'b0;
        csr_estat_is[12] <= ipi_int_in;
    end    
    //ESTAT    Ecode��EsubCode�������쳣ʱ��д�쳣�����ʹ��ţ���ȷ�쳣����д�ؼ����д���
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode    <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end
    //ERA  PC����λ��д�ؼ�ָ����쳣ʱ����Ҫ��¼�� ERA �Ĵ����� PC ���ǵ�ǰд�ؼ��� PC
    always @(posedge clk) begin
        if(wb_ex)
            csr_era_data <= wb_pc;
        else if (csr_we && csr_num == 14'h06) 
            csr_era_data <= csr_wmask[31:0] & csr_wvalue[31:0]
                        | ~csr_wmask[31:0] & csr_era_data;
    end
    //EENTRY
    always @(posedge clk) begin
        if (csr_we && (csr_num == 14'h0c))
            csr_eentry_va <=   csr_wmask[31:6] & csr_wvalue[31:6]
                            | ~csr_wmask[31:6] & csr_eentry_va ;
    end
    //SAVE
    always @(posedge clk) begin
        if (csr_we && csr_num == 14'h30) 
            csr_save0_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save0_data;
        if (csr_we && (csr_num == 14'h31)) 
            csr_save1_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save1_data;
        if (csr_we && (csr_num == 14'h32)) 
            csr_save2_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save2_data;
        if (csr_we && (csr_num == 14'h33)) 
            csr_save3_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save3_data;
    end
    //BADV VAddr��load store��ִ�м����ô漶��д�ؼ��������ַͨ·����������һ��vaddr��
    assign wb_ex_addr_err = wb_ecode == 6'h09 || wb_ecode == 6'h08; 
    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err) begin
            csr_badv_vaddr <= (wb_ecode == 6'h08 && wb_esubcode == 9'd0) ? wb_pc:wb_vaddr;
        end
    end
    //TID
    always @(posedge clk) begin
        if (reset) begin
            csr_tid_tid <= 32'b0;
        end
        else if (csr_we && csr_num == 14'h40) begin
            csr_tid_tid <= csr_wmask[31:0] & csr_wvalue[31:0]
                        | ~csr_wmask[31:0] & csr_tid_tid;
        end
    end
    //TCFG  EN��Periodic��InitVal
    always @(posedge clk) begin
        if (reset) 
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num == 14'h41) begin
            csr_tcfg_en <= csr_wmask[0] & csr_wvalue[0]
                        | ~csr_wmask[0] & csr_tcfg_en;
        end
        if (csr_we && csr_num == 14'h41) begin
            csr_tcfg_periodic <= csr_wmask[1] & csr_wvalue[1]
                              | ~csr_wmask[1] & csr_tcfg_periodic;
            csr_tcfg_initval  <= csr_wmask[31:2] & csr_wvalue[31:2]
                              | ~csr_wmask[31:2] & csr_tcfg_initval;
        end
    end

    //  TVAL TimeVal�����ؼ�ʱ����ֵ
    assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                           |~csr_wmask[31:0] & csr_tcfg_data;
    always @(posedge clk) begin
        if (reset) begin
            timer_cnt <= 32'hffffffff;
        end
        else if (csr_we && csr_num == 14'h41 && tcfg_next_value[0]) begin
            timer_cnt <= {tcfg_next_value[31:2], 2'b0};
        end
        else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin //��ʱ���Ƿ������Ե�������� 0-1=ff..ff,��ôֹͣ����
            if (timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic) begin
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            end
            else begin
                timer_cnt <= timer_cnt - 1'b1;
            end
        end
    end

    //TICLRCLR
    wire csr_ticlr_clr;
    assign csr_ticlr_clr = 1'b0;
    
    assign csr_crmd_data  = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, 
                            csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    assign csr_prmd_data  = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    assign csr_ecfg_data  = {19'b0, csr_ecfg_lie[12:11], 1'd0, csr_ecfg_lie[9:0]};
    assign csr_estat_data = { 1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    assign csr_eentry_data= {csr_eentry_va, 6'b0};
    assign csr_badv_data  = csr_badv_vaddr;
    assign csr_tid_data   = csr_tid_tid;
    assign csr_tcfg_data  = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    assign csr_tval_data  = timer_cnt;
    assign csr_ticlr_data = {31'b0, csr_ticlr_clr};
    //��ȡֵ
    assign csr_rvalue = {32{csr_num == 14'h00}} & csr_crmd_data
                       | {32{csr_num == 14'h01}} & csr_prmd_data
                       | {32{csr_num == 14'h04}} & csr_ecfg_data
                       | {32{csr_num == 14'h05}} & csr_estat_data
                       | {32{csr_num == 14'h06}} & csr_era_data
                       | {32{csr_num == 14'h07}} & csr_badv_data
                       | {32{csr_num == 14'h0c}} & csr_eentry_data
                       | {32{csr_num == 14'h30}} & csr_save0_data
                       | {32{csr_num == 14'h31}} & csr_save1_data
                       | {32{csr_num == 14'h32}} & csr_save2_data
                       | {32{csr_num == 14'h33}} & csr_save3_data
                       | {32{csr_num == 14'h40}} & csr_tid_data
                       | {32{csr_num == 14'h41}} & csr_tcfg_data
                       | {32{csr_num == 14'h42}} & csr_tval_data
                       | {32{csr_num == 14'h44}} & csr_ticlr_data;

endmodule