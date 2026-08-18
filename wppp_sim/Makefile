BUILD_DIR ?= build
SIM_DIR := sim
TOP_LEVEL ?= wppp_tb
QUESTA ?= vsim
SIM_COMPILE ?= 1
SIM_PLUSARGS ?=
SIM_RUN_NAME ?= manual
SIM_LOG_DIR ?= logs/manual
SIM_WLF ?= 0
JOBS ?= 4
WORKFLOW_NOTIFY ?= 1
WORKFLOW_NOTIFY_CMD ?= ../tools/send_workflow_ping.py
REGRESSION_RUNNER ?= python3 tools/run_regression.py
REPRO_RUNNER ?= python3 tools/run_repro.py
RUN_STAMP ?= $(shell date -u +%Y%m%dT%H%M%SZ)
RUN_STAMP := $(RUN_STAMP)
SMOKE_LOG_DIR ?= logs/smoke_$(RUN_STAMP)
FOCUSED_LOG_DIR ?= logs/focused_$(RUN_STAMP)
FULL_LOG_DIR ?= logs/full_$(RUN_STAMP)
REPRO_LOG_DIR ?= logs/repro_$(RUN_STAMP)
SIM_DURATION_HISTORY ?= logs/.duration_history.json
SIM_COMPRESS_PASS_LOGS ?= 1
SIM_RERUN_FAILURES ?= 1
SIM_FAILURE_WLF ?= 0

SMOKE_TESTS := \
	RUN_SINGLE_HINT \
	RUN_OUT_OF_ORDER

FOCUSED_TESTS := \
	$(SMOKE_TESTS) \
	RUN_BACKPRESSURE \
	RUN_HINT_QUEUE \
	RUN_LUT_FLUSH

FULL_TESTS := \
	$(FOCUSED_TESTS) \
	RUN_ID_WRAP

REPRO_SPECS := \
	'RUN_AR_LAST_STALL_REPRO::WPPP_REPRODUCED: last-cacheline hint dequeued without AR handshake' \
	'RUN_RANGE_HEAD_BLOCK_REPRO::WPPP_REPRODUCED: out-of-range head hint blocks following valid hint'

SIM_COMPILE_DO = $(if $(filter 1,$(SIM_COMPILE)),source $(SIM_DIR)/compile.tcl;,)

.PHONY: all compile sim sim-fast sim-smoke sim-focused sim-full sim-repro list-sim-tiers test-tools clean help

all: sim-smoke

compile:
	$(QUESTA) -c -do "set SIM_ROOT [pwd]; source $(SIM_DIR)/compile.tcl; quit -f"

sim:
	@mkdir -p $(SIM_LOG_DIR)
	$(QUESTA) -c -do "set SIM_ROOT [pwd]; $(SIM_COMPILE_DO) set TOP_LEVEL $(TOP_LEVEL); set VSIM_PLUSARGS {$(SIM_PLUSARGS)}; set SIM_RUN_NAME {$(SIM_RUN_NAME)}; set SIM_LOG_DIR {$(SIM_LOG_DIR)}; set SIM_WLF $(SIM_WLF); do $(SIM_DIR)/sim.tcl; quit -f"

sim-fast: SIM_COMPILE=0
sim-fast: sim

sim-smoke: compile
	@$(REGRESSION_RUNNER) \
		--profile smoke \
		--jobs $(JOBS) \
		--log-dir $(SMOKE_LOG_DIR) \
		--history-file $(SIM_DURATION_HISTORY) \
		--compress-pass-logs $(SIM_COMPRESS_PASS_LOGS) \
		--rerun-failures $(SIM_RERUN_FAILURES) \
		--failure-wlf $(SIM_FAILURE_WLF) \
		--notify $(WORKFLOW_NOTIFY) \
		--notify-tool $(WORKFLOW_NOTIFY_CMD) \
		$(SMOKE_TESTS)

sim-focused: compile
	@$(REGRESSION_RUNNER) \
		--profile focused \
		--jobs $(JOBS) \
		--log-dir $(FOCUSED_LOG_DIR) \
		--history-file $(SIM_DURATION_HISTORY) \
		--compress-pass-logs $(SIM_COMPRESS_PASS_LOGS) \
		--rerun-failures $(SIM_RERUN_FAILURES) \
		--failure-wlf $(SIM_FAILURE_WLF) \
		--notify $(WORKFLOW_NOTIFY) \
		--notify-tool $(WORKFLOW_NOTIFY_CMD) \
		$(FOCUSED_TESTS)

sim-full: compile
	@$(REGRESSION_RUNNER) \
		--profile full \
		--jobs $(JOBS) \
		--log-dir $(FULL_LOG_DIR) \
		--history-file $(SIM_DURATION_HISTORY) \
		--compress-pass-logs $(SIM_COMPRESS_PASS_LOGS) \
		--rerun-failures $(SIM_RERUN_FAILURES) \
		--failure-wlf $(SIM_FAILURE_WLF) \
		--notify $(WORKFLOW_NOTIFY) \
		--notify-tool $(WORKFLOW_NOTIFY_CMD) \
		$(FULL_TESTS)

sim-repro: compile
	@$(REPRO_RUNNER) \
		--jobs $(JOBS) \
		--log-dir $(REPRO_LOG_DIR) \
		--notify $(WORKFLOW_NOTIFY) \
		--notify-tool $(WORKFLOW_NOTIFY_CMD) \
		$(REPRO_SPECS)

list-sim-tiers:
	@echo "sim-smoke   : basic read/copy and out-of-order response mapping"
	@echo "sim-focused : smoke plus AXI backpressure, hint ordering, and LUT flush"
	@echo "sim-full    : focused plus the 10-bit request-ID wrap stress"
	@echo "sim-repro   : separately classify known expected-fail protocol bugs"

test-tools:
	python3 -m unittest discover -s tools/tests -p 'test_*.py'

clean:
	rm -rf $(BUILD_DIR) modelsim.ini transcript

help: list-sim-tiers
	@echo ""
	@echo "Single test: make sim SIM_PLUSARGS=+RUN_SINGLE_HINT"
	@echo "Disable pings: append WORKFLOW_NOTIFY=0"
