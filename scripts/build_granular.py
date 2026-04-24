#!/usr/bin/env python3
"""
build_granular.py
Alchitry CU (iCE40 HX8K) — step-by-step build with inspection at every layer.

Usage examples:
  python3 build_granular.py -t display_scroll_test --rtl
  python3 build_granular.py -t display_scroll_test --synth
  python3 build_granular.py -t display_scroll_test --synth --show-stats
  python3 build_granular.py -t display_scroll_test --pnr --gui
  python3 build_granular.py -t display_scroll_test --timing
  python3 build_granular.py -t display_scroll_test --all
  python3 build_granular.py -t display_scroll_test --all --pack --prog

Each stage only runs if its prerequisite outputs exist, so you can run
stages independently without redoing earlier work.
"""

import argparse
import os
import sys
import subprocess

# ── Target dependency table (same as build.py) ────────────────────────────
DEPS = {
    "spi_master":          ["hdl/spi_master.v"],
    "display_driver":      ["hdl/spi_master.v", "hdl/shared_rom.v",
                            "hdl/display_driver.v"],
    "display_top":         ["hdl/spi_master.v", "hdl/shared_rom.v",
                            "hdl/display_driver.v", "hdl/display_top.v"],
    "display_scroll_test": ["hdl/spi_master.v", "hdl/shared_rom.v",
                            "hdl/display_scroll_test.v",
                            "hdl/display_driver.v", "hdl/display_top.v"],
    "blinky":              ["hdl/blinky.v"],
    "adc_to_screen_test":  ["hdl/spi_master.v", "hdl/shared_rom.v",
                            "hdl/display_driver.v", "hdl/adc_decoder.v","hdl/adc_to_screen_test.v"],
	"triad_magic":["hdl/spi_master.v", "hdl/shared_rom.v",
                            "hdl/display_driver.v", "hdl/adc_reader.v", "hdl/chord_channel.v","hdl/triad_magic.v"]
}

DEVICE  = "hx8k"
PACKAGE = "cb132"
BUILD   = "./build"
WAVES   = "./waves"

# ── CLI ────────────────────────────────────────────────────────────────────
p = argparse.ArgumentParser(
    formatter_class=argparse.RawDescriptionHelpFormatter,
    description=__doc__)
p.add_argument("-t", "--target",     default="blinky")
p.add_argument("--pcf",              default="alchitry_cu_br_all.pcf")

# Individual stages
p.add_argument("--rtl",    action="store_true", help="RTL elaboration only (yosys -p 'prep')")
p.add_argument("--synth",  action="store_true", help="Full synthesis to iCE40 netlist JSON")
p.add_argument("--pnr",    action="store_true", help="Place and route (nextpnr)")
p.add_argument("--timing", action="store_true", help="Static timing analysis (icetime)")
p.add_argument("--pack",   action="store_true", help="Pack ASC to bitstream BIN (icepack)")
p.add_argument("--prog",   action="store_true", help="Program device (iceprog)")
p.add_argument("--all",    action="store_true", help="Run synth + pnr + timing + pack")

# Inspection flags (can be combined with any stage)
p.add_argument("--show-stats",  action="store_true",
               help="Print resource usage after synthesis (cells, LUTs, BRAMs, FFs)")
p.add_argument("--show-brams",  action="store_true",
               help="Print each inferred BRAM with width/depth from synthesis log")
p.add_argument("--rtl-dot",     action="store_true",
               help="Emit RTL schematic as DOT + open in xdot (requires xdot)")
p.add_argument("--synth-dot",   action="store_true",
               help="Emit post-synth netlist as DOT + open in xdot")
p.add_argument("--gui",         action="store_true",
               help="Open nextpnr GUI after PnR (shows LUT/FF/wire placement)")
p.add_argument("--timing-gui",  action="store_true",
               help="Colour critical path in nextpnr GUI (implies --gui)")
p.add_argument("--icebox",      action="store_true",
               help="Run icebox_explain on the ASC — human-readable tile dump")
p.add_argument("--icebox-stat", action="store_true",
               help="Run icebox_stat — concise resource counts from placed design")
p.add_argument("--clean",       action="store_true", help="Remove build artefacts")
p.add_argument("--verbose",     action="store_true", help="Echo every command before running")

args = p.parse_args()
top = args.target

os.makedirs(BUILD, exist_ok=True)
os.makedirs(WAVES, exist_ok=True)

src_files = " ".join(DEPS.get(top, [f"hdl/{top}.v"]))

