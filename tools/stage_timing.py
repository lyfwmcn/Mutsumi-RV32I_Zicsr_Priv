#!/usr/bin/env python3
"""Parse nextpnr `--report ... --detailed-timing-report` JSON into a per-pipeline-stage
delay table (Markdown + CSV).

Usage: tools/stage_timing.py [build/timing.json]

Outputs:
  build/stage_timing.md    narrative + per-stage table
  build/stage_timing.csv   launch_stage,capture_stage,max_delay_ns

Data used (see nextpnr common/kernel/report.cc):
  - fmax.<clock>.{achieved,constraint}
  - critical_paths[].path[] : segments {from.cell, to.cell, delay, type, net}
  - detailed_net_timings[]  : per net {driver, sources[], endpoints[{cell,port,delay[min,max]}]}
    `driver`/`endpoints[].cell` are cell instance names; `sources` is the Verilog
    `src` location attribute (e.g. "src/IDStage.v:79..."), NOT a cell name
    (see nextpnr net_sources()). endpoint delay = accumulated arrival (ns) from
    the launch register to that sink.
"""

import collections
import json
import os
import sys

# Hierarchical-name token -> pipeline stage. Order matters (first match wins).
STAGE_TOKENS = [
    ("IFStage", "IF"),
    ("InstrBufferUnit", "IF"),
    ("IDStage", "ID"),
    ("EXStage", "EX"),
    ("M1Stage", "M1"),
    ("M2Stage", "M2"),
    ("SystemBus", "MEM"),
    ("RegFile", "WB"),
    ("CSRFile", "WB"),
    ("PrivilegeMode", "WB"),
]

STAGE_ORDER = ["IF", "ID", "EX", "M1", "MEM", "M2", "WB", "OTHER"]


def stage_of(name):
    for tok, st in STAGE_TOKENS:
        if tok in name:
            return st
    return "OTHER"


def as_float(v):
    if isinstance(v, (int, float)):
        return float(v)
    if isinstance(v, list) and v:
        return max(float(x) for x in v)
    return 0.0


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "build/timing.json"
    if not os.path.exists(path):
        print("timing report not found:", path, file=sys.stderr)
        sys.exit(1)
    with open(path) as f:
        d = json.load(f)

    # ---- per (launch stage -> capture stage) worst arrival delay ----
    # `sources` holds RTL src locations, not cells, so the drive/launch stage
    # comes from the driving cell (`driver`).
    table = collections.defaultdict(float)
    edges = collections.Counter()
    for net in d.get("detailed_net_timings", []):
        lstage = stage_of(net.get("driver", ""))
        for ep in net.get("endpoints", []):
            cstage = stage_of(ep.get("cell", ""))
            delay = as_float(ep.get("delay"))
            key = (lstage, cstage)
            table[key] = max(table[key], delay)
            edges[key] += 1

    # ---- worst critical path (for cross-check / segment breakdown) ----
    crit_rows = []
    for cp in d.get("critical_paths", []):
        seg_by_stage = collections.defaultdict(float)
        total = 0.0
        segs = cp.get("path", [])
        for seg in segs:
            st = stage_of(seg.get("from", {}).get("cell", ""))
            dly = as_float(seg.get("delay"))
            seg_by_stage[st] += dly
            total += dly
        first = segs[0].get("from", {}).get("cell", "?") if segs else "?"
        last = segs[-1].get("to", {}).get("cell", "?") if segs else "?"
        crit_rows.append((cp.get("from", "?"), cp.get("to", "?"), total, first, last,
                          dict(seg_by_stage), len(segs)))

    # ---- render ----
    lines = []
    lines.append("# Pipeline stage timing (ECP5, --freq 25 MHz)\n")
    fmax = d.get("fmax", {})
    for clk, v in fmax.items():
        lines.append("- clock `%s`: achieved **%.2f MHz**, constraint %.2f MHz"
                     % (clk, v.get("achieved", 0.0), v.get("constraint", 0.0)))
    lines.append("")

    lines.append("## Worst critical path(s)\n")
    for frm, to, total, first, last, byst, nseg in crit_rows:
        lines.append("- `%s` -> `%s`: **%.3f ns** (%d segments)" % (frm, to, total, nseg))
        lines.append("  - start `%s`  end `%s`" % (first, last))
        if byst:
            lines.append("  - per-stage delay: "
                         + ", ".join("%s=%.3fns" % (s, byst[s])
                                     for s in sorted(byst, key=lambda x: -byst[x])))
    lines.append("")

    lines.append("## Per-stage delay table (driver stage -> sink stage)\n")
    lines.append("Row = stage of the net's driving cell; column = stage of the sink cell. "
                 "Value = worst accumulated arrival delay (ns) from the launch register over all "
                 "nets in `detailed_net_timings`.\n")
    stages = [s for s in STAGE_ORDER if any(k[0] == s or k[1] == s for k in table)]
    lines.append("| launch \\ capture | " + " | ".join(stages) + " |")
    lines.append("|" + "---|" * (len(stages) + 1))
    for ls in stages:
        row = ["%.3f" % table[(ls, cs)] if (ls, cs) in table else "-" for cs in stages]
        lines.append("| **%s** | %s |" % (ls, " | ".join(row)))
    lines.append("")

    lines.append("## Adjacent-stage delays (worst per stage pair)\n")
    adj = [("IF", "ID"), ("ID", "EX"), ("EX", "M1"), ("M1", "M2"), ("M2", "WB"),
           ("M1", "MEM"), ("MEM", "M2"), ("M2", "MEM"), ("WB", "IF"), ("EX", "EX"),
           ("ID", "ID"), ("M2", "M2"), ("MEM", "MEM")]
    lines.append("| pair | worst (ns) | nets |")
    lines.append("|---|---|---|")
    for a, b in adj:
        if (a, b) in table:
            lines.append("| %s -> %s | %.3f | %d |" % (a, b, table[(a, b)], edges[(a, b)]))
    lines.append("")

    md = "\n".join(lines) + "\n"
    with open("build/stage_timing.md", "w") as f:
        f.write(md)

    with open("build/stage_timing.csv", "w") as f:
        f.write("launch_stage,capture_stage,max_delay_ns,nets\n")
        for (a, b), v in sorted(table.items(), key=lambda kv: -kv[1]):
            f.write("%s,%s,%.4f,%d\n" % (a, b, v, edges[(a, b)]))

    # console summary
    print(md)
    print("written: build/stage_timing.md, build/stage_timing.csv")


if __name__ == "__main__":
    main()
