if {![info exists SIM_ROOT]} { set SIM_ROOT [pwd] }
set sim_root [file normalize $SIM_ROOT]
cd $sim_root

if {![info exists TOP_LEVEL]} { set TOP_LEVEL wppp_tb }
if {![info exists VSIM_PLUSARGS]} { set VSIM_PLUSARGS {} }
if {![info exists SIM_RUN_NAME] || $SIM_RUN_NAME eq ""} { set SIM_RUN_NAME wppp }
if {![info exists SIM_LOG_DIR] || $SIM_LOG_DIR eq ""} { set SIM_LOG_DIR logs/manual }
if {![info exists SIM_WLF]} { set SIM_WLF 0 }

file mkdir $SIM_LOG_DIR
set transcript_path [file normalize [file join $SIM_LOG_DIR "${SIM_RUN_NAME}.vsim.log"]]
transcript file $transcript_path

set load_args [list -lib work $TOP_LEVEL]
foreach plusarg $VSIM_PLUSARGS {
    if {$plusarg ne ""} { lappend load_args $plusarg }
}
if {!$SIM_WLF} {
    lappend load_args -wlf /dev/null
}

puts "Loading $TOP_LEVEL with plusargs: $VSIM_PLUSARGS"
if {[catch {vsim {*}$load_args} message]} {
    puts stderr $message
    quit -code 2 -f
}

set run_status [catch {run -all} run_message]
if {$run_status} {
    puts stderr $run_message
    quit -code 1 -f
}
quit -sim