# Output paths
json_f   = f"{BUILD}/{top}.json"
rtl_il_f = f"{BUILD}/{top}_rtl.il"   # RTLIL after prep (pre-tech-map)
asc_f    = f"{BUILD}/{top}.asc"
bin_f    = f"{BUILD}/{top}.bin"
log_s    = f"{BUILD}/{top}_synth.log"
log_p    = f"{BUILD}/{top}_pnr.log"
log_t    = f"{BUILD}/{top}_timing.log"
rtl_dot  = f"{BUILD}/{top}_rtl.dot"
syn_dot  = f"{BUILD}/{top}_syn.dot"

# ── Helpers ────────────────────────────────────────────────────────────────
def run(cmd, desc=""):
    if desc:
        print(f"\n{'='*60}")
        print(f"  {desc}")
        print(f"{'='*60}")
    if args.verbose:
        print(f"  CMD: {cmd}")
    ret = os.system(cmd)
    if ret != 0:
        print(f"\n[FAILED] exit code {ret}")
        sys.exit(ret)

def need(path, stage):
    if not os.path.exists(path):
        print(f"[ERROR] {stage} requires {path} — run the preceding stage first.")
        sys.exit(1)

def grep_log(path, pattern, label):
    """Print matching lines from a log file."""
    if not os.path.exists(path):
        return
    print(f"\n--- {label} ---")
    found = False
    with open(path) as f:
        for line in f:
            if pattern.lower() in line.lower():
                print(" ", line.rstrip())
                found = True
    if not found:
        print(f"  (no lines matching '{pattern}')")

def open_dot(dot_path, label):
    """Render a DOT file and open it — tries xdot first, then dot→PNG fallback."""
    if not os.path.exists(dot_path):
        print(f"[WARN] DOT file not found: {dot_path}")
        return
    png_path = dot_path.replace(".dot", ".png")
    # Try xdot (interactive, pan/zoom) — best option
    if os.system(f"which xdot > /dev/null 2>&1") == 0:
        print(f"Opening {label} in xdot…")
        subprocess.Popen(["xdot", dot_path])
    # Fall back to graphviz dot → PNG, then xdg-open
    elif os.system(f"which dot > /dev/null 2>&1") == 0:
        print(f"Rendering {label} to {png_path}…")
        os.system(f"dot -Tpng {dot_path} -o {png_path}")
        subprocess.Popen(["xdg-open", png_path])
    else:
        print(f"[WARN] Neither xdot nor graphviz dot found.")
        print(f"       DOT file saved to: {dot_path}")
        print(f"       Paste into https://dreampuf.github.io/GraphvizOnline/ to view.")

# ── Clean ──────────────────────────────────────────────────────────────────
if args.clean:
    os.system(f"rm -rf {BUILD}/*")
    print("Build directory cleaned.")
    sys.exit(0)

# ══════════════════════════════════════════════════════════════════════════
# STAGE 1 — RTL elaboration
# Runs yosys 'prep' which:
#   - Parses Verilog and resolves hierarchy
#   - Inlines parameters
#   - Expands always blocks to RTL logic
#   - Does NOT tech-map to iCE40 primitives
# The resulting RTLIL or DOT view shows your design as pure logic —
# adders, muxes, registers — before any cell mapping.
# This is the best view for finding unintended combinational loops,
# checking that hierarchy flattened as expected, and seeing what
# Yosys understood your intent to be.
# ══════════════════════════════════════════════════════════════════════════
if args.rtl or args.rtl_dot:
    desc = "RTL elaboration (prep — no tech mapping)"

    if args.rtl_dot:
        # Write DOT schematic of the RTL netlist — one box per module
        # 'show' with -format dot emits Graphviz. -stretch improves layout.
        # Warning: large designs produce enormous graphs. Use hierarchy view
        # first (no -flatten) then drill into a module with 'show <modname>'.
        dot_cmd = (f"yosys -p '"
                   f"read_verilog {src_files}; "
                   f"hierarchy -check -top {top}; "
                   f"proc; opt; "
                   f"show -format dot -prefix {BUILD}/{top}_rtl {top}"
                   f"' -l {log_s}_rtl.log")
        run(dot_cmd, desc + " + DOT schematic")
        open_dot(rtl_dot, "RTL schematic")
    else:
        # Just elaborate to RTLIL — fast, logs hierarchy and any errors
        rtl_cmd = (f"yosys -p '"
                   f"read_verilog {src_files}; "
                   f"hierarchy -check -top {top}; "
                   f"proc; opt; "
                   f"write_rtlil {rtl_il_f}"
                   f"' -l {log_s}_rtl.log")
        run(rtl_cmd, desc)
        print(f"  RTLIL written to {rtl_il_f}")
        print(f"  Log:             {log_s}_rtl.log")


