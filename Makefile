PROJECT_DIR ?= hardware_test_design
PROJECT ?= cxltyp2_ed
REVISION ?= cxltyp2_ed
CLOCK_NAME ?= coreclkout_hip
MIN_WNS ?= -0.900
WORKFLOW_NOTIFY ?= 1
WORKFLOW_NOTIFY_CMD ?= tools/send_workflow_ping.py
JOBS ?= 4
QUARTUS_RUNNER ?= python3 tools/run_quartus.py
RUN_STAMP ?= $(shell date -u +%Y%m%dT%H%M%SZ)
RUN_STAMP := $(RUN_STAMP)
QUICK_LOG_DIR ?= logs/quartus_quick_$(RUN_STAMP)
FULL_COMPILE_LOG_DIR ?= logs/quartus_full_$(RUN_STAMP)

.PHONY: all sim-smoke sim-focused sim-full sim-repro sim-integration-smoke sim-integration-focused sim-integration-full quartus-ip-check quartus-ip-plan quartus-preflight quartus-quick quartus-full test-tools clean-sim help

all: sim-smoke

sim-smoke sim-focused sim-full sim-repro:
	$(MAKE) -C wppp_sim $@ WORKFLOW_NOTIFY=$(WORKFLOW_NOTIFY) JOBS=$(JOBS)

sim-integration-smoke:
	$(MAKE) -C wppp_integration_sim sim-smoke WORKFLOW_NOTIFY=$(WORKFLOW_NOTIFY) JOBS=$(JOBS)

sim-integration-focused:
	$(MAKE) -C wppp_integration_sim sim-focused WORKFLOW_NOTIFY=$(WORKFLOW_NOTIFY) JOBS=$(JOBS)

sim-integration-full:
	$(MAKE) -C wppp_integration_sim sim-full WORKFLOW_NOTIFY=$(WORKFLOW_NOTIFY) JOBS=$(JOBS)

quartus-ip-check:
	python3 tools/check_quartus_ip.py \
		--project-dir $(PROJECT_DIR) \
		--project $(PROJECT) \
		--revision $(REVISION)

quartus-ip-plan:
	python3 tools/check_quartus_ip.py \
		--project-dir $(PROJECT_DIR) \
		--project $(PROJECT) \
		--revision $(REVISION) \
		--print-generation-command

quartus-preflight:
	$(QUARTUS_RUNNER) \
		--mode quick-elab \
		--project-dir $(PROJECT_DIR) \
		--project $(PROJECT) \
		--revision $(REVISION) \
		--log-dir $(QUICK_LOG_DIR) \
		--dry-run
	$(QUARTUS_RUNNER) \
		--mode full \
		--project-dir $(PROJECT_DIR) \
		--project $(PROJECT) \
		--revision $(REVISION) \
		--clock-name $(CLOCK_NAME) \
		--min-wns $(MIN_WNS) \
		--log-dir $(FULL_COMPILE_LOG_DIR) \
		--dry-run
	$(MAKE) quartus-ip-check

quartus-quick: quartus-ip-check
	$(QUARTUS_RUNNER) \
		--mode quick-elab \
		--project-dir $(PROJECT_DIR) \
		--project $(PROJECT) \
		--revision $(REVISION) \
		--log-dir $(QUICK_LOG_DIR) \
		--notify $(WORKFLOW_NOTIFY) \
		--notify-tool $(WORKFLOW_NOTIFY_CMD)

quartus-full: quartus-ip-check
	$(QUARTUS_RUNNER) \
		--mode full \
		--project-dir $(PROJECT_DIR) \
		--project $(PROJECT) \
		--revision $(REVISION) \
		--clock-name $(CLOCK_NAME) \
		--min-wns $(MIN_WNS) \
		--log-dir $(FULL_COMPILE_LOG_DIR) \
		--notify $(WORKFLOW_NOTIFY) \
		--notify-tool $(WORKFLOW_NOTIFY_CMD)

test-tools:
	python3 -m unittest discover -s tools/tests -p 'test_*.py'
	$(MAKE) -C wppp_sim test-tools

clean-sim:
	$(MAKE) -C wppp_sim clean
	$(MAKE) -C wppp_integration_sim clean

help:
	@echo "WPPP validation and build targets"
	@echo "  sim-smoke       two-test sanity regression"
	@echo "  sim-focused     protocol/backpressure regression"
	@echo "  sim-full        focused tests plus request-ID wrap"
	@echo "  sim-repro       classify known bugs as XFAIL"
	@echo "  sim-integration-smoke    AXI host pass-through plus one full hint"
	@echo "  sim-integration-focused  smoke plus dual-engine/concurrent traffic"
	@echo "  sim-integration-full     focused plus inactive-HPPB isolation"
	@echo "  quartus-ip-check   verify generated IP/QIP synthesis collateral"
	@echo "  quartus-ip-plan    print the scoped qsys-generate recovery plan"
	@echo "  quartus-preflight  validate Quartus plans, tools, and IP collateral"
	@echo "  quartus-quick   Quartus 25.3 quick elaboration"
	@echo "  quartus-full    full compile plus core-clock timing gate"
	@echo "  test-tools      unit-test the workflow tooling"
	@echo ""
	@echo "Set WORKFLOW_NOTIFY=0 to suppress user pings."
