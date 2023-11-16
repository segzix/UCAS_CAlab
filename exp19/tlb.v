
/**�����ж��ڶ̺��ߺ����ĸһЩ˵��
����λ(E)��1 ���ء�Ϊ 1 ��ʾ���� TLB ����ǿգ����Բ������ƥ�䡣

��ַ�ռ��ʶ(ASID)��10 ���ء���ַ�ռ��ʶ�������ֲ�ͬ�����е�ͬ�������ַ����������л�ʱ������� TLB ��������������ʧ������ϵͳΪÿ�����̷���Ψһ�� ASID��TLB �ڽ��в���ʱ����ַ��Ϣ��һ���⣬����Ҫ�ȶ� ASID ��Ϣ��

ȫ�ֱ�־λ(G)��1 ���ء�����λΪ 1 ʱ������ʱ������ ASID �Ƿ�һ���Եļ�顣������ϵͳ��Ҫ�����н��̼乲��ͬһ�����ַʱ���������� TLB ҳ�����е� G λ��Ϊ 1��

ҳ��С(PS)��6 ���ء����� MTLB �г��֡�����ָ����ҳ�����д�ŵ�ҳ��С����ֵ��ҳ��С�� 2����ָ������о�ܹ� 32 λ�����ֻ֧�� 4KB �� 4MB ����ҳ��С����Ӧ TLB �����е� PS ֵ�ֱ��� 12 �� 21+1��

��˫ҳ��(VPPN)��(VALEN-13)���ء�����о�ܹ� 32 λ������У�ÿһ��ҳ�����������ڵ�һ����ż����ҳ����Ϣ������ TLB ҳ�����д����ҳ�ŵ���ϵͳ����ҳ��/2 �����ݣ�����ҳ�ŵ����λ����Ҫ����� TLB �С����� TLB ʱ�ڸ��ݱ�������ҳ�ŵ����λ������ѡ��������ҳ����ż����ҳ������ת����Ϣ��

��Чλ(V)��1 ���ء�Ϊ 1 ������ҳ��������Ч���ұ����ʹ��ġ�

��λ(D)��1 ���ء�Ϊ 1 ��ʾ��ҳ��������Ӧ�ĵ�ַ��Χ�����������ݡ�

�洢��������(MAT)��2 ���ء��������ڸ�ҳ�������ڵ�ַ�ռ��Ϸô�����Ĵ洢�������͡�

��Ȩ�ȼ���PLV����2 ���ء���ҳ�����Ӧ����Ȩ�ȼ���

����ҳ��(PPN)��(PALEN-12)���ء���ҳ��С���� 4KB ��ʱ��TLB ������ŵ� PPN ��[PS-1:12]λ����������ֵ
**/
module tlb #(
    parameter TLBNUM = 16
)
(
    input  wire clk,
    
    input  wire [              18:0] s0_vppn,
    input  wire                      s0_va_bit12,
    input  wire [               9:0] s0_asid,
    output wire                      s0_found,
    output wire [$clog2(TLBNUM)-1:0] s0_index,
    output wire [              19:0] s0_ppn,
    output wire [               5:0] s0_ps,
    output wire [               1:0] s0_plv,
    output wire [               1:0] s0_mat,
    output wire                      s0_d,
    output wire                      s0_v,
    input  wire [              18:0] s1_vppn,
    input  wire                      s1_va_bit12,
    input  wire [               9:0] s1_asid,
    output wire                      s1_found,
    output wire [$clog2(TLBNUM)-1:0] s1_index,
    output wire [              19:0] s1_ppn,
    output wire [               5:0] s1_ps,
    output wire [               1:0] s1_plv,
    output wire [               1:0] s1_mat,
    output wire                      s1_d,
    output wire                      s1_v,

    input  wire                      invtlb_valid,
    input  wire [               4:0] invtlb_op,

    input  wire                      we, //w(rite) e(nable)
    input  wire [$clog2(TLBNUM)-1:0] w_index,
    input  wire                      w_e,
    input  wire [              18:0] w_vppn,
    input  wire [               5:0] w_ps,
    input  wire [               9:0] w_asid,
    input  wire                      w_g,
    input  wire [              19:0] w_ppn0,
    input  wire [               1:0] w_plv0,
    input  wire [               1:0] w_mat0,
    input  wire                      w_d0,
    input  wire                      w_v0,
    input  wire [              19:0] w_ppn1,
    input  wire [               1:0] w_plv1,
    input  wire [               1:0] w_mat1,
    input  wire                      w_d1,
    input  wire                      w_v1,

    input  wire [$clog2(TLBNUM)-1:0] r_index,
    output wire                      r_e,
    output wire [              18:0] r_vppn,
    output wire [               5:0] r_ps,
    output wire [               9:0] r_asid,
    output wire                      r_g,
    output wire [              19:0] r_ppn0,
    output wire [               1:0] r_plv0,
    output wire [               1:0] r_mat0,
    output wire                      r_d0,
    output wire                      r_v0,
    output wire [              19:0] r_ppn1,
    output wire [               1:0] r_plv1,
    output wire [               1:0] r_mat1,
    output wire                      r_d1,
    output wire                      r_v1
);


