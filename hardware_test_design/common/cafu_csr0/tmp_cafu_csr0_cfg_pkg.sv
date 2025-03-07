// (C) 2001-2024 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// Copyright 2023 Intel Corporation.
//
// THIS SOFTWARE MAY CONTAIN PREPRODUCTION CODE AND IS PROVIDED BY THE
// COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
// OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
///////////////////////////////////////////////////////////////////////
//                                                                             


`ifndef TMP_CAFU_CSR0_CFG_PKG
`define TMP_CAFU_CSR0_CFG_PKG

package tmp_cafu_csr0_cfg_pkg;

//================================================
// register structs



typedef struct packed {
   logic treg_trdy; 
   logic treg_cerr;   
   logic [63:0] treg_rdata;
} tmp_cafu_csr0_cfg_sb_ack_t;

typedef struct packed {
    logic [11:0] next_cap_offset;  // RO
    logic  [3:0] dvsec_cap_version;  // RO
    logic [15:0] dvsec_cap_id;  // RO
} tmp_DVSEC_DEV_t;

typedef struct packed {
    logic [11:0] dvsec_length;  // RO
    logic  [3:0] dvsec_revision;  // RO
    logic [15:0] dvsec_vendor_id;  // RO
} tmp_DVSEC_HDR1_t;

typedef struct packed {
    logic  [0:0] pm_init_comp_capable;  // RO
    logic  [0:0] viral_capable;  // RO
    logic  [0:0] mld;  // RO
    logic  [0:0] reserved0;  // RSVD
    logic  [0:0] cxl_reset_mem_clr_capable;  // RO
    logic  [2:0] cxl_reset_timeout;  // RO
    logic  [0:0] cxl_reset_capable;  // RO
    logic  [0:0] cache_wb_and_inv_capable;  // RO
    logic  [1:0] hdm_count;  // RO
    logic  [0:0] mem_hwInit_mode;  // RO
    logic  [0:0] mem_capable;  // RO
    logic  [0:0] io_capable;  // RO
    logic  [0:0] cache_capable;  // RO
    logic [15:0] dvsec_id;  // RO
} tmp_DVSEC_FBCAP_HDR2_t;

typedef struct packed {
    logic  [0:0] reserved0;  // RSVD
    logic  [0:0] viral_status;  // RW/1C/V/P
    logic [14:0] reserved1;  // RSVD
    logic  [0:0] viral_enable;  // RW/L
    logic  [1:0] reserved2;  // RSVD
    logic  [0:0] cache_clean_eviction;  // RW/L
    logic  [2:0] cache_sf_granularity;  // RW/L
    logic  [4:0] cache_sf_coverage;  // RW/L
    logic  [0:0] mem_enable;  // RW/L
    logic  [0:0] io_enable;  // RO
    logic  [0:0] cache_enable;  // RW/L
} tmp_DVSEC_FBCTRL_STATUS_t;

typedef struct packed {
    logic  [0:0] power_mgt_init_complete;  // RO/V
    logic [11:0] reserved0;  // RSVD
    logic  [0:0] cxl_reset_error;  // RO/V
    logic  [0:0] cxl_reset_complete;  // RO/V
    logic  [0:0] cache_invalid;  // RO/V
    logic [11:0] reserved1;  // RSVD
    logic  [0:0] cxl_reset_mem_clr_enable;  // RW
    logic  [0:0] initiate_cxl_reset;  // RW/1S/V
    logic  [0:0] initiate_cache_wb_and_inv;  // RW/1S/V
    logic  [0:0] disable_caching;  // RW
} tmp_DVSEC_FBCTRL2_STATUS2_t;

typedef struct packed {
    logic  [7:0] cache_size;  // RO
    logic  [3:0] reserved0;  // RSVD
    logic  [3:0] cache_size_unit;  // RO
    logic [14:0] reserved1;  // RSVD
    logic  [0:0] config_lock;  // RW/L
} tmp_DVSEC_FBLOCK_t;

typedef struct packed {
    logic [31:0] memory_size;  // RO
} tmp_DVSEC_FBRANGE1SZHIGH_t;

typedef struct packed {
    logic  [3:0] memory_size_low;  // RO
    logic [11:0] reserved0;  // RSVD
    logic  [2:0] memory_active_timeout;  // RO
    logic  [1:0] reserved1;  // RSVD
    logic  [2:0] desired_interleave;  // RO
    logic  [2:0] memory_class;  // RO
    logic  [2:0] media_type;  // RO
    logic  [0:0] mem_active;  // RO
    logic  [0:0] mem_valid;  // RO
} tmp_DVSEC_FBRANGE1SZLOW_t;

typedef struct packed {
    logic [31:0] memory_base_high;  // RW/L
} tmp_DVSEC_FBRANGE1HIGH_t;

typedef struct packed {
    logic  [3:0] memory_base_low;  // RW/L
    logic [27:0] reserved0;  // RSVD
} tmp_DVSEC_FBRANGE1LOW_t;

typedef struct packed {
    logic [31:0] memory_size;  // RO
} tmp_DVSEC_FBRANGE2SZHIGH_t;

typedef struct packed {
    logic  [3:0] memory_size_low;  // RO
    logic [11:0] reserved0;  // RSVD
    logic  [2:0] memory_active_timeout;  // RO
    logic  [1:0] reserved1;  // RSVD
    logic  [2:0] desired_interleave;  // RO
    logic  [2:0] memory_class;  // RO
    logic  [2:0] media_type;  // RO
    logic  [0:0] mem_active;  // RO
    logic  [0:0] mem_valid;  // RO
} tmp_DVSEC_FBRANGE2SZLOW_t;

typedef struct packed {
    logic [31:0] memory_base_high;  // RW/L
} tmp_DVSEC_FBRANGE2HIGH_t;

typedef struct packed {
    logic  [3:0] memory_base_low;  // RW/L
    logic [27:0] reserved0;  // RSVD
} tmp_DVSEC_FBRANGE2LOW_t;

typedef struct packed {
    logic [11:0] next_cap_offset;  // RO
    logic  [3:0] dvsec_cap_version;  // RO
    logic [15:0] dvsec_cap_id;  // RO
} tmp_DVSEC_DOE_t;

