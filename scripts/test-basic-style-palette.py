#!/usr/bin/env python3
"""Check opaque stock sRGB role pairs, not arbitrary custom/translucent pixel scenes."""
from pathlib import Path
import re
import unittest


def luminance(rgb):
    channels = [value / 255 for value in rgb]
    linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
    return sum(weight * value for weight, value in zip((0.2126, 0.7152, 0.0722), linear))


def contrast(first, second):
    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


class BasicPaletteTest(unittest.TestCase):
    def test_opaque_stock_text_role_pairs(self):
        source = (Path(__file__).resolve().parents[1] / "src/core/theme.cj").read_text()
        for mode in ("light", "dark"):
            with self.subTest(mode=mode):
                body = re.search(r"public static func " + mode + r"\([\s\S]*?Theme\(([\s\S]*?)\n        \)", source)
                self.assertIsNotNone(body, "stock theme representation changed; review the palette test")
                colors = {name: tuple(map(int, (r, g, b))) for name, r, g, b in
                          re.findall(r"(\w+): Color\.rgb\((\d+), (\d+), (\d+)\)", body[1])}
                for foreground, background in (("text", "bg"), ("text", "panel"),
                                               ("mutedText", "bg"), ("mutedText", "panel"),
                                               ("danger", "bg"), ("accentText", "accent")):
                    ratio = contrast(colors[foreground], colors[background])
                    print(f"{mode}: {foreground}/{background} = {ratio:.3f}:1")
                    self.assertGreaterEqual(ratio, 4.5, f"{mode}: {foreground}/{background}")


if __name__ == "__main__":
    unittest.main()
