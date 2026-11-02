#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""编译并运行 riscv-tests 的 rv32ui-p-* 测试。

需要先准备 riscv-tests（含 env 子模块）：
    git clone --recursive https://github.com/riscv-software-src/riscv-tests.git /tmp/riscv-tests
    export RISCV_TESTS=/tmp/riscv-tests

用法：
    python3 tests/riscv-tests/run_rv32ui.py
    python3 tests/riscv-tests/run_rv32ui.py --test add --test ma_data
    python3 tests/riscv-tests/run_rv32ui.py --riscv-tests /path/to/riscv-tests --rebuild

产物位于 build/rv32ui/（可随时删除）。
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "build" / "rv32ui"
SIMDIR = OUT / "obj_dir"
CROSS = "riscv64-unknown-elf-"
TEST_SRC = [
    "simple",
    "add", "addi", "and", "andi", "auipc",
    "beq", "bge", "bgeu", "blt", "bltu", "bne",
    "fence_i", "jal", "jalr",
    "lb", "lbu", "lh", "lhu", "lw", "ld_st", "lui", "ma_data",
    "or", "ori",
    "sb", "sh", "sw", "st_ld",
    "sll", "slli", "slt", "slti", "sltiu", "sltu",
    "sra", "srai", "srl", "srli", "sub",
    "xor", "xori",
]


def run(cmd, cwd=None, quiet=False):
    if not quiet:
        print("+", " ".join(str(c) for c in cmd))
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=quiet)


def build_sim(rebuild=False):
    sim = SIMDIR / "sim"
    if sim.exists() and not rebuild:
        return sim

    verilator = shutil.which("verilator")
    if verilator is None:
        sys.exit("找不到 verilator")

    cmd = [
        verilator, "--binary", "--timing",
        "-Wno-lint", "-Wno-fatal", "-Wno-WIDTH", "-Wno-UNUSED",
        "-Wno-UNDRIVEN", "-Wno-PINMISSING", "-Wno-CASEINCOMPLETE",
        "-j", str(os.cpu_count() or 4),
        "-y", str(ROOT / "src" / "core"),
        "--Mdir", str(SIMDIR),
        "--top-module", "tb_rv32ui",
        str(HERE / "tb_rv32ui.v"),
        str(ROOT / "src" / "core" / "core.v"),
        str(ROOT / "src" / "uncore.v"),
        str(ROOT / "src" / "i_cache_ram.v"),
        str(ROOT / "src" / "d_cache_ram.v"),
        "-o", "sim",
    ]
    r = run(cmd, cwd=ROOT, quiet=True)
    if r.returncode != 0:
        print(r.stdout)
        print(r.stderr)
        sys.exit("Verilator 编译失败")
    return sim


def compile_test(name, riscv_tests, with_misalign=True):
    src = riscv_tests / "isa" / "rv32ui" / (name + ".S")
    if not src.exists():
        sys.exit("找不到测试源：%s" % src)

    elf = OUT / (name + ".elf")
    bin_file = OUT / (name + ".bin")
    hex_file = OUT / (name + ".hex")

    cmd = [
        CROSS + "gcc",
        "-march=rv32i_zicsr_zifencei", "-mabi=ilp32",
        "-static", "-mcmodel=medany", "-fvisibility=hidden",
        "-nostdlib", "-nostartfiles",
        "-I", str(HERE / "env" / "p"),
        "-I", str(riscv_tests / "isa" / "macros" / "scalar"),
        "-I", str(riscv_tests / "env"),
        "-T", str(HERE / "env" / "p" / "link.ld"),
        str(src),
    ]
    if with_misalign:
        cmd.append(str(HERE / "env" / "p" / "misalign.S"))
    cmd += ["-o", str(elf)]

    r = run(cmd, cwd=ROOT, quiet=True)
    if r.returncode != 0:
        print(r.stdout)
        print(r.stderr)
        return False, "GCC 编译失败"

    r = run([
        CROSS + "objcopy", "-O", "binary",
        "-R", ".tohost", "-R", ".riscv.attributes",
        str(elf), str(bin_file),
    ], cwd=ROOT, quiet=True)
    if r.returncode != 0:
        print(r.stdout)
        print(r.stderr)
        return False, "objcopy 失败"

    data = bin_file.read_bytes()
    limit = 64 * 1024          # 0x10000 ~ 0x1ffff
    if len(data) > limit:
        return False, "镜像超过 64KB（%d 字节）" % len(data)
    data += b"\x00" * (limit - len(data))
    with open(hex_file, "w") as f:
        for i in range(0, len(data), 2):
            f.write("%04x\n" % int.from_bytes(data[i:i + 2], "little"))
    return True, hex_file


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--riscv-tests", default=os.environ.get("RISCV_TESTS", ""),
                    help="riscv-tests 仓库路径，默认取 RISCV_TESTS 环境变量")
    ap.add_argument("--test", action="append", default=[],
                    help="只跑指定测试，可重复")
    ap.add_argument("--rebuild", action="store_true", help="强制重新编译仿真器")
    args = ap.parse_args()

    if not args.riscv_tests:
        sys.exit(
            "需要 riscv-tests 仓库。先执行：\n"
            "  git clone --recursive https://github.com/riscv-software-src/riscv-tests.git /tmp/riscv-tests\n"
            "  export RISCV_TESTS=/tmp/riscv-tests"
        )
    riscv_tests = Path(args.riscv_tests).resolve()
    if not (riscv_tests / "isa" / "rv32ui" / "Makefrag").exists():
        sys.exit("RISCV_TESTS 路径不对：%s" % riscv_tests)

    OUT.mkdir(parents=True, exist_ok=True)
    sim = build_sim(args.rebuild)

    tests = args.test or TEST_SRC
    passed = 0
    failed = []
    for name in tests:
        ok, res = compile_test(name, riscv_tests)
        if not ok:
            print("%-10s BUILD-FAIL  %s" % (name, res))
            failed.append(name)
            continue
        r = run([str(sim), "+TESTHEX=%s" % res], cwd=ROOT, quiet=True)
        line = (r.stdout or r.stderr).strip().splitlines()
        line = line[0] if line else "NO OUTPUT"
        if line.startswith("PASS"):
            passed += 1
            print("%-10s %s" % (name, line))
        else:
            failed.append(name)
            print("%-10s %s" % (name, line))

    print("\nrv32ui-p: %d passed, %d failed" % (passed, len(failed)))
    if failed:
        print("FAILED: " + " ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()