typedef struct packed {
    logic [19:0] reserved0;  // RSVD
    logic [10:0] doe_int_msg;  // RO
    logic  [0:0] doe_int_support;  // RO
} tmp_DOE_CAPREG_t;

typedef struct packed {
    logic  [0:0] doe_go;  // RW/V
    logic [28:0] reserved0;  // RSVD
    logic  [0:0] doe_int_enb;  // RW
    logic  [0:0] doe_abort;  // RW/V
} tmp_DOE_CTLREG_t;

typedef struct packed {
    logic  [0:0] data_object_ready;  // RO/V
    logic [27:0] reserved0;  // RSVD
    logic  [0:0] doe_error;  // RO/V
    logic  [0:0] doe_int_status;  // RW/1C/V
    logic  [0:0] doe_busy;  // RO/V
} tmp_DOE_STSREG_t;

typedef struct packed {
    logic [31:0] doe_wr_data_mailbox;  // RW/V
} tmp_DOE_WRMAILREG_t;

typedef struct packed {
    logic [31:0] doe_rd_data_mailbox;  // RW/V
} tmp_DOE_RDMAILREG_t;

typedef struct packed {
    logic [11:0] next_cap_offset;  // RO
    logic  [3:0] test_cap_version;  // RO
    logic [15:0] test_cap_id;  // RO
} tmp_DVSEC_TEST_CAP_t;

typedef struct packed {
    logic [11:0] dvsec_length;  // RO
    logic  [3:0] dvsec_revision;  // RO
    logic [15:0] dvsec_vend_id;  // RO
} tmp_CXL_DVSEC_HEADER_1_t;

typedef struct packed {
    logic [15:0] dvsec_id;  // RO
} tmp_CXL_DVSEC_HEADER_2_t;

typedef struct packed {
    logic [14:0] reserved0;  // RSVD
    logic  [0:0] test_config_lock;  // RW/L
} tmp_CXL_DVSEC_TEST_LOCK_t;

typedef struct packed {
    logic  [7:0] test_config_size;  // RO
    logic  [2:0] reserved0;  // RSVD
    logic  [0:0] cmplte_timeout_injection;  // RO
    logic  [0:0] unexpect_cmpletion;  // RO
    logic  [0:0] cache_flushed;  // RO
    logic  [0:0] cache_wr_inv;  // RO
    logic  [0:0] cache_wow_invf;  // RO
    logic  [0:0] cache_wow_inv;  // RO
    logic  [0:0] cache_clean_evict_nodata;  // RO
    logic  [0:0] cache_dirty_evict;  // RO
    logic  [0:0] cache_clean_evict;  // RO
    logic  [0:0] cache_cl_flush;  // RO
    logic  [0:0] cache_mem_wr;  // RO
    logic  [0:0] cache_itom_wr;  // RO
    logic  [0:0] cache_rdown_nodata;  // RO
    logic  [0:0] cache_rdany;  // RO
    logic  [0:0] cache_rdshared;  // RO
    logic  [0:0] cache_rdown;  // RO
    logic  [0:0] cache_rdcurrent;  // RO
    logic  [0:0] algotype_2;  // RO
    logic  [0:0] algotype_1b;  // RO
    logic  [0:0] algotype_1a;  // RO
    logic  [0:0] algo_selfcheck_enb;  // RO
} tmp_CXL_DVSEC_TEST_CAP1_t;

typedef struct packed {
    logic  [1:0] cache_size_unit;  // RO
    logic [13:0] cache_size_device;  // RO
} tmp_CXL_DVSEC_TEST_CAP2_t;

typedef struct packed {
    logic [27:0] test_config_base_low;  // RO/V
    logic  [0:0] reserved0;  // RSVD
    logic  [1:0] base_reg_type;  // RO
    logic  [0:0] mem_space_indicator;  // RO
} tmp_CXL_DVSEC_TEST_CNF_BASE_LOW_t;

typedef struct packed {
    logic [31:0] test_config_base_high;  // RO/V
} tmp_CXL_DVSEC_TEST_CNF_BASE_HIGH_t;

typedef struct packed {
    logic [11:0] next_cap_offset;  // RO
    logic  [3:0] dvsec_cap_version;  // RO
    logic [15:0] dvsec_cap_id;  // RO
} tmp_DVSEC_GPF_t;

typedef struct packed {
    logic [11:0] dvsec_length;  // RO
    logic  [3:0] dvsec_revision;  // RO
    logic [15:0] dvsec_vendor_id;  // RO
} tmp_DVSEC_GPF_HDR1_t;

typedef struct packed {
    logic  [3:0] reserved0;  // RSVD
    logic  [3:0] gpf_time_scale;  // RO
    logic  [3:0] reserved1;  // RSVD
    logic  [3:0] gpf_time_base;  // RO
    logic [15:0] dvsec_id;  // RO
} tmp_DVSEC_GPF_PH2DUR_HDR2_t;

typedef struct packed {
    logic [31:0] gpf_active_power;  // RO
} tmp_DVSEC_GPF_PH2PWR_t;

typedef struct packed {
    logic  [3:0] reserved0;  // RSVD
    logic  [3:0] dtype;  // RO
    logic  [7:0] version;  // RO
    logic [15:0] cap_id;  // RO
} tmp_CXL_DEV_CAP_ARRAY_0_t;

typedef struct packed {
    logic [15:0] reserved0;  // RSVD
    logic [15:0] cap_cnt;  // RO
} tmp_CXL_DEV_CAP_ARRAY_1_t;

typedef struct packed {
    logic  [7:0] reserved0;  // RSVD
    logic  [7:0] version;  // RO
    logic [15:0] cap_id;  // RO
} tmp_CXL_DEV_CAP_HDR1_0_t;

typedef struct packed {
    logic [31:0] offset;  // RO
} tmp_CXL_DEV_CAP_HDR1_1_t;

typedef struct packed {
    logic [31:0] length;  // RO
} tmp_CXL_DEV_CAP_HDR1_2_t;

typedef struct packed {
    logic  [7:0] reserved0;  // RSVD
    logic  [7:0] version;  // RO
    logic [15:0] cap_id;  // RO
} tmp_CXL_DEV_CAP_HDR2_0_t;

typedef struct packed {
    logic [31:0] offset;  // RO
} tmp_CXL_DEV_CAP_HDR2_1_t;

