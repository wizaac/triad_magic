import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("-t", "--target", type=str, default="blinky")
parser.add_argument("-synth",  action="store_true")
parser.add_argument("-pnr",    action="store_true")
parser.add_argument("-prog",   action="store_true")
parser.add_argument("-all",    action="store_true")
parser.add_argument("-clean",  action="store_true")
parser.add_argument("-sim", action="store_true", help="Run simulation in Questa")
parser.add_argument("-wave", action="store_true", help="Open waveform viewer")
args = parser.parse_args()

DEVICE  = "hx8k"
PACKAGE = "cb132"
PCF     = "alchitry_cu.pcf"
BUILD   = "./build"
SRC     = "./hdl"
TBS     = "./tbs"
top     = args.target

os.makedirs(BUILD, exist_ok=True)


SIM_BUILD = "./sim_build"

deps = {
   "spi_master":     ["hdl/spi_master.v"],
   "display_driver": ["hdl/spi_master.v",
                      "hdl/shared_rom.v",
                      "hdl/display_driver.v"],
   "display_top":    ["hdl/spi_master.v",
                      "hdl/shared_rom.v",
                      "hdl/display_driver.v",
                      "hdl/display_top.v"],
   "blinky":         ["hdl/blinky.v"],
}

src_files = " ".join(deps.get(top, [f"{SRC}/{top}.v"]))

# Questa simulation commands
vlog_cmd = (f"vlog -sv -work {SIM_BUILD}/work "
            f"-createlib "
            f"{src_files} {TBS}/{top}_tb.v "
            f"-l {SIM_BUILD}/vlog_{top}.log")

vopt_cmd = (f"vopt {top}_tb "
            f"-work {SIM_BUILD}/work "
            f"-o {top}_tb_opt "
            f"-debug "
            f"-designfile {SIM_BUILD}/{top}.bin "
            f"-l {SIM_BUILD}/vopt_{top}.log")

vsim_cmd = (f"vsim {top}_tb_opt "
            f"-work {SIM_BUILD}/work "
            f"-c -do 'run -all; quit' "
            f"-l {SIM_BUILD}/vsim_{top}.log")

if args.wave:
    vsim_cmd = (f"vsim {top}_tb_opt "
                f"-work {SIM_BUILD}/work "
                f"-visualizer "
                f"+designfile+{SIM_BUILD}/{top}.bin "
                f"-do 'add wave -r /*; run -all' "
                f"-l {SIM_BUILD}/vsim_{top}.log")

synth_cmd = (f"yosys -p 'synth_ice40 -top {top} -json {BUILD}/{top}.json' "
             f"{src_files}")

pnr_cmd   = (f"nextpnr-ice40 --{DEVICE} --package {PACKAGE} "
             f"--json {BUILD}/{top}.json "
             f"--pcf {PCF} --asc {BUILD}/{top}.asc")
pack_cmd  = f"icepack {BUILD}/{top}.asc {BUILD}/{top}.bin"
prog_cmd  = f"iceprog {BUILD}/{top}.bin"

if args.clean:
    os.system(f"rm -rf {BUILD}/*")
    print("Build directory cleaned")

if args.sim:
    os.makedirs(SIM_BUILD, exist_ok=True)
    print("=== Compiling for simulation ===")
    ret = os.system(vlog_cmd)
    if ret != 0:
        print("vlog failed!")
        exit(1)
    print("=== Optimizing ===")
    ret = os.system(vopt_cmd)
    if ret != 0:
        print("vopt failed!")
        exit(1)
    print("=== Simulating ===")
    os.system(vsim_cmd)

if args.all or args.synth:
    print("=== Synthesizing ===")
    ret = os.system(synth_cmd)
    if ret != 0:
        print("Synthesis failed!")
        exit(1)

if args.all or args.pnr:
    print("=== Place and Route ===")
    ret = os.system(pnr_cmd)
    if ret != 0:
        print("PnR failed!")
        exit(1)
    os.system(pack_cmd)

if args.all or args.prog:
    bin_path = f"{BUILD}/{top}.bin"
    if os.path.exists(bin_path):
        print("=== Pushing bitstream to git ===")
        os.system(f"git add {bin_path}")
        os.system(f"git commit -m 'build: {top} bitstream'")
        os.system(f"git push")
    else:
        print(f"No bin file found at {bin_path}, skipping push")