# ══════════════════════════════════════════════════════════════════════════
# STAGE 2 — Synthesis
# synth_ice40 runs the full iCE40 synthesis flow:
#   - abc  : logic optimisation and technology mapping to LUT4s
#   - BRAM inference (SB_RAM40_4K)
#   - DSP inference (SB_MAC16, if present)
#   - Produces a JSON netlist consumable by nextpnr
#
# --show-stats: parses the log for the "Printing statistics" section
#   which tells you exactly how many SB_LUT4, SB_DFF*, SB_RAM40_4K,
#   SB_CARRY cells were used. This is where you see BRAM inference.
#
# --show-brams: grep for the RAM mapping lines specifically, e.g.:
#   "Mapping to SB_RAM40_4K with width=9, depth=16"
# ══════════════════════════════════════════════════════════════════════════
if args.synth or args.all or args.synth_dot:
    synth_cmd = (f"yosys -p 'synth_ice40 -top {top} -json {json_f}' "
                 f"-l {log_s} "
                 f"{src_files}")
    run(synth_cmd, "Synthesis → iCE40 JSON netlist")

    if args.show_stats:
        grep_log(log_s, "=== design hierarchy ===", "Design hierarchy")
        grep_log(log_s, "SB_", "Cell usage (iCE40 primitives)")

    if args.show_brams:
        grep_log(log_s, "bram", "BRAM inference")
        grep_log(log_s, "SB_RAM", "BRAM cells instantiated")
        # Also look for the RAM mapping report
        grep_log(log_s, "Mapping to", "Technology mapping decisions")

    if args.synth_dot:
        # Post-synthesis DOT — shows the actual iCE40 cells (LUT4, DFF, BRAM)
        # Use this to verify BRAM inference visually and trace critical paths
        # at the cell level. Much more detailed than the RTL view.
        dot_cmd = (f"yosys -p '"
                   f"read_json {json_f}; "
                   f"show -format dot -prefix {BUILD}/{top}_syn {top}"
                   f"'")
        run(dot_cmd, "Post-synthesis DOT schematic")
        open_dot(syn_dot, "Post-synthesis netlist")


# ══════════════════════════════════════════════════════════════════════════
# STAGE 3 — Place and Route
# nextpnr-ice40 takes the JSON netlist and:
#   - Assigns each cell to a physical tile (placement)
#   - Routes wires through the routing fabric
#   - Produces an ASC (ASCII bitstream) file
#
# --gui: opens the nextpnr GUI *after* PnR completes.
#   What you can see in the GUI:
#   - Chip overview: every LUT, FF, BRAM, IO tile visible as coloured blocks
#   - Routing: individual wires drawn as lines across the fabric
#   - Timing: click "Critical Path" to highlight the worst slack path
#     in red/orange from source FF to destination FF
#   - Cell inspector: click any cell to see its type, location, connections
#   - Packing view: see which LUTs got packed into the same 4-LUT cluster
#   Navigation: scroll to zoom, drag to pan, 'F' to fit, click to inspect
#
# --timing-gui: passes --report to nextpnr which annotates the GUI with
#   timing weights on every arc — lets you see *why* a path is critical.
# ══════════════════════════════════════════════════════════════════════════
if args.pnr or args.all or args.gui or args.timing_gui:
    need(json_f, "PnR")

    timing_report = f"{BUILD}/{top}_timing_report.json"
    pnr_flags = ""
    if args.timing_gui:
        pnr_flags += f" --report {timing_report}"

    if args.gui or args.timing_gui:
        # Run PnR then reopen the placed design in the GUI
        # The --gui flag on nextpnr opens the interactive viewer
        # You get the full chip floorplan with your design placed and routed
        pnr_cmd = (f"nextpnr-ice40 --{DEVICE} --package {PACKAGE} "
                   f"--json {json_f} "
                   f"--pcf {args.pcf} --asc {asc_f} "
                   f"--log {log_p} "
                   f"{pnr_flags} "
                   f"--gui")
        run(pnr_cmd, "Place and Route + GUI")
    else:
        pnr_cmd = (f"nextpnr-ice40 --{DEVICE} --package {PACKAGE} "
                   f"--json {json_f} "
                   f"--pcf {args.pcf} --asc {asc_f} "
                   f"--log {log_p} "
                   f"{pnr_flags}")
        run(pnr_cmd, "Place and Route")

    if args.show_stats:
        grep_log(log_p, "Info: Device utilisation", "Device utilisation")
        grep_log(log_p, "Info: Max frequency", "Timing summary")