typedef struct packed {
    logic [31:0] length;  // RO
} tmp_CXL_DEV_CAP_HDR2_2_t;

typedef struct packed {
    logic  [7:0] reserved0;  // RSVD
    logic  [7:0] version;  // RO
    logic [15:0] cap_id;  // RO
} tmp_CXL_DEV_CAP_HDR3_0_t;

typedef struct packed {
    logic [31:0] offset;  // RO
} tmp_CXL_DEV_CAP_HDR3_1_t;

typedef struct packed {
    logic [31:0] length;  // RO
} tmp_CXL_DEV_CAP_HDR3_2_t;

typedef struct packed {
    logic [27:0] reserved0;  // RSVD
    logic  [0:0] fatal_event_log;  // RO/V
    logic  [0:0] failure_event_log;  // RO/V
    logic  [0:0] warning_event_log;  // RO/V
    logic  [0:0] info_event_log;  // RO/V
} tmp_CXL_DEV_CAP_EVENT_STATUS_t;

typedef struct packed {
    logic [23:0] reserved0;  // RSVD
    logic  [2:0] reset_needed;  // RO/V
    logic  [0:0] mailbox_if_ready;  // RO/V
    logic  [1:0] media_status;  // RO/V
    logic  [0:0] fw_halt;  // RO/V
    logic  [0:0] device_fatal;  // RO/V
} tmp_CXL_MEM_DEV_STATUS_t;

typedef struct packed {
    logic [20:0] reserved0;  // RSVD
    logic  [3:0] int_msg_num;  // RO
    logic  [0:0] bk_cmd_comp_int_cap;  // RO
    logic  [0:0] mb_doorbell_int_cap;  // RO
    logic  [4:0] payload_size;  // RO
} tmp_CXL_MB_CAP_t;

typedef struct packed {
    logic [28:0] reserved0;  // RSVD
    logic  [0:0] bk_cmd_comp_int;  // RW
    logic  [0:0] mb_doorbell_int;  // RW
    logic  [0:0] doorbell;  // RW/V
} tmp_CXL_MB_CTRL_t;

typedef struct packed {
    logic [26:0] reserved0;  // RSVD
    logic [20:0] payload_len;  // RW/V
    logic [15:0] command_op;  // RW
} tmp_CXL_MB_CMD_t;

typedef struct packed {
    logic [15:0] vendor_specfic_ext_status;  // RO/V
    logic [15:0] return_code;  // RO/V
    logic [30:0] reserved0;  // RSVD
    logic  [0:0] bk_operation;  // RO/V
} tmp_CXL_MB_STATUS_t;

typedef struct packed {
    logic [15:0] vendor_specfic_ext_status;  // RO/V
    logic [15:0] return_code;  // RO/V
    logic  [8:0] reserved0;  // RSVD
    logic  [6:0] percentage_comp;  // RO/V
    logic [15:0] cmd_opcode;  // RO/V
} tmp_CXL_MB_BK_CMD_STATUS_t;

typedef struct packed {
    logic [31:0] mailbox_payload_start;  // RW
} tmp_CXL_MB_PAY_START_t;

typedef struct packed {
    logic [31:0] mailbox_payload_end;  // RW
} tmp_CXL_MB_PAY_END_t;

typedef struct packed {
    logic [18:0] reserved0;  // RSVD
    logic  [0:0] support_16_way;  // RO
    logic  [0:0] support_3_6_12_way;  // RO
    logic  [0:0] poison_on_err;  // RO
    logic  [0:0] addr14_12;  // RO
    logic  [0:0] addr11_8;  // RO
    logic  [3:0] tgt_cnt;  // RO
    logic  [3:0] dec_cnt;  // RO
} tmp_HDM_DEC_CAP_t;

typedef struct packed {
    logic [29:0] reserved0;  // RSVD
    logic  [0:0] dec_enable;  // RW
    logic  [0:0] poison_on_err_enable;  // RO
} tmp_HDM_DEC_GBL_CTRL_t;

typedef struct packed {
    logic  [3:0] mem_base_low;  // RW/L
    logic [27:0] reserved0;  // RSVD
} tmp_HDM_DEC_BASELOW_t;

typedef struct packed {
    logic [31:0] mem_base_high;  // RW/L
} tmp_HDM_DEC_BASEHIGH_t;

typedef struct packed {
    logic  [3:0] mem_size_low;  // RW/L
    logic [27:0] reserved0;  // RSVD
} tmp_HDM_DEC_SIZELOW_t;

typedef struct packed {
    logic [31:0] mem_size_high;  // RW/L
} tmp_HDM_DEC_SIZEHIGH_t;

typedef struct packed {
    logic [18:0] reserved0;  // RSVD
    logic  [0:0] target_dev_type;  // RO
    logic  [0:0] err_not_committed;  // RO
    logic  [0:0] committed;  // RO/V
    logic  [0:0] commit;  // RW/L
    logic  [0:0] lock_on_commit;  // RW/L
    logic  [3:0] interleave_ways;  // RW/L
    logic  [3:0] interleave_granularity;  // RW/L
} tmp_HDM_DEC_CTRL_t;

typedef struct packed {
    logic  [3:0] dpa_skip_low;  // RW/L
    logic [27:0] reserved0;  // RSVD
} tmp_HDM_DEC_DPALOW_t;

typedef struct packed {
    logic [31:0] dpa_skip_high;  // RW/L
} tmp_HDM_DEC_DPAHIGH_t;

typedef struct packed {
    logic [11:0] reserved0;  // RSVD
    logic [51:0] config_test_start_addr;  // RW
} tmp_CONFIG_TEST_START_ADDR_t;

typedef struct packed {
    logic [11:0] reserved0;  // RSVD
    logic [51:0] config_test_wrback_addr;  // RW
} tmp_CONFIG_TEST_WR_BACK_ADDR_t;

typedef struct packed {
    logic [31:0] config_test_addr_setoffset;  // RW
    logic [31:0] config_test_addr_incre;  // RW
} tmp_CONFIG_TEST_ADDR_INCRE_t;

typedef struct packed {
    logic [31:0] algorithm_pattern2;  // RW
    logic [31:0] algorithm_pattern1;  // RW
} tmp_CONFIG_TEST_PATTERN_t;

