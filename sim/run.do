# Roda um testbench no ModelSim.
# Uso, no console do ModelSim (Transcript):
#   cd <pasta do repositorio>/sim
#   do run.do tb_module_alu
if {[file exists work]} { vdel -lib work -all }
vlib work
vlog +incdir+../rtl ../rtl/*.v $1.v
vsim -voptargs=+acc work.$1
add wave -r /*
run -all
