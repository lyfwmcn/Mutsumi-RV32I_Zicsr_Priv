#!/usr/bin/env python3
"""Readable nextpnr timing report: hierarchy/RTL hot-spots, collapsed paths, run diff.

Consumes the JSON written by:
    nextpnr-ecp5 ... --report build/timing.json --detailed-timing-report

Usage:
    python3 tools/timing_report.py [JSON] [--top N] [--limit N]
                                   [--min-delay NS] [--full] [--all-paths]
                                   [--diff OLD.json]

Without a positional JSON it uses build/timing.json (fallback
build/test_timing.json).  Unlike tools/json_deal.py this never writes the input.

Note on attribution: nextpnr attaches RTL `src` tags to routing segments only,
and yosys `techmap` overwrites the src of internal-module cells.  So the RTL
line table is accurate for top-level nets only; use the module table and the
collapsed path to localize delay inside submodules.
"""
import argparse
import json
import os
import sys

DEFAULT_PRIMARY = "build/timing.json"
DEFAULT_FALLBACK = "build/test_timing.json"


# ---------------------------------------------------------------- loading

def pick_default():
    if os.path.exists(DEFAULT_PRIMARY):
        return DEFAULT_PRIMARY
    if os.path.exists(DEFAULT_FALLBACK):
        return DEFAULT_FALLBACK
    return DEFAULT_PRIMARY


def load(path):
    with open(path) as f:
        return json.load(f)


# ---------------------------------------------------------------- helpers

def is_user_source(s):
    """Drop yosys/techmap internal source tags, keep real RTL files."""
    if "/share/yosys/" in s or "/yosys/" in s:
        return False
    if s.startswith("/usr"):
        return False
    return True


def user_sources(seg):
    return [s for s in (seg.get("sources") or []) if is_user_source(s)]


def src_line(s):
    """'path/file.v:12.3-12.9' -> 'path/file.v:12'."""
    head = s.split("-")[0]
    parts = head.split(":")
    if len(parts) >= 2:
        return parts[0] + ":" + parts[1].split(".")[0]
    return s


def module_of(cell):
    if not cell:
        return "(top)"
    return cell.split(".", 1)[0] if "." in cell else "(top)"


def is_setup_path(p):
    return p.get("to") != "<async>" and not str(p.get("to", "")).startswith("<")


def setup_paths(d):
    return [p for p in d.get("critical_paths", []) if is_setup_path(p)]


def path_total(p):
    return sum(float(s.get("delay", 0.0)) for s in p.get("path", []))


# ---------------------------------------------------------------- attribution

def segment_attributions(path):
    """(module, rtl_line|None, delay) for each segment of a path.

    Logic segments carry no source tags, so attribute them to the sources of
    the following routing segment (the net that logic drives).
    """
    segs = path.get("path", [])
    out = []
    for i, seg in enumerate(segs):
        delay = float(seg.get("delay", 0.0))
        mod = module_of(seg.get("from", {}).get("cell"))
        line = None
        if seg.get("type") == "logic":
            srcs = user_sources(segs[i + 1]) if i + 1 < len(segs) else []
            line = src_line(srcs[0]) if srcs else None
        elif seg.get("type") == "routing":
            srcs = user_sources(seg)
            line = src_line(srcs[0]) if srcs else None
        out.append((mod, line, delay))
    return out


def all_hotspots(d, all_paths=False):
    paths = d.get("critical_paths", []) if all_paths else setup_paths(d)
    mods, lines = {}, {}
    for p in paths:
        for mod, line, delay in segment_attributions(p):
            mods[mod] = mods.get(mod, 0.0) + delay
            if line:
                lines[line] = lines.get(line, 0.0) + delay
    return mods, lines


def collapse(atts, min_delay):
    """Group consecutive equal (module, line); return (groups, shown, total)."""
    groups = []
    for mod, line, delay in atts:
        if groups and groups[-1][0] == mod and groups[-1][1] == line:
            groups[-1][2] += delay
            groups[-1][3] += 1
        else:
            groups.append([mod, line, delay, 1])
    total = sum(g[2] for g in groups)
    if min_delay > 0:
        shown = [g for g in groups if g[2] >= min_delay]
    else:
        shown = groups
    return groups, shown, total