typedef struct packed {
    logic [63:0] cacheline_bytemask;  // RW
} tmp_CONFIG_TEST_BYTEMASK_t;

typedef struct packed {
    logic [59:0] reserved0;  // RSVD
    logic  [0:0] pattern_parameter;  // RW
    logic  [2:0] pattern_size;  // RW
} tmp_CONFIG_TEST_PATTERN_PARAM_t;

typedef struct packed {
    logic [16:0] reserved0;  // RSVD
    logic  [2:0] verify_semantics_cache;  // RW
    logic  [2:0] execute_read_semantics;  // RW
    logic  [0:0] flush_cache;  // RW/L
    logic  [3:0] write_semantics_cache;  // RW
    logic  [2:0] interface_protocol_type;  // RW
    logic  [0:0] address_is_virtual;  // RW
    logic  [7:0] num_of_loops;  // RW
    logic  [7:0] num_of_sets;  // RW
    logic  [7:0] num_of_increments;  // RW
    logic  [3:0] reserved1;  // RSVD
    logic  [0:0] device_selfchecking;  // RW
    logic  [2:0] test_algorithm_type;  // RW/L
} tmp_CONFIG_ALGO_SETTING_t;

typedef struct packed {
    logic [27:0] reserved0;  // RSVD
    logic  [0:0] completer_timeout_inj_busy;  // RO/V
    logic  [0:0] completer_timeout;  // RW/L
    logic  [0:0] unexp_compl_inject_busy;  // RO/V
    logic  [0:0] unexp_compl_inject;  // RW/L
} tmp_CONFIG_DEVICE_INJECTION_t;

typedef struct packed {
    logic [31:0] observed_pattern1;  // RO/V
    logic [31:0] expected_pattern1;  // RO/V
} tmp_DEVICE_ERROR_LOG1_t;

typedef struct packed {
    logic [31:0] observed_pattern2;  // RO/V
    logic [31:0] expected_pattern2;  // RO/V
} tmp_DEVICE_ERROR_LOG2_t;

typedef struct packed {
    logic [46:0] reserved0;  // RSVD
    logic  [0:0] error_status;  // RW/1C/V
    logic  [7:0] loop_numb;  // RO/V
    logic  [7:0] byte_offset;  // RO/V
} tmp_DEVICE_ERROR_LOG3_t;

typedef struct packed {
    logic [44:0] reserved0;  // RSVD
    logic  [0:0] event_edge_detect;  // RW
    logic  [0:0] event_counter_reset;  // RW
    logic  [0:0] reserved1;  // RSVD
    logic  [7:0] sub_event_select;  // RW
    logic  [7:0] available_event_select;  // RW
} tmp_DEVICE_EVENT_CTRL_t;

typedef struct packed {
    logic [63:0] event_count;  // RW/V
} tmp_DEVICE_EVENT_COUNT_t;

typedef struct packed {
    logic [52:0] reserved0;  // RSVD
    logic  [0:0] CacheMemCRCInjectionBusy;  // RO
    logic  [1:0] CacheMemCRCInjectionCount;  // RO
    logic  [1:0] CacheMemCRCInjection;  // RO
    logic  [0:0] IOPoisonInjectionBusy;  // RO
    logic  [0:0] IOPoisonInjectionStart;  // RO
    logic  [0:0] MemPoisonInjectionBusy;  // RO
    logic  [0:0] MemPoisonInjectionStart;  // RW/L
    logic  [0:0] CachePoisonInjectionBusy;  // RO/V
    logic  [0:0] CachePoisonInjectionStart;  // RW/L
} tmp_DEVICE_ERROR_INJECTION_t;

typedef struct packed {
    logic [62:0] reserved0;  // RSVD
    logic  [0:0] forcefully_disable_afu;  // RW
} tmp_DEVICE_FORCE_DISABLE_t;

typedef struct packed {
    logic [51:0] reserved0;  // RSVD
    logic  [3:0] set_number;  // RO/V
    logic  [7:0] address_increment;  // RO/V
} tmp_DEVICE_ERROR_LOG4_t;

typedef struct packed {
    logic [11:0] reserved0;  // RSVD
    logic [51:0] address_of_first_error;  // RO/V
} tmp_DEVICE_ERROR_LOG5_t;

typedef struct packed {
    logic [53:0] reserved0;  // RSVD
    logic  [0:0] slverr_on_write_response;  // RO/V
    logic  [0:0] slverr_on_read_response;  // RO/V
    logic  [0:0] poison_on_read_response;  // RO/V
    logic  [0:0] illegal_cache_flush_call;  // RO/V
    logic  [0:0] illegal_base_address;  // RO/V
    logic  [0:0] illegal_pattern_size;  // RO/V
    logic  [0:0] illegal_verify_read_semantics;  // RO/V
    logic  [0:0] illegal_execute_read_semantics;  // RO/V
    logic  [0:0] illegal_write_semantics;  // RO/V
    logic  [0:0] illegal_protocol;  // RO/V
} tmp_CONFIG_CXL_ERRORS_t;

typedef struct packed {
    logic [31:0] current_base_pattern;  // RO/V
    logic  [3:0] set_number;  // RO/V
    logic  [7:0] loop_number;  // RO/V
    logic [15:0] reserved0;  // RSVD
    logic  [0:0] alg_verify_sc_busy;  // RO/V
    logic  [0:0] alg_verify_nsc_busy;  // RO/V
    logic  [0:0] alg_execute_busy;  // RO/V
    logic  [0:0] afu_busy;  // RO/V
} tmp_DEVICE_AFU_STATUS1_t;

typedef struct packed {
    logic [11:0] reserved0;  // RSVD
    logic [51:0] current_base_address;  // RO/V
} tmp_DEVICE_AFU_STATUS2_t;

typedef struct packed {
    logic  [3:0] read_aruser_opcode;  // RO/V
    logic [11:0] read_arid;  // RO/V
    logic  [0:0] read_opcode_error_status;  // RO/V
    logic  [0:0] reserved0;  // RSVD
    logic  [3:0] write_awuser_opcode;  // RO/V
    logic [11:0] write_awid;  // RO/V
    logic  [0:0] write_opcode_error_status;  // RO/V
    logic  [0:0] reserved1;  // RSVD
    logic  [2:0] cafu_csr0_read_semantic;  // RO/V
    logic  [3:0] cafu_csr0_write_semantic;  // RO/V
    logic  [0:0] config_error_status;  // RO/V
    logic [17:0] reserved2;  // RSVD
    logic  [0:0] axi2cpi_busy;  // RO/V
    logic  [0:0] clear;  // RW
} tmp_DEVICE_AXI2CPI_STATUS_1_t;

