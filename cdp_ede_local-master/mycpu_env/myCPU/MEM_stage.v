`include "mycpu_head.v"

module MEM_stage(
    input  wire                          clk,
    input  wire                          reset,
    // allowin
    input  wire                          ws_allowin,
    output wire                          ms_allowin,
    // from exe stage
    input  wire                          es_to_ms_valid,
    input  wire [`ES_TO_MS_BUS_WD -1:0]  es_to_ms_bus,
    // to wb stage
    output wire                          ms_to_ws_valid,
    output wire [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus,
    // from data sram
    input  wire [31:0]                   data_sram_rdata
);

reg         ms_valid;
wire        ms_ready_go;

reg  [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus_r;

wire        res_from_mem;
wire        gr_we;
wire [ 4:0] dest;
wire [31:0] alu_result;
wire [31:0] ms_pc;

wire [31:0] mem_result;
wire [31:0] final_result;

assign {res_from_mem,
        gr_we       ,
        dest        ,
        alu_result  ,
        ms_pc
       } = es_to_ms_bus_r;

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;

assign ms_to_ws_bus = {gr_we       , // 69
                       dest        , // 68:64
                       final_result, // 63:32
                       ms_pc         // 31:0
                      };

always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end

endmodule