# ══════════════════════════════════════════════════════════════════════════
# STAGE 4 — Static timing analysis (icetime)
# icetime reads the ASC and performs path-based timing analysis.
# It reports:
#   - The critical path: the longest combinational chain between registers
#   - The worst-case delay in ns
#   - The maximum achievable clock frequency for your design
# Flags used:
#   -tmd : timing model for the device
#   -p   : read the PCF for pin names in the report
#   -r   : write a detailed path report
#   -t   : print total delay of each path segment
# The -d hx8k flag selects the HX8K timing model.
# ══════════════════════════════════════════════════════════════════════════
if args.timing or args.all:
    need(asc_f, "Timing analysis")
    timing_cmd = (f"icetime "
                  f"-d {DEVICE} "
                  f"-p {args.pcf} "
                  f"-t "         # print path details
                  f"-r {log_t} " # write detailed report
                  f"{asc_f}")
    run(timing_cmd, "Static timing analysis (icetime)")
    if os.path.exists(log_t):
        print(f"\n  Full timing report: {log_t}")
        # Print the summary lines (always at the end)
        with open(log_t) as f:
            lines = f.readlines()
        for line in lines[-10:]:
            print(" ", line.rstrip())


# ══════════════════════════════════════════════════════════════════════════
# STAGE 5 — icebox tools (ASC inspection)
# These tools work directly on the ASC text file, which is a human-readable
# description of every configuration bit in every tile of the iCE40.
#
# icebox_explain:
#   Translates each tile's configuration bits into plain English.
#   Output like: "Tile (12,8): LUT input A connected to net foo_out"
#   Useful for low-level debugging — did the router actually connect
#   what you think it connected? Are IOs configured correctly?
#   Warning: output is very verbose (thousands of lines for real designs).
#   Pipe through grep for the signal you care about.
#
# icebox_stat:
#   Counts how many of each resource type are used vs available.
#   Faster and cleaner than reading the nextpnr log.
#   Output: LUTs used/total, FFs, BRAMs, IOs, PLLs, etc.
# ══════════════════════════════════════════════════════════════════════════
if args.icebox:
    need(asc_f, "icebox_explain")
    explain_f = f"{BUILD}/{top}_explained.txt"
    run(f"icebox_explain {asc_f} > {explain_f}",
        "icebox_explain — human-readable tile dump")
    print(f"\n  Full explanation: {explain_f}")
    print(f"  Tip: grep that file for a net name to trace a specific signal")
    print(f"  e.g.: grep 'spi_sclk' {explain_f}")

if args.icebox_stat:
    need(asc_f, "icebox_stat")
    run(f"icebox_stat {asc_f}", "icebox_stat — resource counts from placed design")


# ══════════════════════════════════════════════════════════════════════════
# STAGE 6 — Pack ASC → BIN
# icepack converts the human-readable ASC configuration file into the
# binary bitstream that iceprog sends to the FPGA.
# Nothing interesting to inspect here, but separating it lets you
# examine the ASC before committing to programming.
# ══════════════════════════════════════════════════════════════════════════
if args.pack or args.all:
    need(asc_f, "icepack")
    run(f"icepack {asc_f} {bin_f}", "Pack ASC → BIN bitstream")
    if os.path.exists(bin_f):
        size = os.path.getsize(bin_f)
        print(f"  Bitstream: {bin_f}  ({size:,} bytes)")


# ══════════════════════════════════════════════════════════════════════════
# STAGE 7 — Program
# ══════════════════════════════════════════════════════════════════════════
if args.prog:
    need(bin_f, "iceprog")
    run(f"iceprog {bin_f}", "Program device")


# ── Summary ────────────────────────────────────────────────────────────────
print(f"\n{'='*60}")
print(f"  Done. Build artefacts in {BUILD}/")
present = [(p, f"{BUILD}/{n}") for p, n in [
    ("RTLIL",    f"{top}_rtl.il"),
    ("JSON",     f"{top}.json"),
    ("ASC",      f"{top}.asc"),
    ("BIN",      f"{top}.bin"),
    ("Synth log",f"{top}_synth.log"),
    ("PnR log",  f"{top}_pnr.log"),
    ("Timing",   f"{top}_timing.log"),
] if os.path.exists(f"{BUILD}/{n}")]
for label, path in present:
    print(f"  {label:<12} {path}")
print(f"{'='*60}\n")