typedef struct packed {
    logic [46:0] address;  // RO/V
    logic [12:0] ccv_afu_arid;  // RO/V
    logic  [0:0] data_parity_error_status;  // RO/V
    logic  [0:0] header_parity_error_status;  // RO/V
    logic  [0:0] reserved0;  // RSVD
    logic  [0:0] clear;  // RW
} tmp_DEVICE_AXI2CPI_STATUS_2_t;

typedef struct packed {
    logic [31:0] cdat_0;  // RW/V
} tmp_CDAT_0_t;

typedef struct packed {
    logic [31:0] cdat_1;  // RW/V
} tmp_CDAT_1_t;

typedef struct packed {
    logic [31:0] cdat_2;  // RW
} tmp_CDAT_2_t;

typedef struct packed {
    logic [31:0] cdat_3;  // RW
} tmp_CDAT_3_t;

typedef struct packed {
    logic [31:0] dsmas_0;  // RW
} tmp_DSMAS_0_t;

typedef struct packed {
    logic [31:0] dsmas_1;  // RW
} tmp_DSMAS_1_t;

typedef struct packed {
    logic [31:0] dsmas_2;  // RW
} tmp_DSMAS_2_t;

typedef struct packed {
    logic [31:0] dsmas_3;  // RW
} tmp_DSMAS_3_t;

typedef struct packed {
    logic [31:0] dsmas_4;  // RW
} tmp_DSMAS_4_t;

typedef struct packed {
    logic [31:0] dsmas_5;  // RW
} tmp_DSMAS_5_t;

typedef struct packed {
    logic [31:0] dsis_0;  // RW
} tmp_DSIS_0_t;

typedef struct packed {
    logic [31:0] dsis_1;  // RW
} tmp_DSIS_1_t;

typedef struct packed {
    logic [31:0] dslbis_0;  // RW
} tmp_DSLBIS_0_t;

typedef struct packed {
    logic [31:0] dslbis_1;  // RW
} tmp_DSLBIS_1_t;

typedef struct packed {
    logic [31:0] dslbis_2;  // RW
} tmp_DSLBIS_2_t;

typedef struct packed {
    logic [31:0] dslbis_3;  // RW
} tmp_DSLBIS_3_t;

typedef struct packed {
    logic [31:0] dslbis_4;  // RW
} tmp_DSLBIS_4_t;

typedef struct packed {
    logic [31:0] dslbis_5;  // RW
} tmp_DSLBIS_5_t;

typedef struct packed {
    logic [31:0] dsemts_0;  // RW
} tmp_DSEMTS_0_t;

typedef struct packed {
    logic [31:0] dsemts_1;  // RW
} tmp_DSEMTS_1_t;

typedef struct packed {
    logic [31:0] dsemts_2;  // RW
} tmp_DSEMTS_2_t;

typedef struct packed {
    logic [31:0] dsemts_3;  // RW
} tmp_DSEMTS_3_t;

typedef struct packed {
    logic [31:0] dsemts_4;  // RW
} tmp_DSEMTS_4_t;

typedef struct packed {
    logic [31:0] dsemts_5;  // RW
} tmp_DSEMTS_5_t;

typedef struct packed {
    logic [15:0] mc1_status;  // RO/V
    logic [15:0] mc0_status;  // RO/V
} tmp_MC_STATUS_t;

typedef struct packed {
    logic [31:0] chan1_cnt;  // RO/V
    logic [31:0] chan0_cnt;  // RO/V
} tmp_DEVMEM_SBECNT_t;

typedef struct packed {
    logic [31:0] chan1_cnt;  // RO/V
    logic [31:0] chan0_cnt;  // RO/V
} tmp_DEVMEM_DBECNT_t;

typedef struct packed {
    logic [31:0] chan1_cnt;  // RO/V
    logic [31:0] chan0_cnt;  // RO/V
} tmp_DEVMEM_POISONCNT_t;

typedef struct packed {
    logic [27:0] reserved;  // RW
    logic  [0:0] event_record;  // RW
    logic  [1:0] event_severity;  // RW
    logic  [0:0] event_trigger;  // RW
} tmp_MBOX_EVENTINJ_t;

typedef struct packed {
    logic  [0:0] clear_number_loops;  // RW
    logic [19:0] total_number_loops;  // RO/V
    logic [39:0] reserved0;  // RSVD
    logic  [0:0] reads_only_mode_enable;  // RW
    logic  [0:0] writes_only_mode_enable;  // RW
    logic  [0:0] latency_mode_enable;  // RW
} tmp_DEVICE_AFU_LATENCY_MODE_t;

typedef struct packed {
    logic [29:0] reserved0;  // RSVD
    logic  [1:0] cache_eviction_policy;  // RW
} tmp_CACHE_EVICTION_POLICY_t;

typedef struct packed {
    logic  [0:0] reserved0;  // RSVD
    logic  [2:0] write_burst_size;  // RW
    logic  [1:0] reserved1;  // RSVD
    logic  [5:0] write_byte_offset;  // RW
    logic  [1:0] reserved2;  // RSVD
    logic  [1:0] write_burst_mode;  // RW
    logic  [1:0] reserved3;  // RSVD
    logic  [5:0] awuser_mode;  // RW
    logic  [1:0] reserved4;  // RSVD
    logic  [5:0] atomic_operation;  // RW
} tmp_AFU_ATOMIC_TEST_ENGINE_CTRL_t;

typedef struct packed {
    logic [30:0] reserved1;  // RO
    logic  [0:0] force_disable;  // RW/1S/V
} tmp_AFU_ATOMIC_TEST_ENGINE_FORCE_DISABLE_t;

typedef struct packed {
    logic [30:0] reserved1;  // RO
    logic  [0:0] initiate_transaction;  // RW/1S/V
} tmp_AFU_ATOMIC_TEST_ENGINE_INITIATE_t;