reg [TLBNUM-1:0] tlb_e;
reg [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB
reg [18:0] tlb_vppn [TLBNUM-1:0];
reg [ 9:0] tlb_asid [TLBNUM-1:0];
reg        tlb_g    [TLBNUM-1:0];

reg [19:0] tlb_ppn0 [TLBNUM-1:0];
reg [ 1:0] tlb_plv0 [TLBNUM-1:0];
reg [ 1:0] tlb_mat0 [TLBNUM-1:0];
reg        tlb_d0   [TLBNUM-1:0];
reg        tlb_v0   [TLBNUM-1:0];
wire s0_page;
reg [19:0] tlb_ppn1 [TLBNUM-1:0];
reg [ 1:0] tlb_plv1 [TLBNUM-1:0];
reg [ 1:0] tlb_mat1 [TLBNUM-1:0];
reg        tlb_d1   [TLBNUM-1:0];
reg        tlb_v1   [TLBNUM-1:0];
wire s1_page;

//��ҳ��Сҳ��Ӧ��vppny��offset��ʽ
//��vppn[18:9] ��Чλ (vppn[7:0] va_bit12 offset[11:0]) =>(21λ)
//С��vppn[18:0] va_bit12 offset[11:0]
//---------����-----------
//match
wire [TLBNUM-1:0] match0;
wire [TLBNUM-1:0] match1;
genvar i;
generate
    for (i = 0; i < TLBNUM; i = i + 1) begin : x
        assign match0[i] = (s0_vppn[18:9]==tlb_vppn[i][18:9])//������Σ�vppnǰ��λ�϶����ܴ�
                            && (tlb_ps4MB[i] || s0_vppn[8:0]==tlb_vppn[i][8:0])//���ǵ�����Ǵ�ҳ����ôvppn��λ�Ϳ��Բ�һ��������Ҫ��һ��
                            && ((s0_asid==tlb_asid[i]) || tlb_g[i])//Ҫ����ͬһ�����̺�ȫ��ָ��
                            && tlb_e[i];
        assign match1[i] = (s1_vppn[18:9]==tlb_vppn[i][18:9])
                            && (tlb_ps4MB[i] || s1_vppn[8:0]==tlb_vppn[i][8:0])
                            && ((s1_asid==tlb_asid[i]) || tlb_g[i])
                            && tlb_e[i];
    end
endgenerate

assign s0_found = match0 != 16'd0;
assign s1_found = match1 != 16'd0;

assign s0_index =   match0[ 1] ? 4'd1  :
                    match0[ 2] ? 4'd2  :
                    match0[ 3] ? 4'd3  :
                    match0[ 4] ? 4'd4  :
                    match0[ 5] ? 4'd5  :
                    match0[ 6] ? 4'd6  :
                    match0[ 7] ? 4'd7  :
                    match0[ 8] ? 4'd8  :
                    match0[ 9] ? 4'd9  :
                    match0[10] ? 4'd10 :
                    match0[11] ? 4'd11 :
                    match0[12] ? 4'd12 :
                    match0[13] ? 4'd13 :
                    match0[14] ? 4'd14 :
                    match0[15] ? 4'd15 :
                    4'd0;

assign s1_index =   match1[ 1] ? 4'd1  :
                    match1[ 2] ? 4'd2  :
                    match1[ 3] ? 4'd3  :
                    match1[ 4] ? 4'd4  :
                    match1[ 5] ? 4'd5  :
                    match1[ 6] ? 4'd6  :
                    match1[ 7] ? 4'd7  :
                    match1[ 8] ? 4'd8  :
                    match1[ 9] ? 4'd9  :
                    match1[10] ? 4'd10 :
                    match1[11] ? 4'd11 :
                    match1[12] ? 4'd12 :
                    match1[13] ? 4'd13 :
                    match1[14] ? 4'd14 :
                    match1[15] ? 4'd15 :
                    4'd0;
//����va_bit12��һЩ˵����
//va_bit12ֻ����mmu��ʱ����õ�������ȷ���������żҳ;������searchʱ��ֻ���ҵ�index��found����
//���ù�va_bit12
////ͨ���Ƚ�matchΪȡָ�ͷô�˿ڶ��ҵ�ƫ�ƣ�Ȼ���������ƫ��ȥ�Ҷ�Ӧ�ı���

assign s0_page  = tlb_ps4MB[s0_index] ? s0_vppn[8] : s0_va_bit12;
assign s0_ps    = tlb_ps4MB[s0_index] ? 6'd22 : 6'd12;
assign s0_ppn   = s0_page ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
assign s0_plv   = s0_page ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
assign s0_mat   = s0_page ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
assign s0_d     = s0_page ? tlb_d1  [s0_index] : tlb_d0  [s0_index];
assign s0_v     = s0_page ? tlb_v1  [s0_index] : tlb_v0  [s0_index];


assign s1_page  = tlb_ps4MB[s1_index] ? s1_vppn[8] : s1_va_bit12;
assign s1_ps    = tlb_ps4MB[s1_index] ? 6'd22 : 6'd12;
assign s1_ppn   = s1_page ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
assign s1_plv   = s1_page ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
assign s1_mat   = s1_page ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
assign s1_d     = s1_page ? tlb_d1  [s1_index] : tlb_d0  [s1_index];
assign s1_v     = s1_page ? tlb_v1  [s1_index] : tlb_v0  [s1_index];

//---------д��-----------
wire [TLBNUM-1:0] mask [31:0];
integer j;
always @ (posedge clk) begin
    if (we) begin
        tlb_e      [w_index] <= w_e;
        tlb_ps4MB  [w_index] <= (w_ps == 6'd22);
        tlb_vppn   [w_index] <= w_vppn;
        tlb_asid   [w_index] <= w_asid;
        tlb_g      [w_index] <= w_g;
        tlb_ppn0   [w_index] <= w_ppn0;
        tlb_plv0   [w_index] <= w_plv0;
        tlb_mat0   [w_index] <= w_mat0;
        tlb_d0     [w_index] <= w_d0;
        tlb_v0     [w_index] <= w_v0;
        tlb_ppn1   [w_index] <= w_ppn1;
        tlb_plv1   [w_index] <= w_plv1;
        tlb_mat1   [w_index] <= w_mat1;
        tlb_d1     [w_index] <= w_d1;
        tlb_v1     [w_index] <= w_v1;
    end else if(invtlb_valid) begin
        tlb_e <= tlb_e & mask[invtlb_op];//ʹ������ʵ��E����Ч��
    end 
end

//---------INVTLB-----------
wire [TLBNUM-1:0] cond1;
wire [TLBNUM-1:0] cond2;
wire [TLBNUM-1:0] cond3;
wire [TLBNUM-1:0] cond4;
wire [TLBNUM-1:0] mask [31:0];
generate
    for (i = 0;i < TLBNUM;i = i + 1) begin : y
       assign cond1[i] = ~tlb_g[i];
       assign cond2[i] =  tlb_g[i];
       assign cond3[i] = s1_asid == tlb_asid[i];
       assign cond4[i] = (s1_vppn[18:10] == tlb_vppn[i][18:10])&&(tlb_ps4MB[i]||(s1_vppn[9:0] == tlb_vppn[i][9:0]));
    end
endgenerate
assign mask[0] = 16'd0;  
assign mask[1] = 16'd0;
assign mask[2] = ~cond2;
assign mask[3] = ~cond1;
assign mask[4] = ~cond1 | ~cond3;
assign mask[5] = ~cond1 | ~cond3 | ~cond4;
assign mask[6] = ~cond1 & ~cond3 | ~cond4;
generate
    for (i = 7; i < 32; i = i + 1) begin : z
        assign mask[i] = 16'hffff;
    end
endgenerate

//---------��ȡ-----------
assign r_e    = tlb_e    [r_index];
assign r_vppn = tlb_vppn [r_index];
assign r_ps   = tlb_ps4MB[r_index] ? 6'd22 : 6'd12;
assign r_asid = tlb_asid [r_index];
assign r_g    = tlb_g    [r_index];
assign r_ppn0 = tlb_ppn0 [r_index];
assign r_plv0 = tlb_plv0 [r_index];
assign r_mat0 = tlb_mat0 [r_index];
assign r_d0   = tlb_d0   [r_index];
assign r_v0   = tlb_v0   [r_index];
assign r_ppn1 = tlb_ppn1 [r_index];
assign r_plv1 = tlb_plv1 [r_index];
assign r_mat1 = tlb_mat1 [r_index];
assign r_d1   = tlb_d1   [r_index];
assign r_v1   = tlb_v1   [r_index];

endmodule