def sorted_delta(old, new, limit):
    keys = set(old) | set(new)
    rows = [(k, new.get(k, 0.0) - old.get(k, 0.0)) for k in keys]
    rows.sort(key=lambda kv: -abs(kv[1]))
    return rows[:limit]


# ---------------------------------------------------------------- printing

def hr(title):
    print()
    print("== %s ==" % title)
    print("-" * 72)


def print_fmax(d):
    hr("Fmax")
    fmax = d.get("fmax", {})
    if not fmax:
        print("  (no clock domains reported)")
        return
    for clk, v in fmax.items():
        ach = float(v.get("achieved", 0.0))
        con = float(v.get("constraint", 0.0))
        ap = 1000.0 / ach if ach > 0 else float("inf")
        cp = 1000.0 / con if con > 0 else float("inf")
        print("  %s" % clk)
        print("    achieved   : %8.2f MHz  (%.3f ns)" % (ach, ap))
        print("    constraint : %8.2f MHz  (%.3f ns)" % (con, cp))
        print("    slack      : %8.3f ns   %s"
              % (cp - ap, "PASS" if ach >= con else "FAIL"))


def print_hotspots(d, limit, all_paths):
    mods, lines = all_hotspots(d, all_paths)
    total = sum(mods.values())
    label = "all paths" if all_paths else "setup paths (reg -> reg)"
    hr("Hot spots by module [%s]" % label)
    if not mods:
        print("  (none)")
    else:
        print("  %-30s %10s %8s" % ("module", "delay(ns)", "share"))
        for m, v in sorted(mods.items(), key=lambda kv: -kv[1])[:limit]:
            print("  %-30s %10.3f %7.1f%%"
                  % (m, v, 100.0 * v / total if total else 0.0))
    print()
    print("  Hot spots by net source  (post-techmap: only top-level nets keep RTL src)")
    if not lines:
        print("  (no RTL source tags found in routing segments)")
        return
    print("  %-30s %10s %8s" % ("location", "delay(ns)", "share"))
    for l, v in sorted(lines.items(), key=lambda kv: -kv[1])[:limit]:
        print("  %-30s %10.3f %7.1f%%"
              % (l, v, 100.0 * v / total if total else 0.0))


def print_paths(d, top, min_delay, full):
    paths = d.get("critical_paths", [])
    hr("Critical paths (%d)" % len(paths))
    if not paths:
        print("  (none)")
        return
    for pi, p in enumerate(paths[:top] if top else paths, 1):
        total = path_total(p)
        print()
        print("[%d] %s" % (pi, p.get("from", "?")))
        print("     -> %s" % p.get("to", "?"))
        print("     total %.3f ns  (%.2f MHz)  %d segments"
              % (total, 1000.0 / total if total else 0.0, len(p.get("path", []))))
        if full:
            print("     %-4s %-10s %10s %-24s %s"
                  % ("#", "type", "delay(ns)", "cell", "net / rtl"))
            for j, seg in enumerate(p.get("path", []), 1):
                cell = seg.get("from", {}).get("cell", "?")
                net = seg.get("net") or ""
                srcs = user_sources(seg)
                src = src_line(srcs[0]) if srcs else ""
                print("     %-4d %-10s %10.3f %-24s %s"
                      % (j, seg.get("type", "?"), float(seg.get("delay", 0.0)),
                         cell, net or src))
            continue
        groups, shown, _ = collapse(segment_attributions(p), min_delay)
        shown_ids = set(id(g) for g in shown)
        print("     %-4s %-12s %-22s %9s %9s  %s"
              % ("#", "module", "rtl", "delay", "cum", "detail"))
        cum = 0.0
        idx = 0
        for g in groups:
            cum += g[2]
            if id(g) not in shown_ids:
                continue
            idx += 1
            print("     %-4d %-12s %-22s %9.3f %9.3f  %d seg"
                  % (idx, g[0], g[1] or "-", g[2], cum, g[3]))
        hidden = len(groups) - len(shown)
        if hidden:
            print("     (%d group(s) < %.3f ns hidden)" % (hidden, min_delay))


