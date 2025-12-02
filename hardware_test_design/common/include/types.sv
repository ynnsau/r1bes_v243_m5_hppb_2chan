package mig_params;
    // HOT PAGE PUSHING SIGNALS
    localparam ACTUAL_MIG_GRP_SIZE = 32;
    localparam MIG_GRP_SIZE = ACTUAL_MIG_GRP_SIZE;          // MAX allowed = 8, ARID constraint  
    localparam PG_NUM_ENTRIES = 4096*8/512;
endpackage

package m5_pkg;
    // 34 + 2 = 36 bits
    typedef struct packed {
        logic [33:0] araddr;
        logic arvalid;
        logic arready;
    } queue_struct_t;
endpackage

package prefetch_read_write_pkg;
    typedef enum logic [4:0]{
        STATE_RESET, // prefetch is idle
        STATE_RD_ADDR, // prefetch issue read address
        STATE_RD_DATA, // prefetch reads in data and stores it in a reg
        STATE_WR_SUB, // prefetch issues write sub-request (issue ncp)
        STATE_WR_SUB_RESP // prefetch receives write sub-request response, write channel is ready to reuse
        // any additional states?
    } prefetch_rw_state_t;

    typedef enum logic [4:0]{
        IDLE = 5'd0,
        DB_READ_ADDR = 5'd1,
        DB_READ_DATA = 5'd2,
        HB_READ_ADDR = 5'd3,
        HB_READ_DATA = 5'd4,
        NCP_CHECK = 5'd5,
        NCP_WRITE = 5'd6,
        NCP_ABORT = 5'd7,
        NCP_WRITE_RESP = 5'd8,
        HB_VALID_CHECK = 5'd9,
        ABORT_HB_VALID_CHECK = 5'd10,
        WAIT_LOW_RVALID = 5'd11,

        NCP_WRITE_DATA = 5'd12,
        WRITE_RESP_TIMEOUT = 5'd13
    } prefetch_rw_v2_state_t;
endpackage

package wppprefetch_pkg;
    typedef enum logic [4:0]{
        IDLE = 5'd0,
        HB_READ_ADDR = 5'd1,
        HB_READ_DATA = 5'd2,
        F_READ_ADDR = 5'd3,
        F_READ_DATA = 5'd4,
        NCP_WRITE = 5'd5,
        NCP_WRITE_DATA = 5'd6,
        HB_ABORT = 5'd7,
        F_ABORT = 5'd8,
        ABORT = 5'd9,
        LUT_WAIT = 5'd10
    } wppprefetch_rw_state_t;

    typedef struct packed {
        logic push_valid;
        logic [11:0] push_id;
        logic [63:0] push_addr;
        logic [511:0] push_data;
    } wppprefetch_rw_pipe_t;

	 typedef struct packed {
        logic [11:0] id;
        logic [63:0] addr;
        logic [511:0] data;
    } ncp_fifo_t;

    typedef struct packed {
        logic [63:0] hint_addr;
        logic [8:0] hint_num_of_cl;
    } wppp_hint_fifo_entry_t;
endpackage

package afu_rchan_track_pkg;
    typedef struct packed {
        logic [7:0] rid;
        logic [511:0] rdata;
        logic rvalid;
        logic rlast;
        logic ruser;
    } afu_rchan_track_t; // 8 + 512 + 1 + 1 + 1 = 523 bits
endpackage


