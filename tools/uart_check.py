#!/usr/bin/env python3
"""上板串口自检：读 iCELink 的 USB 串口，和 build/boot.bin 逐字节比对。

板上程序（tests/boot_rom/uart_prog.s，烧进 ROM 0~4K）每轮：
    12 行 x 16 字节，行尾 '~'，轮末 '\\n'，然后延时约 0.2 s 再重复。
本脚本收流、按行比对，分别统计：
    - 数据错字节（真错误，FPGA/缓存/ROM 的问题）
    - 链接丢字节（iCELink 的 USB 缓冲溢出，固件会往流里插 "<iCELink:Overflow>"）

注意：必须关掉 IXON/XOFF，并且**显式设置波特率** ——
镜像里有 0x13(XOFF)/0x11(XON)，主机 tty 若开着软件流控会静默丢字节；
而 CDC ACM 会把 line coding 传给 iCELink，继承 tty 原有波特率会解出乱码。
所以这里直接改 termios 属性副本再一次性 tcsetattr。

用法：
    python3 tools/uart_check.py                      # 默认 /dev/ttyACM0，收 10 轮
    python3 tools/uart_check.py -p /dev/ttyACM0 -n 20 -t 30
"""

import argparse
import os
import sys
import termios
import time

LINES = 12          # 每轮行数
LINE_BYTES = 16     # 每行字节数
OVERFLOW = b"<iCELink:Overflow>"


def open_port(dev):
    fd = os.open(dev, os.O_RDONLY | os.O_NOCTTY | os.O_NONBLOCK)
    iflag, oflag, cflag, lflag, ispeed, ospeed, cc = termios.tcgetattr(fd)
    # 波特率必须显式指定（CDC 会把它发给 iCELink）
    ispeed = ospeed = termios.B115200
    iflag &= ~(termios.IXON | termios.IXOFF | termios.IXANY |
               termios.INLCR | termios.ICRNL | termios.IGNCR |
               termios.ISTRIP | termios.INPCK)
    oflag &= ~termios.OPOST
    lflag &= ~(termios.ECHO | termios.ECHONL | termios.ICANON |
               termios.ISIG | termios.IEXTEN)
    cflag &= ~(termios.CSIZE | termios.PARENB | termios.CSTOPB)
    cflag |= termios.CS8 | termios.CREAD | termios.CLOCAL
    if hasattr(termios, "CRTSCTS"):
        cflag &= ~termios.CRTSCTS
    cc = list(cc)
    cc[termios.VMIN] = 0
    cc[termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW,
                      [iflag, oflag, cflag, lflag, ispeed, ospeed, cc])
    return fd


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-p", "--port", default="/dev/ttyACM0")
    ap.add_argument("-b", "--bin", default="build/boot.bin")
    ap.add_argument("-n", "--rounds", type=int, default=10, help="比对多少轮后退出")
    ap.add_argument("-t", "--timeout", type=float, default=30.0, help="总超时（秒）")
    ap.add_argument("-q", "--quiet", action="store_true")
    args = ap.parse_args()

    try:
        img = open(args.bin, "rb").read()
    except OSError as e:
        sys.exit(f"读不到镜像 {args.bin}: {e}")
    need = LINES * LINE_BYTES
    if len(img) < need:
        # ROM 里程序后面是 0（boot.hex 按 256 行补零），镜像短了就按 0 补齐
        print(f"提示：{args.bin} 只有 {len(img)} 字节，后面按 0 补齐到 {need}")
        img = img + b"\x00" * (need - len(img))
    exp = [img[i * LINE_BYTES:(i + 1) * LINE_BYTES] for i in range(LINES)]

    try:
        fd = open_port(args.port)
    except OSError as e:
        sys.exit(f"打不开 {args.port}: {e}")

    if not args.quiet:
        print(f"串口 {args.port} 已打开（115200 raw，无流控），等数据…")

    buf = bytearray()
    good = 0          # 完整且逐字节正确的轮数
    data_bad = 0      # 数据错字节数
    link_bad = 0      # 因链接丢字节而残缺的轮数
    overflow = 0      # iCELink 溢出提示次数
    total_lines = 0
    first_bad = None
    started = False
    t0 = time.time()

    while (time.time() - t0) < args.timeout and good < args.rounds:
        try:
            chunk = os.read(fd, 8192)
        except BlockingIOError:
            chunk = b""
        if not chunk:
            time.sleep(0.0002)
            continue

        if OVERFLOW in chunk or OVERFLOW in buf:
            overflow += chunk.count(OVERFLOW) if OVERFLOW in chunk else 0
            chunk = chunk.replace(OVERFLOW, b"")
        buf += chunk

        # 只处理以 '\n' 结尾的完整轮
        while True:
            i = buf.find(b"\n")
            if i < 0:
                break
            rd = bytes(buf[:i])
            del buf[:i + 1]
            if not started:          # 第一段可能是残轮，丢掉
                started = True
                continue
            segs = rd.split(b"~")
            if len(segs) != LINES + 1 or segs[-1] != b"":
                link_bad += 1        # 行数/行长度不对 = 链接丢字节
                if not args.quiet:
                    print(f"  [LINK] 残缺轮：{len(segs) - 1} 行"
                          f"（长度 {[len(s) for s in segs[:-1]][:4]}…）")
                continue
            round_bad = 0
            for ln in range(LINES):
                if len(segs[ln]) != LINE_BYTES:
                    link_bad += 1
                    round_bad = -1
                    break
            if round_bad < 0:
                if not args.quiet:
                    print("  [LINK] 行长度异常（链接丢字节）")
                continue
            total_lines += LINES
            for ln in range(LINES):
                if segs[ln] != exp[ln]:
                    for k in range(LINE_BYTES):
                        if segs[ln][k] != exp[ln][k]:
                            data_bad += 1
                            if first_bad is None:
                                first_bad = (good, ln, k, exp[ln][k], segs[ln][k])
            good += 1
            if not args.quiet:
                print(f"  第 {good} 轮完成（累计错字节 {data_bad}）")

    os.close(fd)

    print()
    if good == 0:
        print(f"[FAIL] {args.timeout:.0f}s 内没有收到完整的一轮数据")
        return 1
    tag = "PASS" if data_bad == 0 else "FAIL"
    print(f"[{tag}] {good} 轮 / {total_lines} 行 / {total_lines * LINE_BYTES} 字节，"
          f"数据错字节 {data_bad}，链接丢字节轮数 {link_bad}，iCELink 溢出 {overflow} 次")
    if first_bad:
        r, ln, k, e, g = first_bad
        print(f"        首个不一致：轮 {r} 行 {ln} 字节 {k}：期望 {e:02x} 实际 {g:02x}")
    return 0 if data_bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
