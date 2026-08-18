if {![info exists SIM_ROOT]} { set SIM_ROOT [pwd] }
set sim_root [file normalize $SIM_ROOT]
cd $sim_root

file mkdir build
if {[file exists build/work]} {
    vdel -lib build/work -all
}
vlib build/work
vmap work build/work

set sources {}
foreach list_file {rtl/rtl.f tb/tb.f} {
    set handle [open $list_file r]
    while {[gets $handle line] >= 0} {
        set line [string trim $line]
        if {$line ne "" && ![string match "//*" $line]} {
            lappend sources $line
        }
    }
    close $handle
}

puts "Compiling [llength $sources] WPPP simulation sources"
if {[catch {vlog -sv -work work +incdir+rtl +incdir+tb {*}$sources} message]} {
    puts stderr $message
    quit -code 2 -f
}
