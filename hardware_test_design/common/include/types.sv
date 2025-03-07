package mig_params;
    localparam MIG_GRP_SIZE = 2;          // MAX allowed = 8, ARID constraint  
    localparam MIG_REGION_SIZE = 16*1024*1024;    // 16MB?
    localparam PG_NUM_ENTRIES = 4096*8/512;
    localparam MIG_GRP_ID_SIZE = MIG_GRP_SIZE == 1 ? 0 : ($clog2(MIG_GRP_SIZE)-1);
    localparam PG_ENTRY_OFFSET_SIZE = $clog2(PG_NUM_ENTRIES)-1; // == 5
endpackage

package m5_pkg;
    // 34 + 2 = 36 bits
    typedef struct packed {
        logic [33:0] araddr;
        logic arvalid;
        logic arready;
    } queue_struct_t;
endpackage
