`include "mycpu_head.v"

module IF_stage(
    input  wire                          clk,
    input  wire                          reset,
    input  wire                          ds_allowin,
    input  wire [`BR_BUS_WD       -1:0]  br_bus,
    output wire                          fs_to_ds_valid,
    output wire [`FS_TO_DS_BUS_WD -1:0]  fs_to_ds_bus,
    // inst sram interface
    output wire                          inst_sram_en,
    output wire [ 3:0]                   inst_sram_we,
    output wire [31:0]                   inst_sram_addr,
    output wire [31:0]                   inst_sram_wdata,
    input  wire [31:0]                   inst_sram_rdata
);

reg         fs_valid;
reg         fs_refill; // 分支冲刷后需要重新取 fs_pc，而不是 fs_pc+4
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] next_pc;

wire        br_taken;
wire [31:0] br_target;

assign {br_taken, br_target} = br_bus;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;

assign fs_to_ds_bus = {fs_inst, fs_pc};

assign to_fs_valid = ~reset;
assign seq_pc      = fs_pc + 32'h4;

// br_taken: 取目标
// fs_refill: 冲刷后重取当前 fs_pc（同步 RAM 关键）
// 其余: 取下一条 seq_pc
assign next_pc = br_taken  ? br_target :
                 fs_refill ? fs_pc     :
                             seq_pc;

assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || (fs_ready_go && ds_allowin);
assign fs_to_ds_valid = fs_valid && fs_ready_go && !br_taken;

always @(posedge clk) begin
    if (reset) begin
        fs_valid  <= 1'b0;
        fs_refill <= 1'b0;
    end
    else if (br_taken) begin
        fs_valid  <= 1'b0;
        fs_refill <= 1'b1;
    end
    else if (fs_allowin) begin
        fs_valid  <= to_fs_valid;
        if (to_fs_valid)
            fs_refill <= 1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1bfffffc;
    end
    else if (br_taken) begin
        fs_pc <= br_target;
    end
    else if (to_fs_valid && fs_allowin) begin
        if (fs_valid) begin
            fs_pc <= seq_pc;
        end
        else if (!fs_refill) begin
            // 复位后第一次进入 IF：PC 从 1bfffffc 进入 1c000000
            fs_pc <= next_pc;
        end
        // fs_refill 时 fs_pc 已是分支目标，保持不变
    end
end

assign inst_sram_en    = to_fs_valid && (fs_allowin || fs_refill);
assign inst_sram_we    = 4'h0;
assign inst_sram_addr  = next_pc;
assign inst_sram_wdata = 32'b0;

assign fs_inst = inst_sram_rdata;

endmodule
