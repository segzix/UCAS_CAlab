`timescale 1ns / 1ps
`define CSR_CRMD    14'h0000
`define CSR_PRMD    14'h0001
`define CSR_ECFG    14'h0004
`define CSR_ESTAT   14'h0005
`define CSR_ERA     14'h0006
`define CSR_BADV    14'h0007
`define CSR_EENTRY  14'h000c
`define CSR_SAVE0   14'h0030
`define CSR_SAVE1   14'h0031
`define CSR_SAVE2   14'h0032
`define CSR_SAVE3   14'h0033
`define CSR_TID     14'h0040
`define CSR_TCFG    14'h0041
`define CSR_TVAL    14'h0042
`define CSR_TICLR   14'h0044

`define CSR_TLBIDX      14'h0010
`define CSR_TLBEHI      14'h0011
`define CSR_TLBELO0     14'h0012
`define CSR_TLBELO1     14'h0013
`define CSR_ASID        14'h0018
`define CSR_TLBRENTRY   14'h0088
`define CSR_DMW0        14'h0180
`define CSR_DMW1        14'h0181

`define ECODE_ADE    6'h08
`define ECODE_ALE    6'h09
`define ESUBCODE_ADEF   9'h000
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
module csr_regfile#(
    parameter TLBNUM = 16
)
(
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
    output wire [31:0]   tlbr_entry, //tlb����������ڵ�ַ
    output wire          has_int   , //�ж���Ч�ź�
    input  wire          ertn_flush, //ertnָ��ִ����Ч�ź�
    input  wire          wb_ex     , //�쳣�������ź�
    input  wire [ 5:0]   wb_ecode  , //�쳣����
    input  wire [ 8:0]   wb_esubcode,//�쳣���͸�����
    input  wire [31:0]   wb_vaddr   ,//�ô��ַ
    input  wire [31:0]   wb_pc  ,     //д�صķ��ص�ַ

    input  wire          tlbrd,
    input  wire          tlbwr,
    input  wire          tlbfill,
    input  wire          tlbsrch,

    input  wire [3:0]    TLB_s_index,//TLB�����ƫ����//srchʱд��
    input  wire          TLB_s_NE,//TLB�����NEλ���Ƿ�����//s0_found||s1_found���������ֻ֤����һ������//srchʱд��
    output wire [18:0]   TLB_s_vppn,
    output wire [9:0]    TLB_s_asid,
    //д��index�Ĵ���

    output wire [$clog2(TLBNUM)-1:0] TLB_r_index,
    //������Щ�����ڶ���ʱ��Ż�����Ǹ�������
    input  wire [18:0]   TLB_r_vppn,
    input  wire [9:0]    TLB_r_asid,
    input  wire          TLB_r_E,//rdʱд��
    input  wire [5:0]    TLB_r_ps,//TLB�����psλ����żҳ//rdʱд��
    //д��ehi��asid�Ĵ���

    input  wire          TLB_r_g,
    input  wire          TLB_r_valid0,
    input  wire          TLB_r_dirty0,
    input  wire [1:0]    TLB_r_plv0,
    input  wire [1:0]    TLB_r_mat0,
    input  wire [19:0]   TLB_r_ppn0,
    //׼��д��TLBELO0
    input  wire          TLB_r_valid1,
    input  wire          TLB_r_dirty1,
    input  wire [1:0]    TLB_r_plv1,
    input  wire [1:0]    TLB_r_mat1,
    input  wire [19:0]   TLB_r_ppn1,
    //׼��д��TLBELO1

    // input  wire [31:0]   TLB_eentry,

    //����idx�Ĵ��������
    output  wire [$clog2(TLBNUM)-1:0] TLB_w_index,
    output  wire                      TLB_w_e,
    output  wire [               5:0] TLB_w_ps,

    //����ehi�Ĵ��������
    output  wire [              18:0] TLB_w_vppn,

    //����asid�Ĵ��������
    output  wire [               9:0] TLB_w_asid,

    //����tlbλΪ����ELO�Ĵ��������
    output  wire                      TLB_w_g,
    output  wire [              19:0] TLB_w_ppn0,
    output  wire [               1:0] TLB_w_plv0,
    output  wire [               1:0] TLB_w_mat0,
    output  wire                      TLB_w_d0,
    output  wire                      TLB_w_v0,
    output  wire [              19:0] TLB_w_ppn1,
    output  wire [               1:0] TLB_w_plv1,
    output  wire [               1:0] TLB_w_mat1,
    output  wire                      TLB_w_d1,
    output  wire                      TLB_w_v1,
    //����Ľ�Ҫд��tlbģ�������

    output  wire [31: 0]              csr_dmw0_data,
    output  wire [31: 0]              csr_dmw1_data,
    output  reg                       csr_crmd_da, 
    output  reg                       csr_crmd_pg,
    output  reg  [ 1: 0]              csr_crmd_plv
    
    //�����mmuģ�������ж���ʵ��ַת��ģʽ

);
    wire [ 7: 0] hw_int_in;
    wire         ipi_int_in;
    //��ǰģʽ��Ϣ
    wire [31: 0] csr_crmd_data;      
    reg          csr_crmd_ie;
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
    //tlb�Ĵ�����ֵ
    wire [31: 0] csr_tlbidx_data;
    wire [31: 0] csr_tlbehi_data;
    wire [31: 0] csr_tlbelo0_data;
    wire [31: 0] csr_tlbelo1_data;
    wire [31: 0] csr_tlbasid_data;
    wire [31: 0] csr_tlbrentry_data;
    //��ʱ���ж����
    wire [31: 0] csr_ticlr_data;
    assign has_int = (|(csr_estat_is[11:0] & csr_ecfg_lie[11:0])) & csr_crmd_ie;
    assign ex_entry = csr_eentry_data;
    assign ertn_entry = csr_era_data;
    assign tlbr_entry = csr_tlbrentry_data;

    //CRMD  PLV,IE
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
        else if (csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_plv <= csr_wmask[1:0] & csr_wvalue[1:0]
                          | ~csr_wmask[1:0] & csr_crmd_plv;
            csr_crmd_ie  <= csr_wmask[2] & csr_wvalue[2]
                          | ~csr_wmask[2] & csr_crmd_ie;
        end
    end

    //CRMD  DA,PG,DATF,DATM
    always @(posedge clk) begin
        if(reset) begin
            csr_crmd_da   <= 1'b1;
            csr_crmd_pg   <= 1'b0;
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end
        else if(csr_we && csr_num == `CSR_CRMD)begin
            csr_crmd_da   <= csr_wmask[3]   & csr_wvalue[3]
                          | ~csr_wmask[3]   & csr_crmd_da;
            csr_crmd_pg   <= csr_wmask[4]   & csr_wvalue[4]
                          | ~csr_wmask[4]   & csr_crmd_pg;
            csr_crmd_datf <= csr_wmask[6:5] & csr_wvalue[6:5]
                          | ~csr_wmask[6:5] & csr_crmd_datf;
            csr_crmd_datm <= csr_wmask[8:7] & csr_wvalue[8:7]
                          | ~csr_wmask[8:7] & csr_crmd_datm;
        end
        else if(wb_ex &&  wb_ecode == 6'h3f) begin//tlb�����쳣
            csr_crmd_da   <= 1'b1;
            csr_crmd_pg   <= 1'b0;
        end
        else if(ertn_flush && csr_estat_ecode == 6'h3f) begin//tlb�����쳣����ʱ����
            csr_crmd_da   <= 1'b0;
            csr_crmd_pg   <= 1'b1;
            // csr_crmd_datf <= 2'b01;
            // csr_crmd_datm <= 2'b01;//����ò��ùܣ�Ӳ���Զ������ù�            
        end
    end

    //PRMD  PPLV,PIE
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end
        else if (csr_we && csr_num == `CSR_PRMD) begin
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
        else if(csr_we && csr_num == `CSR_ECFG)
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
        else if (csr_we && (csr_num == `CSR_ESTAT)) begin
            csr_estat_is[1:0] <= ( csr_wmask[1:0] & csr_wvalue[1:0])
                               | (~csr_wmask[1:0] & csr_estat_is[1:0]          );
        end

        csr_estat_is[9:2] <= hw_int_in[7:0];
        csr_estat_is[10] <= 1'b0;

        if (timer_cnt[31:0] == 32'b0) begin
            csr_estat_is[11] <= 1'b1;
        end
        else if (csr_we && csr_num == `CSR_TICLR && csr_wmask[0]&& csr_wvalue[0])begin 
            csr_estat_is[11] <= 1'b0;
        end

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
        else if (csr_we && csr_num == `CSR_ERA) 
            csr_era_data <= csr_wmask[31:0] & csr_wvalue[31:0]
                         | ~csr_wmask[31:0] & csr_era_data;
    end

    //EENTRY �����ж���ڵ�ַ
    always @(posedge clk) begin
        if (csr_we && (csr_num == `CSR_EENTRY))
            csr_eentry_va <=   csr_wmask[31:6] & csr_wvalue[31:6]
                            | ~csr_wmask[31:6] & csr_eentry_va ;
    end

    //SAVE
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_SAVE0) 
            csr_save0_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save0_data;
        if (csr_we && (csr_num == `CSR_SAVE1)) 
            csr_save1_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save1_data;
        if (csr_we && (csr_num == `CSR_SAVE2)) 
            csr_save2_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save2_data;
        if (csr_we && (csr_num == `CSR_SAVE3)) 
            csr_save3_data <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_save3_data;
    end

    //BADV ȡָ��ô��ַ�쳣ʱ���쳣��ַд��(tlb�쳣ʱҲҪȫ��д��)
    assign wb_ex_addr_err = wb_ecode == 6'h08 || wb_ecode == 6'h09 ||
                            wb_ecode == 6'h3f || wb_ecode == 6'h03 || 
                            wb_ecode == 6'h01 || wb_ecode == 6'h02 || 
                            wb_ecode == 6'h07 || wb_ecode == 6'h04;
    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err) begin
            csr_badv_vaddr <= (wb_ecode == 6'h08 && wb_esubcode == 9'd0) ? wb_pc:wb_vaddr;
        end else if (csr_we && csr_num==`CSR_BADV) begin
            csr_badv_vaddr <=  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & csr_badv_vaddr;
        end
    end

    //TID
    always @(posedge clk) begin
        if (reset) begin
            csr_tid_tid <= 32'b0;
        end
        else if (csr_we && csr_num == `CSR_TID) begin
            csr_tid_tid <= csr_wmask[31:0] & csr_wvalue[31:0]
                        | ~csr_wmask[31:0] & csr_tid_tid;
        end
    end

    //TCFG  EN��Periodic��InitVal
    always @(posedge clk) begin
        if (reset) 
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num == `CSR_TCFG) begin
            csr_tcfg_en <= csr_wmask[0] & csr_wvalue[0]
                        | ~csr_wmask[0] & csr_tcfg_en;
        end
        if (csr_we && csr_num == `CSR_TCFG) begin
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
        else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_value[0]) begin
            timer_cnt <= {tcfg_next_value[31:2], 2'b0};
        end
        else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin //��ʱ���Ƿ������Ե��������? 0-1=ff..ff,��ôֹͣ����
            if (timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic) begin
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            end
            else begin
                timer_cnt <= timer_cnt - 1'b1;
            end
        end
    end

    //TICLRCLR

    ////////////////////////////////TLB���csr�Ĵ���

    /////IDX�Ĵ���
    reg [3:0]   csr_tlbidx_idx;
    reg [5:0]   csr_tlbidx_ps;
    reg         csr_tlbidx_ne;

    always @(posedge clk) begin
        if (reset) begin
            csr_tlbidx_idx <= 4'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBIDX)begin
            csr_tlbidx_idx <=  csr_wmask[3:0] & csr_wvalue[3:0]
                            | ~csr_wmask[3:0] & csr_tlbidx_idx;
        end
        else if (tlbsrch && TLB_s_NE) begin//Ϊ���������в�д��
            csr_tlbidx_idx <= TLB_s_index;
        end
    end
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbidx_ps <= 6'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBIDX)begin
            csr_tlbidx_ps <=  csr_wmask[29:24] & csr_wvalue[29:24]
                           | ~csr_wmask[29:24] & csr_tlbidx_ps;
        end
        else if (tlbrd && TLB_r_E) begin
            csr_tlbidx_ps <= TLB_r_ps;
        end
        else if (tlbrd && !TLB_r_E) begin
            csr_tlbidx_ps <= 0;
        end
    end
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbidx_ne <= 1'b1;
        end
        else if(csr_we && csr_num == `CSR_TLBIDX)begin
            csr_tlbidx_ne <=   csr_wmask[31] & csr_wvalue[31]
                            | ~csr_wmask[31] & csr_tlbidx_ne;
        end
        else if (tlbsrch) begin//Ϊ���������в�д��
            csr_tlbidx_ne <= !TLB_s_NE;
        end
        else if (tlbrd) begin
            csr_tlbidx_ne <= !TLB_r_E;
        end
    end

    assign TLB_r_index =  csr_tlbidx_idx;

    /////EHI(�����쳣ʱ�轫vaddr��¼�ڴ�!)
    reg [18:0]    csr_tlbehi_vppn; 
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbehi_vppn <= 19'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBEHI)begin
            csr_tlbehi_vppn <= csr_wmask[31:13] & csr_wvalue[31:13]
                            | ~csr_wmask[31:13] & csr_tlbehi_vppn;
        end
        else if (wb_ex && ( wb_ecode == 6'h3f || wb_ecode==6'h03 || wb_ecode==6'h01 || 
                            wb_ecode == 6'h02 || wb_ecode==6'h07 || wb_ecode==6'h04)) begin
            csr_tlbehi_vppn <= wb_vaddr[31:13];
        end
        else if (tlbrd && TLB_r_E) begin
            csr_tlbehi_vppn <= TLB_r_vppn;
        end
        else if (tlbrd && !TLB_r_E) begin
            csr_tlbehi_vppn <= 0;
        end
    end

    assign TLB_s_vppn = csr_tlbehi_vppn;
    assign TLB_s_asid = csr_tlbasid_asid;


    //ELO0
    reg         csr_tlbELO0_v; 
    reg         csr_tlbELO0_d; 
    reg [1:0]   csr_tlbELO0_plv; 
    reg [1:0]   csr_tlbELO0_mat; 
    reg         csr_tlbELO0_g; 
    reg [19:0]  csr_tlbELO0_ppn; 
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbELO0_v   <= 1'b0;
            csr_tlbELO0_d   <= 1'b0;
            csr_tlbELO0_plv <= 2'b0;
            csr_tlbELO0_mat <= 2'b0;
            csr_tlbELO0_g   <= 1'b0;
            csr_tlbELO0_ppn <= 20'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBELO0)begin
            csr_tlbELO0_v <=   csr_wmask[0]    & csr_wvalue[0]
                            | ~csr_wmask[0]    & csr_tlbELO0_v;
            csr_tlbELO0_d <=   csr_wmask[1]    & csr_wvalue[1]
                            | ~csr_wmask[1]    & csr_tlbELO0_d;
            csr_tlbELO0_plv <= csr_wmask[3:2]  & csr_wvalue[3:2]
                            | ~csr_wmask[3:2]  & csr_tlbELO0_plv;
            csr_tlbELO0_mat <= csr_wmask[5:4]  & csr_wvalue[5:4]
                            | ~csr_wmask[5:4]  & csr_tlbELO0_mat;
            csr_tlbELO0_g <=   csr_wmask[6]    & csr_wvalue[6]
                            | ~csr_wmask[6]    & csr_tlbELO0_g;
            csr_tlbELO0_ppn <= csr_wmask[27:8] & csr_wvalue[27:8]
                            | ~csr_wmask[27:8] & csr_tlbELO0_ppn;
        end
        else if (tlbrd && TLB_r_E) begin
            csr_tlbELO0_v   <= TLB_r_valid0;
            csr_tlbELO0_d   <= TLB_r_dirty0;
            csr_tlbELO0_plv <= TLB_r_plv0;
            csr_tlbELO0_mat <= TLB_r_mat0;
            csr_tlbELO0_g   <= TLB_r_g;//����ELO��gλ����Ϊ���һ��
            csr_tlbELO0_ppn <= TLB_r_ppn0;
        end
        else if (tlbrd && !TLB_r_E)begin
            csr_tlbELO0_v   <= 0;
            csr_tlbELO0_d   <= 0;
            csr_tlbELO0_plv <= 0;
            csr_tlbELO0_mat <= 0;
            csr_tlbELO0_g   <= 0;//����ELO��gλ����Ϊ���һ��
            csr_tlbELO0_ppn <= 0;
        end//�����Ч����ȫΪ0
    end

    assign TLB_w_ppn0 = csr_tlbELO0_ppn;
    assign TLB_w_plv0 = csr_tlbELO0_plv;
    assign TLB_w_mat0 = csr_tlbELO0_mat;
    assign TLB_w_d0   = csr_tlbELO0_d;
    assign TLB_w_v0   = csr_tlbELO0_v;

    //ELO1
    reg         csr_tlbELO1_v; 
    reg         csr_tlbELO1_d; 
    reg [1:0]   csr_tlbELO1_plv; 
    reg [1:0]   csr_tlbELO1_mat; 
    reg         csr_tlbELO1_g; 
    reg [19:0]  csr_tlbELO1_ppn; 
    always @(posedge clk) begin
        if (reset) begin
            csr_tlbELO1_v   <= 1'b0;
            csr_tlbELO1_d   <= 1'b0;
            csr_tlbELO1_plv <= 2'b0;
            csr_tlbELO1_mat <= 2'b0;
            csr_tlbELO1_g   <= 1'b0;
            csr_tlbELO1_ppn <= 20'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBELO1)begin
            csr_tlbELO1_v <=   csr_wmask[0]    & csr_wvalue[0]
                            | ~csr_wmask[0]    & csr_tlbELO1_v;
            csr_tlbELO1_d <=   csr_wmask[1]    & csr_wvalue[1]
                            | ~csr_wmask[1]    & csr_tlbELO1_d;
            csr_tlbELO1_plv <= csr_wmask[3:2]  & csr_wvalue[3:2]
                            | ~csr_wmask[3:2]  & csr_tlbELO1_plv;
            csr_tlbELO1_mat <= csr_wmask[5:4]  & csr_wvalue[5:4]
                            | ~csr_wmask[5:4]  & csr_tlbELO1_mat;
            csr_tlbELO1_g <=   csr_wmask[6]    & csr_wvalue[6]
                            | ~csr_wmask[6]    & csr_tlbELO1_g;
            csr_tlbELO1_ppn <= csr_wmask[27:8] & csr_wvalue[27:8]
                            | ~csr_wmask[27:8] & csr_tlbELO1_ppn;
        end
        else if (tlbrd && TLB_r_E) begin
            csr_tlbELO1_v   <= TLB_r_valid1;
            csr_tlbELO1_d   <= TLB_r_dirty1;
            csr_tlbELO1_plv <= TLB_r_plv1;
            csr_tlbELO1_mat <= TLB_r_mat1;
            csr_tlbELO1_g   <= TLB_r_g;//����ELO��gλ����Ϊ���һ��
            csr_tlbELO1_ppn <= TLB_r_ppn1;
        end
        else if (tlbrd && !TLB_r_E)begin
            csr_tlbELO1_v   <= 0;
            csr_tlbELO1_d   <= 0;
            csr_tlbELO1_plv <= 0;
            csr_tlbELO1_mat <= 0;
            csr_tlbELO1_g   <= 0;//����ELO��gλ����Ϊ���һ��
            csr_tlbELO1_ppn <= 0;
        end//�����Ч����ȫΪ0
    end

    assign TLB_w_ppn1 = csr_tlbELO1_ppn;
    assign TLB_w_plv1 = csr_tlbELO1_plv;
    assign TLB_w_mat1 = csr_tlbELO1_mat;
    assign TLB_w_d1   = csr_tlbELO1_d;
    assign TLB_w_v1   = csr_tlbELO1_v;

    assign TLB_w_vppn  =  csr_tlbehi_vppn;
    assign TLB_w_ps    =  csr_tlbidx_ps;
    assign TLB_w_e     = !csr_tlbidx_ne;
    assign TLB_w_index =  csr_tlbidx_idx;
    assign TLB_w_g     =  csr_tlbELO0_g && csr_tlbELO1_g;
    assign TLB_w_asid  = csr_tlbasid_asid;
    //����ELO�Ĵ�����gλ��Ϊ��Чʱ���Ż�ȥ��tlb�е�gλ��Ϊ1

    //asid
    reg [9:0]   csr_tlbasid_asid;
    wire[7:0]   csr_tlbasid_asidbits;

    always @(posedge clk)begin
        if (reset) begin
            csr_tlbasid_asid <= 10'b0;
        end
        else if(csr_we && csr_num == `CSR_ASID)begin
            csr_tlbasid_asid <= csr_wmask[9:0] & csr_wvalue[9:0]
                             | ~csr_wmask[9:0] & csr_tlbasid_asid;
        end
        else if (tlbrd && TLB_r_E) begin
            csr_tlbasid_asid <= TLB_r_asid;
        end
        else if (tlbrd && !TLB_r_E) begin
            csr_tlbasid_asid <= 0;
        end
    end

    assign csr_tlbasid_asidbits = 8'b1010;
    //д��tlb�Ĵ�����asid�����ڴˣ�д��д��we����

    //asid
    reg [25:0]   csr_tlbrentry;

    always @(posedge clk)begin
        if (reset) begin
            csr_tlbrentry <= 26'b0;
        end
        else if(csr_we && csr_num == `CSR_TLBRENTRY)begin
            csr_tlbrentry <=   csr_wmask[31:6] & csr_wvalue[31:6]
                            | ~csr_wmask[31:6] & csr_tlbrentry;
        end
    end

    //tlb��������ʱ��ת���˴�

    reg         csr_dmw0_plv0;
    reg         csr_dmw0_plv3;
    reg [1:0]   csr_dmw0_mat;
    reg [2:0]   csr_dmw0_pseg;
    reg [2:0]   csr_dmw0_vseg;

    reg         csr_dmw1_plv0;
    reg         csr_dmw1_plv3;
    reg [1:0]   csr_dmw1_mat;
    reg [2:0]   csr_dmw1_pseg;
    reg [2:0]   csr_dmw1_vseg;

    //ӳ�䴰�ڼĴ���
    always @(posedge clk) begin
        if (reset) begin
            csr_dmw0_plv0 <= 0;
            csr_dmw0_plv3 <= 0;
            csr_dmw0_mat <= 0;
            csr_dmw0_pseg <= 0;
            csr_dmw0_vseg <= 0;
        end else if (csr_we && csr_num==`CSR_DMW0) begin
            csr_dmw0_plv0 <= csr_wmask[0] & csr_wvalue[0]
                      | ~csr_wmask[0] & csr_dmw0_plv0;
            csr_dmw0_plv3 <= csr_wmask[3] & csr_wvalue[3]
                      | ~csr_wmask[3] & csr_dmw0_plv3;
            csr_dmw0_mat <= csr_wmask[5:4] & csr_wvalue[5:4]
                      | ~csr_wmask[5:4] & csr_dmw0_mat;
            csr_dmw0_pseg <= csr_wmask[27:25] & csr_wvalue[27:25]
                      | ~csr_wmask[27:25] & csr_dmw0_pseg;
            csr_dmw0_vseg <= csr_wmask[31:29] & csr_wvalue[31:29]
                      | ~csr_wmask[31:29] & csr_dmw0_vseg;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            csr_dmw1_plv0 <= 0;
            csr_dmw1_plv3 <= 0;
            csr_dmw1_mat <= 0;
            csr_dmw1_pseg <= 0;
            csr_dmw1_vseg <= 0;
        end else if (csr_we && csr_num==`CSR_DMW1) begin
            csr_dmw1_plv0 <= csr_wmask[0] & csr_wvalue[0]
                      | ~csr_wmask[0] & csr_dmw1_plv0;
            csr_dmw1_plv3 <= csr_wmask[3] & csr_wvalue[3]
                      | ~csr_wmask[3] & csr_dmw1_plv3;
            csr_dmw1_mat <= csr_wmask[5:4] & csr_wvalue[5:4]
                      | ~csr_wmask[5:4] & csr_dmw1_mat;
            csr_dmw1_pseg <= csr_wmask[27:25] & csr_wvalue[27:25]
                      | ~csr_wmask[27:25] & csr_dmw1_pseg;
            csr_dmw1_vseg <= csr_wmask[31:29] & csr_wvalue[31:29]
                      | ~csr_wmask[31:29] & csr_dmw1_vseg;
        end
    end

    ////////////////////////////////TLB���csr�Ĵ���

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

    assign csr_tlbidx_data    = {csr_tlbidx_ne,1'b0,csr_tlbidx_ps,20'b0,csr_tlbidx_idx};
    assign csr_tlbehi_data    = {csr_tlbehi_vppn,13'b0};
    assign csr_tlbelo0_data   = {4'b0,csr_tlbELO0_ppn,1'b0,csr_tlbELO0_g,csr_tlbELO0_mat,csr_tlbELO0_plv,csr_tlbELO0_d,csr_tlbELO0_v};
    assign csr_tlbelo1_data   = {4'b0,csr_tlbELO1_ppn,1'b0,csr_tlbELO1_g,csr_tlbELO1_mat,csr_tlbELO1_plv,csr_tlbELO1_d,csr_tlbELO1_v};
    assign csr_tlbasid_data   = {8'b0,csr_tlbasid_asidbits,6'b0,csr_tlbasid_asid};
    assign csr_tlbrentry_data = {csr_tlbrentry,6'b0}; 
    assign csr_dmw0_data   = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};
    assign csr_dmw1_data   = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};
    //��ȡֵ
    assign csr_rvalue =  {32{csr_num == `CSR_CRMD}}      & csr_crmd_data
                       | {32{csr_num == `CSR_PRMD}}      & csr_prmd_data
                       | {32{csr_num == `CSR_ECFG}}      & csr_ecfg_data
                       | {32{csr_num == `CSR_ESTAT}}     & csr_estat_data
                       | {32{csr_num == `CSR_ERA}}       & csr_era_data
                       | {32{csr_num == `CSR_BADV}}      & csr_badv_data
                       | {32{csr_num == `CSR_EENTRY}}    & csr_eentry_data
                       | {32{csr_num == `CSR_SAVE0}}     & csr_save0_data
                       | {32{csr_num == `CSR_SAVE1}}     & csr_save1_data
                       | {32{csr_num == `CSR_SAVE2}}     & csr_save2_data
                       | {32{csr_num == `CSR_SAVE3}}     & csr_save3_data
                       | {32{csr_num == `CSR_TID}}       & csr_tid_data
                       | {32{csr_num == `CSR_TCFG}}      & csr_tcfg_data
                       | {32{csr_num == `CSR_TVAL}}      & csr_tval_data
                       | {32{csr_num == `CSR_TICLR}}     & csr_ticlr_data
                       | {32{csr_num == `CSR_TLBIDX}}    & csr_tlbidx_data
                       | {32{csr_num == `CSR_TLBEHI}}    & csr_tlbehi_data
                       | {32{csr_num == `CSR_TLBELO0}}   & csr_tlbelo0_data
                       | {32{csr_num == `CSR_TLBELO1}}   & csr_tlbelo1_data
                       | {32{csr_num == `CSR_ASID}}      & csr_tlbasid_data
                       | {32{csr_num == `CSR_TLBRENTRY}} & csr_tlbrentry_data
                       | {32{csr_num==`CSR_DMW0}}        & csr_dmw0_data
                       | {32{csr_num==`CSR_DMW1}}        & csr_dmw1_data;

endmodule