#!/usr/bin/env python3
"""Regenerate pinned Unicode 15.1 grapheme properties/tests from local official files.

No network access. Input SHA-256 values are part of the reproducible source contract.
Run with --check in CI after supplying the four original Unicode data files.
"""
import argparse
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = {
    "GraphemeBreakProperty.txt": "a7e52eee647e52dc210b8719b4d7037276f4b353810293d69377fc46374cec3f",
    "DerivedCoreProperties.txt": "f55d0db69123431a7317868725b1fcbf1eab6b265d756d1bd7f0f6d9f9ee108b",
    "emoji-data.txt": "d7aef489c8fe4c14f09ea5695200277c6b93ac82ac60845cdd2161b0d6835cc1",
    "GraphemeBreakTest.txt": "ed9c5e92fd0911ccbeeb63c97cb19c519ea272ff1112ce843abd991582dd848f",
}
GCB = {name: index for index, name in enumerate([
    "Other", "CR", "LF", "Control", "Extend", "ZWJ", "Regional_Indicator",
    "Prepend", "SpacingMark", "L", "V", "T", "LV", "LVT"])}
HEADER = """package chui.core

// Generated from Unicode15.1 official data by scripts/generate-grapheme-data.py.
// Copyright © 2023 Unicode, Inc. Distributed under LICENSE-UNICODE (Unicode-3.0).
// Do not hand-edit; input hashes and original download paths are in the generator/manual.

"""


def rows(content):
    for line in content.splitlines():
        body = line.split("#", 1)[0].strip()
        if body:
            yield [part.strip() for part in body.split(";")]


def table(content, select):
    result = []
    for fields in rows(content):
        value = select(fields[1:])
        if not value:
            continue
        bounds = fields[0].split("..")
        lo, hi = int(bounds[0], 16), int(bounds[-1], 16)
        result.append((lo, hi, value))
    merged = []
    for lo, hi, value in sorted(result):
        if merged and lo <= merged[-1][1]:
            raise ValueError("overlapping property ranges")
        if merged and lo == merged[-1][1] + 1 and value == merged[-1][2]:
            merged[-1] = (merged[-1][0], hi, value)
        else:
            merged.append((lo, hi, value))
    return merged


def render_table(name, values):
    lines = [f"private let {name}: Array<UInt32> = ["]
    lines += [f"    UInt32(0x{lo:X}), UInt32(0x{hi:X}), UInt32({value})," for lo, hi, value in values]
    lines += ["]", ""]
    return "\n".join(lines)


def render_tests(content):
    cases = []
    for line in content.splitlines():
        tokens = line.split("#", 1)[0].split()
        if not tokens:
            continue
        points, offsets, byte = [], [], 0
        for token in tokens:
            if token == "÷":
                offsets.append(byte)
            elif token != "×":
                point = int(token, 16)
                points.append(point)
                byte += len(chr(point).encode("utf-8"))
        literal = '"' + "".join(f"\\u{{{point:X}}}" for point in points) + '"'
        cases.append(f"    assertOfficialGrapheme({literal}, [{', '.join(map(str, offsets))}])")
    if len(cases) != 1187:
        raise ValueError(f"unexpected official corpus size: {len(cases)}")
    out = HEADER
    for start in range(0, len(cases), 100):
        out += f"@Test\nfunc unicode151OfficialGraphemeBreaks{start // 100}(): Unit {{\n"
        out += "\n".join(cases[start:start + 100]) + "\n}\n\n"
    out += """private func assertOfficialGrapheme(text: String, expected: Array<Int64>): Unit {
    let index = GraphemeIndex(text)
    @Expect(index.count + 1, expected.size)
    for (i in 0..expected.size) {
        @Expect(index.boundary(i), expected[i])
    }
}
"""
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--check", action="store_true")
    options = parser.parse_args()
    data = {}
    for name, expected in FILES.items():
        raw = (options.input / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != expected:
            raise ValueError(f"untrusted or wrong-version Unicode input: {name}")
        data[name] = raw.decode("utf-8")
    gcb = table(data["GraphemeBreakProperty.txt"], lambda f: GCB[f[0]])
    incb = table(data["DerivedCoreProperties.txt"],
                 lambda f: {"Consonant": 1, "Linker": 2, "Extend": 3}[f[1]] if f[0] == "InCB" else 0)
    pictographic = table(data["emoji-data.txt"], lambda f: 1 if f[0] == "Extended_Pictographic" else 0)
    source = HEADER + render_table("GRAPHEME_GCB", gcb) + render_table("GRAPHEME_INCB", incb)
    source += render_table("GRAPHEME_PICTOGRAPHIC", pictographic)
    source += """
internal func graphemeGcb(point: UInt32): Int64 { graphemeRangeValue(GRAPHEME_GCB, point) }
internal func graphemeIncb(point: UInt32): Int64 { graphemeRangeValue(GRAPHEME_INCB, point) }
internal func graphemePictographic(point: UInt32): Bool {
    graphemeRangeValue(GRAPHEME_PICTOGRAPHIC, point) != 0
}

private func graphemeRangeValue(ranges: Array<UInt32>, point: UInt32): Int64 {
    if (point >= UInt32(0x20) && point <= UInt32(0x7E)) { return 0 }
    var low: Int64 = 0
    var high = ranges.size / 3
    while (low < high) {
        let mid = low + (high - low) / 2
        if (point < ranges[mid * 3]) {
            high = mid
        } else if (point > ranges[mid * 3 + 1]) {
            low = mid + 1
        } else {
            return Int64(ranges[mid * 3 + 2])
        }
    }
    0
}
"""
    outputs = {"unicode_grapheme_data.cj": source,
               "unicode_grapheme_test.cj": render_tests(data["GraphemeBreakTest.txt"])}
    for name, content in outputs.items():
        target = ROOT / "src/core" / name
        if options.check:
            if target.read_text() != content:
                raise ValueError(f"stale generated file: {name}")
        else:
            target.write_text(content)
    print(f"Unicode15.1: GCB={len(gcb)} InCB={len(incb)} EP={len(pictographic)}; official cases=1187")


if __name__ == "__main__":
    main()
