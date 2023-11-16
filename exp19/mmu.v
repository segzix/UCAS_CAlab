module mmu #(
    parameter TLBNUM = 16
)
(
    input  wire clk,

    input  wire [31:0]  csr_dmw0_data,
    input  wire [31:0]  csr_dmw1_data, 
    input  wire         csr_crmd_da, 
    input  wire         csr_crmd_pg,
    input  wire [1:0]   csr_crmd_plv,
    input  wire         mem_wr,//���ߴ�����storeָ��
    //pre_IF����ѯ��?????

    input  wire [31:0] next_pc_vaddr,
    // input  wire [              18:0] s0_vppn,
    // input  wire                      s0_va_bit12,
    // input  wire [               9:0] s0_asid,

    //ͨ����mmu�������ѯ�˿ڣ�����ɶ�tlb�Ķ˿ڣ�������tlb������֮��ֻ������������õ�����ʵ��ַ?????
    //(��Ϊsrchָ����????Ҫ����index��found?????)
    output wire [18:0] s0_vppn,
    output wire        s0_va_bit12,
    output wire [9:0]  s0_asid,

    input  wire                      s0_found,
    input  wire [$clog2(TLBNUM)-1:0] s0_index,
    input  wire [19:0] s0_ppn,
    input  wire [5:0]  s0_ps,
    input  wire [1:0]  s0_plv,
    input  wire [1:0]  s0_mat,
    input  wire        s0_d,
    input  wire        s0_v,

    output wire [31:0]  next_pc_true_addr,
    output wire         to_PreIF_ex_ade,
    output wire         to_PreIF_ex_tlbr,
    output wire         to_PreIF_ex_pif,
    output wire         to_PreIF_ex_ppi,

    //EXE����ѯ�˿�
    input  wire         EXE_tlbsrch,
    input  wire         EXE_tlbinvtlb,
    //EXE��ȥ����tlb���index��NEʱ�õ���ָ���ź�,��ʱ�����csr�����κ��޸�
    //�����search�߼���Ҫ���ݲ�ͬ������???��ͬ��vppn��asid���в���
    input  wire [4:0]   invtlb_s_op,

    input  wire [18:0]  TLB_s_vppn,
    input  wire [31:0]  invtlb_s_rk_vppn,
    input  wire [9:0]   TLB_s_asid,
    input  wire [31:0]  invtlb_s_rj_asid,
    input  wire [31:0]  mem_vaddr,
    //д��index�Ĵ�??????
    //���ڲ��ҵĲ��֣����ڿ��ܻ��csr������Ҳ���ܻ��mmu���������tlb��csr����ֱ��
    //���ڶ���д��csr��tlb����ֱ��
    output wire [18:0] s1_vppn,
    output wire        s1_va_bit12,
    output wire [ 9:0] s1_asid,
    output wire        invtlb_valid,
    output wire [ 4:0] invtlb_op,

    input  wire [19:0] s1_ppn,
    input  wire [5:0]  s1_ps,
    input  wire [1:0]  s1_plv,
    input  wire [1:0]  s1_mat,
    input  wire        s1_d,
    input  wire        s1_v,
    input  wire                      s1_found,
    input  wire [$clog2(TLBNUM)-1:0] s1_index,

    output wire [31:0]  mem_paddr,
    output wire         to_EXE_ex_ade,
    output wire         to_EXE_ex_tlbr,
    output wire         to_EXE_ex_pil,
    output wire         to_EXE_ex_pis,
    output wire         to_EXE_ex_ppi,
    output wire         to_EXE_ex_pme
);

    wire next_pc_is_DA_mode;
    wire next_pc_is_PG_DMW_mode;
    wire next_pc_is_PG_TLB_mode;
    wire next_pc_in_DMW0;
    wire next_pc_in_DMW1;

    wire [2:0]  preIF_dmw_pseg;
    wire [8:0]  preIF_choose_ppn;//����ѡ��vaddr������ŵ�ppn��???��ѡ����ppn����????

    //��ַӳ��ģʽ
    assign next_pc_in_DMW0          =  (next_pc_vaddr[31:29]==csr_dmw0_data[31:29]) && //dmw0��vseg????
                                       (csr_dmw0_data[0] && csr_crmd_plv==2'b00 || 
                                        csr_dmw0_data[3] && csr_crmd_plv==2'b11);//dmw0����Ȩ���Ƿ����
    assign next_pc_in_DMW1          =  (next_pc_vaddr[31:29]==csr_dmw1_data[31:29]) && 
                                       (csr_dmw1_data[0] && csr_crmd_plv==2'b00 || 
                                        csr_dmw1_data[3] && csr_crmd_plv==2'b11);
    assign next_pc_is_DA_mode       =  csr_crmd_da && ~csr_crmd_pg;
    assign next_pc_is_PG_DMW_mode   = ~csr_crmd_da &&  csr_crmd_pg && (next_pc_in_DMW0 || next_pc_in_DMW1);
    assign next_pc_is_PG_TLB_mode   = ~csr_crmd_da &&  csr_crmd_pg && ~next_pc_in_DMW0 && ~next_pc_in_DMW1;

    //tlb��ѯ�˿�(s0,pre_IF����ѯ�˿�)
    assign s0_vppn      = next_pc_vaddr[31:13];
    assign s0_va_bit12  = next_pc_vaddr[12];
    assign s0_asid      = TLB_s_asid;//ʼ����csr�е�asid�Ĵ�????(�˿�1)

    //�쳣����
    assign to_PreIF_ex_ade  = next_pc_vaddr[31] && next_pc_is_PG_TLB_mode; // || next_pc_is_PG_DMW_mode && (next_pc_in_DMW0 ? csr_dmw0_pseg[2] : csr_dmw1_pseg[2]);
    assign to_PreIF_ex_tlbr = next_pc_is_PG_TLB_mode && ~s0_found;//�����쳣
    assign to_PreIF_ex_pif  = next_pc_is_PG_TLB_mode &&  s0_found && ~s0_v;//ҳ��Ч�쳣
    assign to_PreIF_ex_ppi  = next_pc_is_PG_TLB_mode &&  s0_found &&  s0_v && 
                              ($unsigned(csr_crmd_plv) > $unsigned(s0_plv));//��Ȩ���쳣


    //��ʵ��ַת��
    assign preIF_dmw_pseg = next_pc_in_DMW0 ? csr_dmw0_data[27:25] :
                            next_pc_in_DMW1 ? csr_dmw1_data[27:25] :
                            3'd0;
    assign preIF_choose_ppn = (s0_ps==22) ? next_pc_vaddr[20:12] : s0_ppn[8:0];//�����2MB��ҳ����ʵ��ַ�ĺ��漸λ����������

    assign next_pc_true_addr =  next_pc_is_DA_mode ? next_pc_vaddr :
                                next_pc_is_PG_DMW_mode ? {preIF_dmw_pseg,next_pc_vaddr[28:0]} :
                                next_pc_is_PG_TLB_mode ? {s0_ppn[19:9],preIF_choose_ppn,next_pc_vaddr[11:0]} :
                                32'd0;



    wire mem_addr_is_DA_mode;
    wire mem_addr_is_PG_DMW_mode;
    wire mem_addr_is_PG_TLB_mode;
    wire mem_addr_in_DMW0;
    wire mem_addr_in_DMW1;

    wire [2:0]  mem_dmw_pseg;
    wire [8:0]  mem_choose_ppn;

    //��ַӳ��ģʽ
    assign mem_addr_is_DA_mode       =  csr_crmd_da && ~csr_crmd_pg;
    assign mem_addr_is_PG_DMW_mode   = ~csr_crmd_da &&  csr_crmd_pg && (mem_addr_in_DMW0 || mem_addr_in_DMW1);
    assign mem_addr_is_PG_TLB_mode   = ~csr_crmd_da &&  csr_crmd_pg && ~mem_addr_in_DMW0 && ~mem_addr_in_DMW1;
    assign mem_addr_in_DMW0          =  (mem_vaddr[31:29]==csr_dmw0_data[31:29]) && 
                                        (csr_dmw0_data[0] && csr_crmd_plv==2'b00 || 
                                         csr_dmw0_data[3] && csr_crmd_plv==2'b11);
    assign mem_addr_in_DMW1          =  (mem_vaddr[31:29]==csr_dmw1_data[31:29]) && 
                                        (csr_dmw1_data[0] && csr_crmd_plv==2'b00 || 
                                         csr_dmw1_data[3] && csr_crmd_plv==2'b11);

    //tlb��ѯ�˿�(s1,EXE����ѯ�˿�)
    assign s1_vppn      =   EXE_tlbinvtlb ? invtlb_s_rk_vppn[31:13] :
                            EXE_tlbsrch ? TLB_s_vppn :
                            mem_vaddr[31:13];
    assign s1_asid      =   EXE_tlbinvtlb ? invtlb_s_rj_asid[9:0] : TLB_s_asid;
    assign s1_va_bit12  =   EXE_tlbinvtlb ? invtlb_s_rk_vppn[12]  :
                            EXE_tlbsrch ? 1'd0 : 
                            mem_vaddr[12];
    assign invtlb_valid = EXE_tlbinvtlb;
    assign invtlb_op    = invtlb_s_op;

    //�쳣����
    assign to_EXE_ex_ade  = mem_vaddr[31] && mem_addr_is_PG_TLB_mode; // || mem_addr_is_PG_DMW_mode && (mem_addr_in_DMW0 ? csr_dmw0_pseg[2] : csr_dmw1_pseg[2]);
    assign to_EXE_ex_tlbr = mem_addr_is_PG_TLB_mode && ~s1_found;//��������
    assign to_EXE_ex_pil  = mem_addr_is_PG_TLB_mode &&  s1_found && ~s1_v && ~mem_wr;//load��Ч����
    assign to_EXE_ex_pis  = mem_addr_is_PG_TLB_mode &&  s1_found && ~s1_v &&  mem_wr;//store��Ч����
    assign to_EXE_ex_ppi  = mem_addr_is_PG_TLB_mode &&  s1_found &&  s1_v && 
                            ($unsigned(csr_crmd_plv) > $unsigned(s1_plv));//��Ȩ�ȼ�����
    assign to_EXE_ex_pme  = mem_addr_is_PG_TLB_mode &&  s1_found &&  s1_v && 
                            !($unsigned(csr_crmd_plv) > $unsigned(s1_plv)) && 
                            mem_wr && ~s1_d;//ҳ�޸�����

    //��ʵ��ַת��
    assign mem_dmw_pseg =   mem_addr_in_DMW0 ? csr_dmw0_data[27:25] :
                            mem_addr_in_DMW1 ? csr_dmw1_data[27:25] :
                            3'd0;
    assign mem_choose_ppn = (s1_ps==22) ? mem_vaddr[20:12] : s1_ppn[8:0];//�����2MB��ҳ����ʵ��ַ�ĺ��漸λ����������

    assign mem_paddr =  mem_addr_is_DA_mode ? mem_vaddr :
                        mem_addr_is_PG_DMW_mode ? {mem_dmw_pseg, mem_vaddr[28:0]} :
                        mem_addr_is_PG_TLB_mode ? {s1_ppn[19:9],mem_choose_ppn,mem_vaddr[11:0]}:
                        32'd0;

endmodule