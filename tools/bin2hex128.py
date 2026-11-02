#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把二进制镜像转成 128 位一行的 hex（给 boot_rom 的 $readmemh 用）。

用法：
    python3 tools/bin2hex128.py <in.bin> <out.hex> [lines]

每行 32 个十六进制字符 = 16 字节（一小条 cache line，SDRAM 按行写）。
不足 lines 行时补 0，方便 boot_loader 用固定行数。
"""
import sys

if len(sys.argv) < 3:
    print(__doc__)
    sys.exit(1)

src, dst = sys.argv[1], sys.argv[2]
lines = int(sys.argv[3]) if len(sys.argv) > 3 else 0

data = open(src, 'rb').read()
while len(data) % 16:
    data += b'\x00'

need = len(data) // 16
if lines and need > lines:
    sys.exit("镜像太大：%d 行 > 上限 %d 行（%d 字节）" % (need, lines, lines * 16))

out = []
for i in range(0, len(data), 16):
    out.append('%032x' % int.from_bytes(data[i:i + 16], 'little'))
if lines:
    while len(out) < lines:
        out.append('%032x' % 0)

open(dst, 'w').write('\n'.join(out) + '\n')
print("生成 %s：%d 行（%d 字节）" % (dst, len(out), len(data)))