def print_utilization(d, limit=12):
    hr("Utilization")
    util = d.get("utilization", {})
    rows = []
    for name, v in util.items():
        used = int(v.get("used", 0))
        avail = int(v.get("available", 0))
        if used:
            rows.append((name, used, avail, 100.0 * used / avail if avail else 0.0))
    if not rows:
        print("  (none)")
        return
    rows.sort(key=lambda r: (-r[3], r[0]))
    print("  %-20s %10s %10s %8s" % ("resource", "used", "available", "used%"))
    for name, used, avail, pct in rows[:limit]:
        print("  %-20s %10d %10d %7.1f%%" % (name, used, avail, pct))


def print_diff(old, new, limit=15):
    hr("Diff vs previous run")
    of, nf = old.get("fmax", {}), new.get("fmax", {})
    print("  Fmax")
    for clk in sorted(set(of) | set(nf)):
        o = float(of.get(clk, {}).get("achieved", 0.0))
        n = float(nf.get(clk, {}).get("achieved", 0.0))
        d = n - o
        print("    %-32s %8.2f -> %8.2f MHz  (%s%.2f)"
              % (clk, o, n, "+" if d >= 0 else "", d))

    def totals(d):
        return {(p.get("from", "?"), p.get("to", "?")): path_total(p)
                for p in d.get("critical_paths", [])}

    ot, nt = totals(old), totals(new)
    print("  Critical path totals (ns)")
    for k in sorted(set(ot) | set(nt)):
        o, n = ot.get(k), nt.get(k)
        if o is None:
            print("    [new ] %s -> %s : %.3f" % (k[0], k[1], n))
        elif n is None:
            print("    [gone] %s -> %s : was %.3f" % (k[0], k[1], o))
        else:
            d = n - o
            print("    %s -> %s : %.3f -> %.3f  (%s%.3f)"
                  % (k[0], k[1], o, n, "+" if d >= 0 else "", d))

    om, ol = all_hotspots(old)
    nm, nl = all_hotspots(new)
    print("  Module delta (new - old)")
    for m, d in sorted_delta(om, nm, limit):
        print("    %-30s %+9.3f ns" % (m, d))
    print("  RTL line delta (new - old)")
    dd = sorted_delta(ol, nl, limit)
    if not dd:
        print("    (no RTL source tags)")
    for l, d in dd:
        print("    %-30s %+9.3f ns" % (l, d))


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(
        description="Readable nextpnr timing report with hot-spot attribution.")
    ap.add_argument("json", nargs="?", default=None,
                    help="nextpnr timing JSON (default: build/timing.json)")
    ap.add_argument("--top", type=int, default=0,
                    help="max critical paths to show (0 = all)")
    ap.add_argument("--limit", type=int, default=15,
                    help="hot-spot table rows (default 15)")
    ap.add_argument("--min-delay", type=float, default=0.0, metavar="NS",
                    help="hide collapsed hops below NS ns")
    ap.add_argument("--full", action="store_true",
                    help="print every raw path segment instead of collapsed hops")
    ap.add_argument("--all-paths", action="store_true",
                    help="hot-spots over all paths, not just reg->reg setup paths")
    ap.add_argument("--diff", metavar="OLD.json", default=None,
                    help="compare against an earlier nextpnr timing JSON")
    args = ap.parse_args()

    path = args.json or pick_default()
    if not os.path.exists(path):
        print("file not found: %s" % path, file=sys.stderr)
        sys.exit(1)
    d = load(path)
    print("Timing report: %s" % path)
    print("=" * 72)
    print_fmax(d)
    print_hotspots(d, args.limit, args.all_paths)
    print_paths(d, args.top, args.min_delay, args.full)
    print_utilization(d)
    if args.diff:
        if not os.path.exists(args.diff):
            print("diff file not found: %s" % args.diff, file=sys.stderr)
        else:
            print_diff(load(args.diff), d)


if __name__ == "__main__":
    main()
