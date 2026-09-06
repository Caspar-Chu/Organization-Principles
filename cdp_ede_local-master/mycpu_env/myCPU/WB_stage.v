`include "mycpu_head.v"

module WB_stage(
    input  wire                          clk,
    input  wire                          reset,
    // allowin
    output wire                          ws_allowin,
    // from mem stage
    input  wire                          ms_to_ws_valid,
    input  wire [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus,
    // to rf: for write back
    output wire [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus,
    // trace debug interface
    output wire [31:0]                   debug_wb_pc,
    output wire [ 3:0]                   debug_wb_rf_we,
    output wire [ 4:0]                   debug_wb_rf_wnum,
    output wire [31:0]                   debug_wb_rf_wdata
);

reg         ws_valid;
wire        ws_ready_go;

reg  [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus_r;

wire        gr_we;
wire [ 4:0] dest;
wire [31:0] final_result;
wire [31:0] ws_pc;

wire        rf_we;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

assign {gr_we       ,
        dest        ,
        final_result,
        ws_pc
       } = ms_to_ws_bus_r;

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;

assign rf_we    = gr_we && ws_valid;
assign rf_waddr = dest;
assign rf_wdata = final_result;

assign ws_to_rf_bus = {rf_we, rf_waddr, rf_wdata};

assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

endmodule
