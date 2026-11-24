# add_sources.tcl — 소스를 Vivado 프로젝트(charge_jump.xpr)에 등록한다. 파일은 복사하지 않고 제자리에서 참조한다.
# 프로젝트를 연 뒤 Tcl 콘솔에서:
#   source C:/Users/sun20/vivado/charge_jump/add_sources.tcl
# 파일이 새로 생겼을 때 다시 실행해도 된다 (이미 등록된 파일은 건너뛴다).
set root [file dirname [file normalize [info script]]]

proc add_new {fileset files} {
    set new {}
    foreach f $files {
        if {[llength [get_files -quiet $f]] == 0} { lappend new $f }
    }
    if {[llength $new] > 0} {
        add_files -norecurse -fileset $fileset $new
        puts "charge_jump: $fileset 에 [llength $new]개 추가"
    }
}

# 설계 소스
add_new sources_1 [concat [glob $root/rtl/*.v] \
    [list $root/rtl/params.vh $root/rtl/map.mem $root/rtl/sin.mem]]
set_property file_type {Verilog Header} [get_files $root/rtl/params.vh]
set_property include_dirs [list $root/rtl] [get_filesets sources_1]
set_property top top [get_filesets sources_1]

# 제약
add_new constrs_1 [list $root/constrs/charge_jump.xdc]

# 시뮬레이션
add_new sim_1 [concat [glob $root/sim/tb_*.v] \
    [list $root/sim/tb_harness.vh $root/sim/test_map.mem]]
set_property file_type {Verilog Header} [get_files $root/sim/tb_harness.vh]
set_property include_dirs [list $root/rtl $root/sim] [get_filesets sim_1]
set_property top tb_physics [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "charge_jump: 소스 등록 완료. 시뮬레이션 top 을 바꾸려면: set_property top tb_collision \[get_filesets sim_1\]"