typedef struct packed {
    logic [63:0] atomic_attr_byte_enable;  // RW
} tmp_AFU_ATOMIC_TEST_ATTR_BYTE_EN_t;

typedef struct packed {
    logic [11:0] reserved52;  // RO
    logic [45:0] target_address;  // RW
    logic  [5:0] reserved0;  // RO
} tmp_AFU_ATOMIC_TEST_TARGET_ADDRESS_t;

typedef struct packed {
    logic [63:0] compare_value_0;  // RW
} tmp_AFU_ATOMIC_TEST_COMPARE_VALUE_0_t;

typedef struct packed {
    logic [63:0] compare_value_1;  // RW
} tmp_AFU_ATOMIC_TEST_COMPARE_VALUE_1_t;

typedef struct packed {
    logic [63:0] swap_value_0;  // RW
} tmp_AFU_ATOMIC_TEST_SWAP_VALUE_0_t;

typedef struct packed {
    logic [63:0] swap_value_1;  // RW
} tmp_AFU_ATOMIC_TEST_SWAP_VALUE_1_t;

typedef struct packed {
    logic [26:0] reserved0;  // RSVD
    logic  [0:0] slverr_on_write_response;  // RO/V
    logic  [0:0] slverr_on_read_response;  // RO/V
    logic  [0:0] cofig_error_status;  // RO/V
    logic  [0:0] read_data_timeout_error;  // RO/V
    logic  [0:0] atomic_test_engine_busy;  // RO/V
} tmp_AFU_ATOMIC_TEST_ENGINE_STATUS_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_0;  // RO/V
} tmp_AFU_ATOMIC_TEST_READ_DATA_VALUE_0_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_1;  // RO/V
} tmp_AFU_ATOMIC_TEST_READ_DATA_VALUE_1_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_2;  // RO/V
} tmp_AFU_ATOMIC_TEST_READ_DATA_VALUE_2_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_3;  // RO/V
} tmp_AFU_ATOMIC_TEST_READ_DATA_VALUE_3_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_4;  // RO/V
} tmp_AFU_ATOMIC_TEST_READ_DATA_VALUE_4_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_5;  // RO/V
} tmp_AFU_ATOMIC_TEST_READ_DATA_VALUE_5_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_6;  // RO/V
} tmp_AFU_ATOMIC_TEST_READ_DATA_VALUE_6_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_7;  // RO/V
} tmp_AFU_ATOMIC_TEST_READ_DATA_VALUE_7_t;

typedef struct packed {
    logic  [0:0] viral_status;  // RW/1C/V/P
} tmp_load_DVSEC_FBCTRL_STATUS_t;

typedef struct packed {
    logic  [0:0] initiate_cxl_reset;  // RW/1S/V
    logic  [0:0] initiate_cache_wb_and_inv;  // RW/1S/V
} tmp_load_DVSEC_FBCTRL2_STATUS2_t;

typedef struct packed {
    logic  [0:0] doe_go;  // RW/V
    logic  [0:0] doe_abort;  // RW/V
} tmp_load_DOE_CTLREG_t;

typedef struct packed {
    logic  [0:0] doe_int_status;  // RW/1C/V
} tmp_load_DOE_STSREG_t;

typedef struct packed {
    logic  [0:0] doe_wr_data_mailbox;  // RW/V
} tmp_load_DOE_WRMAILREG_t;

typedef struct packed {
    logic  [0:0] doe_rd_data_mailbox;  // RW/V
} tmp_load_DOE_RDMAILREG_t;

typedef struct packed {
    logic  [0:0] doorbell;  // RW/V
} tmp_load_CXL_MB_CTRL_t;

typedef struct packed {
    logic  [0:0] payload_len;  // RW/V
} tmp_load_CXL_MB_CMD_t;

typedef struct packed {
    logic  [0:0] error_status;  // RW/1C/V
} tmp_load_DEVICE_ERROR_LOG3_t;

typedef struct packed {
    logic  [0:0] event_count;  // RW/V
} tmp_load_DEVICE_EVENT_COUNT_t;

typedef struct packed {
    logic  [0:0] cdat_0;  // RW/V
} tmp_load_CDAT_0_t;

typedef struct packed {
    logic  [0:0] cdat_1;  // RW/V
} tmp_load_CDAT_1_t;

typedef struct packed {
    logic  [0:0] force_disable;  // RW/1S/V
} tmp_load_AFU_ATOMIC_TEST_ENGINE_FORCE_DISABLE_t;

typedef struct packed {
    logic  [0:0] initiate_transaction;  // RW/1S/V
} tmp_load_AFU_ATOMIC_TEST_ENGINE_INITIATE_t;

typedef struct packed {
    logic  [0:0] mem_base_low;  // RW/L
} tmp_lock_HDM_DEC_BASELOW_t;

typedef struct packed {
    logic  [0:0] mem_base_high;  // RW/L
} tmp_lock_HDM_DEC_BASEHIGH_t;

typedef struct packed {
    logic  [0:0] mem_size_low;  // RW/L
} tmp_lock_HDM_DEC_SIZELOW_t;

typedef struct packed {
    logic  [0:0] mem_size_high;  // RW/L
} tmp_lock_HDM_DEC_SIZEHIGH_t;

typedef struct packed {
    logic  [0:0] commit;  // RW/L
    logic  [0:0] lock_on_commit;  // RW/L
    logic  [0:0] interleave_ways;  // RW/L
    logic  [0:0] interleave_granularity;  // RW/L
} tmp_lock_HDM_DEC_CTRL_t;

typedef struct packed {
    logic  [0:0] dpa_skip_low;  // RW/L
} tmp_lock_HDM_DEC_DPALOW_t;

typedef struct packed {
    logic  [0:0] dpa_skip_high;  // RW/L
} tmp_lock_HDM_DEC_DPAHIGH_t;

typedef struct packed {
    logic  [0:0] viral_status;  // RW/1C/V/P
} tmp_new_DVSEC_FBCTRL_STATUS_t;

typedef struct packed {
    logic  [0:0] power_mgt_init_complete;  // RO/V
    logic  [0:0] cxl_reset_error;  // RO/V
    logic  [0:0] cxl_reset_complete;  // RO/V
    logic  [0:0] cache_invalid;  // RO/V
    logic  [0:0] initiate_cxl_reset;  // RW/1S/V
    logic  [0:0] initiate_cache_wb_and_inv;  // RW/1S/V
} tmp_new_DVSEC_FBCTRL2_STATUS2_t;

