#!/usr/bin/env python3
"""对比两组 bench 采集（@@RESULT 行）的逐用例耗时，用于 A/B 实验或历史留档比对。

每侧可给多个采集文件，同一用例跨文件取最小值（最小值对 E 核调度、后台抢占等
单向噪声最稳健——最好的一次最接近代码的真实成本）。随后逐用例算 B/A 比值，并给出
中位比值（两侧共同的机器态在此归零）。

用法：
    python .devtools/bench_compare.py --a head1.txt head2.txt --b cur1.txt cur2.txt
    python .devtools/bench_compare.py --a old.txt --b new.txt --threshold 1.3

输出按 B/A 比值降序；超过阈值（默认 1.25，即 B 比 A 慢 25%）的用例标记 [SLOWER]，
低于其倒数的标记 [FASTER]。只在一侧出现的用例单独列出，不参与比值。
"""

import argparse
import io
import statistics
import sys
from pathlib import Path


def load_side(paths):
    """返回 {用例键: 最小 ns}；用例键为 kind|group|name。"""
    best = {}
    for p in paths:
        text = Path(p).read_text(encoding="utf-8", errors="replace")
        for ln in text.splitlines():
            if not ln.startswith("@@RESULT"):
                continue
            parts = ln.strip().split("|")
            if len(parts) < 6:
                continue
            key = "|".join(parts[1:4])
            try:
                ns = int(parts[4])
            except ValueError:
                continue
            if key not in best or ns < best[key]:
                best[key] = ns
    return best


def fmt(ns):
    if ns < 10_000:
        return f"{ns:.0f} ns"
    if ns < 10_000_000:
        return f"{ns / 1000:.2f} us"
    return f"{ns / 1_000_000:.3f} ms"


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="对比两组 @@RESULT 采集的逐用例耗时")
    ap.add_argument("--a", nargs="+", required=True, help="A 侧采集文件（基准侧）")
    ap.add_argument("--b", nargs="+", required=True, help="B 侧采集文件（对比侧）")
    ap.add_argument("--threshold", type=float, default=1.25, help="标记阈值（默认 1.25）")
    args = ap.parse_args()

    side_a = load_side(args.a)
    side_b = load_side(args.b)
    common = sorted(set(side_a) & set(side_b))
    if not common:
        print("两侧没有共同用例。")
        return 2

    rows = []
    for key in common:
        a, b = side_a[key], side_b[key]
        rows.append((key, a, b, b / a if a > 0 else float("inf")))
    rows.sort(key=lambda r: -r[3])

    ratios = [r[3] for r in rows]
    median = statistics.median(ratios)
    print(f"共同用例 {len(rows)} 个 ｜ B/A 中位比值 {median:.2f}x（共同机器态已在最小值采样中部分抵消）")
    print(f"标记阈值：慢于 {args.threshold:.2f}x 记 [SLOWER]，快于 {1 / args.threshold:.2f}x 记 [FASTER]\n")
    width = max(len(r[0]) for r in rows)
    slower = 0
    for key, a, b, ratio in rows:
        mark = ""
        if ratio > args.threshold:
            mark = "  [SLOWER]"
            slower += 1
        elif ratio < 1 / args.threshold:
            mark = "  [FASTER]"
        print(f"  {key.ljust(width)}  {fmt(a):>11} -> {fmt(b):>11}   {ratio:5.2f}x{mark}")

    only_a = sorted(set(side_a) - set(side_b))
    only_b = sorted(set(side_b) - set(side_a))
    if only_a:
        print(f"\n仅 A 侧有的用例（{len(only_a)} 个）：")
        for key in only_a:
            print(f"  {key}  {fmt(side_a[key])}")
    if only_b:
        print(f"\n仅 B 侧有的用例（{len(only_b)} 个）：")
        for key in only_b:
            print(f"  {key}  {fmt(side_b[key])}")
    return 1 if slower else 0


if __name__ == "__main__":
    sys.exit(main())
