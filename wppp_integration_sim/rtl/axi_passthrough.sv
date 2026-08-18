module axi_passthrough (
    axi_ports.ar_resp upstream_r,
    axi_ports.aw_resp upstream_w,
    axi_ports.ar_req  downstream_r,
    axi_ports.aw_req  downstream_w
);
    assign downstream_r.arid     = upstream_r.arid;
    assign downstream_r.araddr   = upstream_r.araddr;
    assign downstream_r.arlen    = upstream_r.arlen;
    assign downstream_r.arsize   = upstream_r.arsize;
    assign downstream_r.arburst  = upstream_r.arburst;
    assign downstream_r.arprot   = upstream_r.arprot;
    assign downstream_r.arqos    = upstream_r.arqos;
    assign downstream_r.aruser   = upstream_r.aruser;
    assign downstream_r.arvalid  = upstream_r.arvalid;
    assign downstream_r.arcache  = upstream_r.arcache;
    assign downstream_r.arlock   = upstream_r.arlock;
    assign downstream_r.arregion = upstream_r.arregion;
    assign upstream_r.arready     = downstream_r.arready;

    assign upstream_r.rid        = downstream_r.rid;
    assign upstream_r.rdata      = downstream_r.rdata;
    assign upstream_r.rresp      = downstream_r.rresp;
    assign upstream_r.rlast      = downstream_r.rlast;
    assign upstream_r.ruser      = downstream_r.ruser;
    assign upstream_r.rvalid     = downstream_r.rvalid;
    assign downstream_r.rready   = upstream_r.rready;

    assign downstream_w.awid     = upstream_w.awid;
    assign downstream_w.awaddr   = upstream_w.awaddr;
    assign downstream_w.awlen    = upstream_w.awlen;
    assign downstream_w.awsize   = upstream_w.awsize;
    assign downstream_w.awburst  = upstream_w.awburst;
    assign downstream_w.awprot   = upstream_w.awprot;
    assign downstream_w.awqos    = upstream_w.awqos;
    assign downstream_w.awuser   = upstream_w.awuser;
    assign downstream_w.awvalid  = upstream_w.awvalid;
    assign downstream_w.awcache  = upstream_w.awcache;
    assign downstream_w.awlock   = upstream_w.awlock;
    assign downstream_w.awregion = upstream_w.awregion;
    assign downstream_w.awatop   = upstream_w.awatop;
    assign upstream_w.awready     = downstream_w.awready;

    assign downstream_w.wdata    = upstream_w.wdata;
    assign downstream_w.wstrb    = upstream_w.wstrb;
    assign downstream_w.wlast    = upstream_w.wlast;
    assign downstream_w.wuser    = upstream_w.wuser;
    assign downstream_w.wvalid   = upstream_w.wvalid;
    assign upstream_w.wready      = downstream_w.wready;

    assign upstream_w.bid        = downstream_w.bid;
    assign upstream_w.bresp      = downstream_w.bresp;
    assign upstream_w.buser      = downstream_w.buser;
    assign upstream_w.bvalid     = downstream_w.bvalid;
    assign downstream_w.bready   = upstream_w.bready;
endmodule

module axi_read_passthrough (
    axi_ports.ar_resp upstream_r,
    axi_ports.ar_req  downstream_r
);
    assign downstream_r.arid     = upstream_r.arid;
    assign downstream_r.araddr   = upstream_r.araddr;
    assign downstream_r.arlen    = upstream_r.arlen;
    assign downstream_r.arsize   = upstream_r.arsize;
    assign downstream_r.arburst  = upstream_r.arburst;
    assign downstream_r.arprot   = upstream_r.arprot;
    assign downstream_r.arqos    = upstream_r.arqos;
    assign downstream_r.aruser   = upstream_r.aruser;
    assign downstream_r.arvalid  = upstream_r.arvalid;
    assign downstream_r.arcache  = upstream_r.arcache;
    assign downstream_r.arlock   = upstream_r.arlock;
    assign downstream_r.arregion = upstream_r.arregion;
    assign upstream_r.arready     = downstream_r.arready;

    assign upstream_r.rid        = downstream_r.rid;
    assign upstream_r.rdata      = downstream_r.rdata;
    assign upstream_r.rresp      = downstream_r.rresp;
    assign upstream_r.rlast      = downstream_r.rlast;
    assign upstream_r.ruser      = downstream_r.ruser;
    assign upstream_r.rvalid     = downstream_r.rvalid;
    assign downstream_r.rready   = upstream_r.rready;
endmodule
