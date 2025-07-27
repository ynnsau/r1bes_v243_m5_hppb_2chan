package func_offload_params;

    typedef enum logic [1:0] {
        func_in_args  = 2'b00,
        func_read_offset  = 2'b01,
        func_read_entry  = 2'b10,
        func_out_val  = 2'b11
    } func_offload_mem_req_type;

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