interface axi_ports;

    logic [11:0]               arid;
    logic [63:0]               araddr;
    logic [9:0]                arlen;    // must tie to 10'd0
    logic [2:0]                arsize;   // must tie to 3'b110
    logic [1:0]                arburst;  // must tie to 2'b00
    logic [2:0]                arprot;   // must tie to 3'b000
    logic [3:0]                arqos;    // must tie to 4'b0000
    logic [5:0]                aruser;   // 4'b0000": non-cacheable; 4'b0001: cacheable shared; 4'b0010: cacheable owned
    logic                      arvalid;
    logic [3:0]                arcache;  // must tie to 4'b0000
    logic [1:0]                arlock;   // must tie to 2'b00
    logic [3:0]                arregion; // must tie to 4'b0000
    logic                      arready;

    logic [11:0]               rid;
    logic [511:0]              rdata;  
    logic [1:0]                rresp;  // no use: 2'b00: OKAY; 2'b01: EXOKAY; 2'b10: SLVERR
    logic                      rlast;  // no use
    logic                      ruser;  // no use
    logic                      rvalid;
    logic                      rready;

    logic [11:0]               awid;
    logic [63:0]               awaddr; 
    logic [9:0]                awlen;    // must tie to 10'd0
    logic [2:0]                awsize;   // must tie to 3'b110 (64B/T)
    logic [1:0]                awburst;  // must tie to 2'b00            : CXL IP limitation
    logic [2:0]                awprot;   // must tie to 3'b000
    logic [3:0]                awqos;    // must tie to 4'b0000
    logic [5:0]                awuser;
    logic                      awvalid;
    logic [3:0]                awcache;  // must tie to 4'b0000
    logic [1:0]                awlock;   // must tie to 2'b00
    logic [3:0]                awregion; // must tie to 4'b0000
    logic [5:0]                awatop;   // must tie to 6'b000000
    logic                      awready;

    logic [511:0]              wdata;
    logic [(512/8)-1:0]        wstrb;
    logic                      wlast;
    logic                      wuser;  // must tie to 1'b0
    logic                      wvalid;
    logic                      wready;

    logic [11:0]               bid;
    logic [1:0]                bresp;  // no use: 2'b00: OKAY; 2'b01: EXOKAY; 2'b10: SLVERR
    logic [3:0]                buser;  // must tie to 4'b0000
    logic                      bvalid;
    logic                      bready;

    modport ar_req(
        output              arid,
        output              araddr,
        output              arlen,    // must tie to 10'd0
        output              arsize,   // must tie to 3'b110
        output              arburst,  // must tie to 2'b00
        output              arprot,   // must tie to 3'b000
        output              arqos,    // must tie to 4'b0000
        output              aruser,   // 4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cacheable owned
        output              arvalid,
        output              arcache,  // must tie to 4'b0000
        output              arlock,   // must tie to 2'b00
        output              arregion, // must tie to 4'b0000
        input               arready,

        input               rid,
        input               rdata,  
        input               rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
        input               rlast,  // no use
        input               ruser,  // no use
        input               rvalid,
        output              rready
    );

    modport ar_resp(
        input               arid,
        input               araddr,
        input               arlen,    // must tie to 10'd0
        input               arsize,   // must tie to 3'b110
        input               arburst,  // must tie to 2'b00
        input               arprot,   // must tie to 3'b000
        input               arqos,    // must tie to 4'b0000
        input               aruser,   // 4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cacheable owned
        input               arvalid,
        input               arcache,  // must tie to 4'b0000
        input               arlock,   // must tie to 2'b00
        input               arregion, // must tie to 4'b0000
        output              arready,

        output              rid,
        output              rdata,  
        output              rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
        output              rlast,  // no use
        output              ruser,  // no use
        output              rvalid,
        input               rready
    );

    modport aw_req(
        output              awid,
        output              awaddr, 
        output              awlen,    // must tie to 10'd0
        output              awsize,   // must tie to 3'b110 (64B/T)
        output              awburst,  // must tie to 2'b00            : CXL IP limitation
        output              awprot,   // must tie to 3'b000
        output              awqos,    // must tie to 4'b0000
        output              awuser,
        output              awvalid,
        output              awcache,  // must tie to 4'b0000
        output              awlock,   // must tie to 2'b00
        output              awregion, // must tie to 4'b0000
        output              awatop,   // must tie to 6'b000000
        input               awready,

        output              wdata,
        output              wstrb,
        output              wlast,
        output              wuser,  // must tie to 1'b0
        output              wvalid,
        input               wready,

        input               bid,
        input               bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
        input               buser,  // must tie to 4'b0000
        input               bvalid,
        output              bready
    );

    modport aw_resp(
        input               awid,
        input               awaddr, 
        input               awlen,    // must tie to 10'd0
        input               awsize,   // must tie to 3'b110 (64B/T)
        input               awburst,  // must tie to 2'b00            : CXL IP limitation
        input               awprot,   // must tie to 3'b000
        input               awqos,    // must tie to 4'b0000
        input               awuser,
        input               awvalid,
        input               awcache,  // must tie to 4'b0000
        input               awlock,   // must tie to 2'b00
        input               awregion, // must tie to 4'b0000
        input               awatop,   // must tie to 6'b000000
        output              awready,

        input               wdata,
        input               wstrb,
        input               wlast,
        input               wuser,  // must tie to 1'b0
        input               wvalid,
        output              wready,

        output              bid,
        output              bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
        output              buser,  // must tie to 4'b0000
        output              bvalid,
        input               bready
    );

endinterface


module axi_r_stub(axi_ports.ar_req axi_r_ch);
    assign axi_r_ch.arvalid = 1'b0;
endmodule

module axi_w_stub(axi_ports.aw_req axi_w_ch);
    assign axi_w_ch.awvalid = 1'b0;
    assign axi_w_ch.wvalid = 1'b0;
endmodule
