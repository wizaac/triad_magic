import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("-t", "--target", type=str, default="blinky")
parser.add_argument("-synth",  action="store_true")
parser.add_argument("-pnr",    action="store_true")
parser.add_argument("-prog",   action="store_true")
parser.add_argument("-all",    action="store_true")
parser.add_argument("-clean",  action="store_true")
args = parser.parse_args()

DEVICE  = "hx8k"
PACKAGE = "cb132"
PCF     = "alchitry_cu.pcf"
BUILD   = "./build"
SRC     = "./hdl"
top     = args.target

os.makedirs(BUILD, exist_ok=True)

synth_cmd = (f"yosys -p 'synth_ice40 -top {top} -json {BUILD}/{top}.json' "
             f"{SRC}/{top}.v")
pnr_cmd   = (f"nextpnr-ice40 --{DEVICE} --package {PACKAGE} "
             f"--json {BUILD}/{top}.json "
             f"--pcf {PCF} --asc {BUILD}/{top}.asc")
pack_cmd  = f"icepack {BUILD}/{top}.asc {BUILD}/{top}.bin"
prog_cmd  = f"iceprog {BUILD}/{top}.bin"

if args.clean:
    os.system(f"rm -rf {BUILD}/*")
    print("Build directory cleaned")

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
    print("=== Programming ===")
    os.system(prog_cmd)