typedef struct packed {
    logic  [0:0] doe_go;  // RW/V
    logic  [0:0] doe_abort;  // RW/V
} tmp_new_DOE_CTLREG_t;

typedef struct packed {
    logic  [0:0] data_object_ready;  // RO/V
    logic  [0:0] doe_error;  // RO/V
    logic  [0:0] doe_int_status;  // RW/1C/V
    logic  [0:0] doe_busy;  // RO/V
} tmp_new_DOE_STSREG_t;

typedef struct packed {
    logic [31:0] doe_wr_data_mailbox;  // RW/V
} tmp_new_DOE_WRMAILREG_t;

typedef struct packed {
    logic [31:0] doe_rd_data_mailbox;  // RW/V
} tmp_new_DOE_RDMAILREG_t;

typedef struct packed {
    logic [27:0] test_config_base_low;  // RO/V
} tmp_new_CXL_DVSEC_TEST_CNF_BASE_LOW_t;

typedef struct packed {
    logic [31:0] test_config_base_high;  // RO/V
} tmp_new_CXL_DVSEC_TEST_CNF_BASE_HIGH_t;

typedef struct packed {
    logic  [0:0] fatal_event_log;  // RO/V
    logic  [0:0] failure_event_log;  // RO/V
    logic  [0:0] warning_event_log;  // RO/V
    logic  [0:0] info_event_log;  // RO/V
} tmp_new_CXL_DEV_CAP_EVENT_STATUS_t;

typedef struct packed {
    logic  [2:0] reset_needed;  // RO/V
    logic  [0:0] mailbox_if_ready;  // RO/V
    logic  [1:0] media_status;  // RO/V
    logic  [0:0] fw_halt;  // RO/V
    logic  [0:0] device_fatal;  // RO/V
} tmp_new_CXL_MEM_DEV_STATUS_t;

typedef struct packed {
    logic  [0:0] doorbell;  // RW/V
} tmp_new_CXL_MB_CTRL_t;

typedef struct packed {
    logic [20:0] payload_len;  // RW/V
} tmp_new_CXL_MB_CMD_t;

typedef struct packed {
    logic [15:0] vendor_specfic_ext_status;  // RO/V
    logic [15:0] return_code;  // RO/V
    logic  [0:0] bk_operation;  // RO/V
} tmp_new_CXL_MB_STATUS_t;

typedef struct packed {
    logic [15:0] vendor_specfic_ext_status;  // RO/V
    logic [15:0] return_code;  // RO/V
    logic  [6:0] percentage_comp;  // RO/V
    logic [15:0] cmd_opcode;  // RO/V
} tmp_new_CXL_MB_BK_CMD_STATUS_t;

typedef struct packed {
    logic  [0:0] committed;  // RO/V
} tmp_new_HDM_DEC_CTRL_t;

typedef struct packed {
    logic  [0:0] completer_timeout_inj_busy;  // RO/V
    logic  [0:0] unexp_compl_inject_busy;  // RO/V
} tmp_new_CONFIG_DEVICE_INJECTION_t;

typedef struct packed {
    logic [31:0] observed_pattern1;  // RO/V
    logic [31:0] expected_pattern1;  // RO/V
} tmp_new_DEVICE_ERROR_LOG1_t;

typedef struct packed {
    logic [31:0] observed_pattern2;  // RO/V
    logic [31:0] expected_pattern2;  // RO/V
} tmp_new_DEVICE_ERROR_LOG2_t;

typedef struct packed {
    logic  [0:0] error_status;  // RW/1C/V
    logic  [7:0] loop_numb;  // RO/V
    logic  [7:0] byte_offset;  // RO/V
} tmp_new_DEVICE_ERROR_LOG3_t;

typedef struct packed {
    logic [63:0] event_count;  // RW/V
} tmp_new_DEVICE_EVENT_COUNT_t;

typedef struct packed {
    logic  [0:0] CachePoisonInjectionBusy;  // RO/V
} tmp_new_DEVICE_ERROR_INJECTION_t;

typedef struct packed {
    logic  [3:0] set_number;  // RO/V
    logic  [7:0] address_increment;  // RO/V
} tmp_new_DEVICE_ERROR_LOG4_t;

typedef struct packed {
    logic [51:0] address_of_first_error;  // RO/V
} tmp_new_DEVICE_ERROR_LOG5_t;

typedef struct packed {
    logic  [0:0] slverr_on_write_response;  // RO/V
    logic  [0:0] slverr_on_read_response;  // RO/V
    logic  [0:0] poison_on_read_response;  // RO/V
    logic  [0:0] illegal_cache_flush_call;  // RO/V
    logic  [0:0] illegal_base_address;  // RO/V
    logic  [0:0] illegal_pattern_size;  // RO/V
    logic  [0:0] illegal_verify_read_semantics;  // RO/V
    logic  [0:0] illegal_execute_read_semantics;  // RO/V
    logic  [0:0] illegal_write_semantics;  // RO/V
    logic  [0:0] illegal_protocol;  // RO/V
} tmp_new_CONFIG_CXL_ERRORS_t;

typedef struct packed {
    logic [31:0] current_base_pattern;  // RO/V
    logic  [3:0] set_number;  // RO/V
    logic  [7:0] loop_number;  // RO/V
    logic  [0:0] alg_verify_sc_busy;  // RO/V
    logic  [0:0] alg_verify_nsc_busy;  // RO/V
    logic  [0:0] alg_execute_busy;  // RO/V
    logic  [0:0] afu_busy;  // RO/V
} tmp_new_DEVICE_AFU_STATUS1_t;

typedef struct packed {
    logic [51:0] current_base_address;  // RO/V
} tmp_new_DEVICE_AFU_STATUS2_t;

