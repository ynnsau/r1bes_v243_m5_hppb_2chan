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