typedef struct packed {
    logic  [3:0] read_aruser_opcode;  // RO/V
    logic [11:0] read_arid;  // RO/V
    logic  [0:0] read_opcode_error_status;  // RO/V
    logic  [3:0] write_awuser_opcode;  // RO/V
    logic [11:0] write_awid;  // RO/V
    logic  [0:0] write_opcode_error_status;  // RO/V
    logic  [2:0] cafu_csr0_read_semantic;  // RO/V
    logic  [3:0] cafu_csr0_write_semantic;  // RO/V
    logic  [0:0] config_error_status;  // RO/V
    logic  [0:0] axi2cpi_busy;  // RO/V
} tmp_new_DEVICE_AXI2CPI_STATUS_1_t;

typedef struct packed {
    logic [46:0] address;  // RO/V
    logic [12:0] ccv_afu_arid;  // RO/V
    logic  [0:0] data_parity_error_status;  // RO/V
    logic  [0:0] header_parity_error_status;  // RO/V
} tmp_new_DEVICE_AXI2CPI_STATUS_2_t;

typedef struct packed {
    logic [31:0] cdat_0;  // RW/V
} tmp_new_CDAT_0_t;

typedef struct packed {
    logic [31:0] cdat_1;  // RW/V
} tmp_new_CDAT_1_t;

typedef struct packed {
    logic [15:0] mc1_status;  // RO/V
    logic [15:0] mc0_status;  // RO/V
} tmp_new_MC_STATUS_t;

typedef struct packed {
    logic [31:0] chan1_cnt;  // RO/V
    logic [31:0] chan0_cnt;  // RO/V
} tmp_new_DEVMEM_SBECNT_t;

typedef struct packed {
    logic [31:0] chan1_cnt;  // RO/V
    logic [31:0] chan0_cnt;  // RO/V
} tmp_new_DEVMEM_DBECNT_t;

typedef struct packed {
    logic [31:0] chan1_cnt;  // RO/V
    logic [31:0] chan0_cnt;  // RO/V
} tmp_new_DEVMEM_POISONCNT_t;

typedef struct packed {
    logic [19:0] total_number_loops;  // RO/V
} tmp_new_DEVICE_AFU_LATENCY_MODE_t;

typedef struct packed {
    logic  [0:0] force_disable;  // RW/1S/V
} tmp_new_AFU_ATOMIC_TEST_ENGINE_FORCE_DISABLE_t;

typedef struct packed {
    logic  [0:0] initiate_transaction;  // RW/1S/V
} tmp_new_AFU_ATOMIC_TEST_ENGINE_INITIATE_t;

typedef struct packed {
    logic  [0:0] slverr_on_write_response;  // RO/V
    logic  [0:0] slverr_on_read_response;  // RO/V
    logic  [0:0] cofig_error_status;  // RO/V
    logic  [0:0] read_data_timeout_error;  // RO/V
    logic  [0:0] atomic_test_engine_busy;  // RO/V
} tmp_new_AFU_ATOMIC_TEST_ENGINE_STATUS_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_0;  // RO/V
} tmp_new_AFU_ATOMIC_TEST_READ_DATA_VALUE_0_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_1;  // RO/V
} tmp_new_AFU_ATOMIC_TEST_READ_DATA_VALUE_1_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_2;  // RO/V
} tmp_new_AFU_ATOMIC_TEST_READ_DATA_VALUE_2_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_3;  // RO/V
} tmp_new_AFU_ATOMIC_TEST_READ_DATA_VALUE_3_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_4;  // RO/V
} tmp_new_AFU_ATOMIC_TEST_READ_DATA_VALUE_4_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_5;  // RO/V
} tmp_new_AFU_ATOMIC_TEST_READ_DATA_VALUE_5_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_6;  // RO/V
} tmp_new_AFU_ATOMIC_TEST_READ_DATA_VALUE_6_t;

typedef struct packed {
    logic [63:0] cacheline_readdata_7;  // RO/V
} tmp_new_AFU_ATOMIC_TEST_READ_DATA_VALUE_7_t;

 endpackage 

 `endif 
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "8PhOGCnqQbAbJgmQKuGahsXyBGOqnzJpaaepB4em/LfHKuzJoKpoYsBe35LjKDi25jgan/aauEWsf8HDTdfj7jcC2yCsixDCQ3p7OCgc9Hp1H2OzKOvi1qhwBi7kYnvuqWX26D6nOTtEFDfggOZVro8JXoRIL9p3vh13LBiTXTGn8SWhyyzJS6Tqcxi2IXTDzRrzmeGJnXTRhMERLiUIGnZaBs86Pr/nV4RjvtzkvHFJ/+5PciVspe6J++zvrv0nDDjn1iDDk+mOJOexbZUpFLhEqyEOrH20HdPIbl7bBplPJ97VG6MrMbh1G5Fl2DNhvf7KRWj8PC2Moe8QhWhKSbZ9TnTLC3s4tArYBsuBVX47vo4pGPq+oVoa5FHTTX3Z7q4CdSo3cka/Hh7LPBaBCWzlniJ0YNL2yrv7NXS+VXqOW+rulJ1CLrpH9cRm6Xwfne1YCeQAYh0S1JquFHSyzlW3L5Hhyauwjh8wBjmwRoMoOU3WK+/RR5E5aRq4OZAQ2XDsJ9Lb3bwgi1RQSMvHyMft5nb1Nng7UEiq8gsxlMS8sjXuKjupTJUgFyrVy+G6Gw9JlrgLXg5lzpeM4XyLdDdJu0hsw594pMelj+sZOtHH7TEqiT4Y17Q/NQP8DYdaFk+ssXQ0kl4/hk/ArA6hhGnCF9jHx27T05kgY61AxF3pzSVPKf8a5hphfSCMV2fhNiW7MJkKOBt7h+Wv5bHw4LoMOmYUTdlQnKqToE6BNg75/SJRNp5ekotsm8Ru+JBMJtC48cAapY8URXCdz0/rIu4PVU/6v4Bf3yExIXLqLvKJ62S+FC+PMZOKcw8xwb9bBk8WM7ZRIq39s7Kg8mQyuHEsqLecl2kF31ZE4DvsLMDKWKIfwXHVHOKVUMT/igiPyVOI3ScvHt/Sx7bnvwNttU8oLtAixcoFNDFgr4PTT8/xlfIIaY68+12QOSB2JazM3Dbv6g3K1njs8FeZpwEV2qRPI1NgYLiwKQj64zoNvc7bb3CDLLktBBgud2sE7Tvm"
`endif