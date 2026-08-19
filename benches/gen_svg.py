#!/usr/bin/env python3
"""Generate assets/benchmark.svg from benches/results.json.

Usage (from the repo root, after `nvim -l benches/compare.lua`):

    uv run benches/gen_svg.py

Downloads the Inter font (Google Fonts, SIL OFL 1.1) and embeds it as a
base64 @font-face data URI so the SVG renders identically inside GitHub
README <img> tags with no external references. If the download fails the
script exits with an explicit error instead of shipping unembedded fonts.

Python stdlib only.
"""

from __future__ import annotations

import base64
import json
import os
import re
import sys
import urllib.request
from datetime import date
from html import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS = os.path.join(ROOT, "benches", "results.json")
OUT = os.path.join(ROOT, "assets", "benchmark.svg")

# GitHub-ish palette
INK = "#1F2328"
MUTED = "#59636E"
FAINT = "#8c959f"
BORDER = "#d1d9e0"
TRACK = "#eff2f5"
VIM_COLOR = "#bf8700"  # muted amber — the pure-Lua vim-regex path
RUST_COLOR = "#1a7f37"  # green — the native Rust matcher
CALLOUT_BG = "#dafbe1"
CALLOUT_INK = "#116329"

CATEGORY_LABELS = {
    "zh_ja": "Chinese + Japanese",
    "ja_ko": "Japanese + Korean",
    "zh_ja_ko_en": "Chinese + Japanese + Korean + English",
}

FONT_CSS_URL = (
    "https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap"
)
FONT_UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)


def fail(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": FONT_UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def embed_fonts() -> str:
    """Download Inter (400 + 700, latin subset) and return @font-face CSS."""
    try:
        css = fetch(FONT_CSS_URL).decode("utf-8")
    except Exception as exc:  # noqa: BLE001 - report any network failure
        fail(
            "could not download Inter CSS from Google Fonts "
            f"({exc!r}); refusing to emit an SVG without embedded fonts"
        )
        raise

    # Google's CSS lists several unicode subsets per weight; keep the
    # plain-latin block for each requested weight.
    blocks = re.findall(r"/\*\s*([a-z-]+)\s*\*/\s*@font-face\s*\{(.*?)\}", css, re.S)
    faces: dict[int, str] = {}
    for subset, body in blocks:
        if subset != "latin":
            continue
        weight = re.search(r"font-weight:\s*(\d+)", body)
        url = re.search(r"url\((https://[^)]+\.woff2)\)", body)
        if not (weight and url):
            continue
        w = int(weight.group(1))
        if w in (400, 700) and w not in faces:
            faces[w] = url.group(1)

    missing = [w for w in (400, 700) if w not in faces]
    if missing:
        fail(f"Google Fonts CSS contained no latin woff2 for weights {missing}")

    rules = []
    for weight in (400, 700):
        try:
            data = fetch(faces[weight])
        except Exception as exc:  # noqa: BLE001
            fail(
                f"could not download Inter woff2 (weight {weight}) from "
                f"{faces[weight]} ({exc!r}); refusing to emit an SVG "
                "without embedded fonts"
            )
            raise
        b64 = base64.b64encode(data).decode("ascii")
        rules.append(
            "@font-face{font-family:'InterBench';font-weight:"
            f"{weight};src:url(data:font/woff2;base64,{b64}) "
            "format('woff2');}"
        )
    return "".join(rules)


def fmt_ms(x: float) -> str:
    return f"{x:.1f}" if x >= 10 else f"{x:.2f}"


def fmt_x(x: float) -> str:
    return f"{x:.1f}\u00d7" if x < 10 else f"{x:.0f}\u00d7"


def text(x: float, y: float, s: str, size: float, fill: str, weight: int = 400,
         anchor: str = "start", spacing: float = 0.0) -> str:
    extra = f" letter-spacing='{spacing}'" if spacing else ""
    return (
        f"<text x='{x:.1f}' y='{y:.1f}' font-size='{size}' fill='{fill}' "
        f"font-weight='{weight}' text-anchor='{anchor}'{extra}>"
        f"{escape(s)}</text>"
    )


def rounded(x: float, y: float, w: float, h: float, r: float, fill: str,
            stroke: str | None = None) -> str:
    st = f" stroke='{stroke}'" if stroke else ""
    return (
        f"<rect x='{x:.1f}' y='{y:.1f}' width='{w:.1f}' height='{h:.1f}' "
        f"rx='{r}' fill='{fill}'{st}/>"
    )


def main() -> None:
    if not os.path.isfile(RESULTS):
        fail(f"{RESULTS} not found - run `nvim -l benches/compare.lua` first")
    with open(RESULTS, encoding="utf-8") as fh:
        results = json.load(fh)

    cats = [
        (key, results["categories"][key])
        for key in ("zh_ja", "ja_ko", "zh_ja_ko_en")
    ]
    overall = results["overall"]
    meta = results["meta"]
    total_cases = overall["cases"]
    failures = overall.get("vim_regex_failures", 0)

    font_css = embed_fonts()

    W, H = 960, 620
    LEFT, RIGHT = 40, W - 40
    BODY = RIGHT - LEFT

    parts = []
    parts.append(
        f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
        "viewBox='0 0 %d %d' role='img' "
        "aria-label='Benchmark: vim-regex path versus native Rust matcher, "
        "per-keystroke cost'>" % (W, H)
    )
    parts.append(
        f"<defs><style>{font_css}text{{font-family:'InterBench',Inter,"
        "'Helvetica Neue',Arial,sans-serif;}}</style></defs>"
    )
    # ---------------------------------------------------------------- header
    parts.append(text(LEFT, 54, "flash-cjk.nvim — matcher performance",
                      21, INK, 700))
    parts.append(
        text(LEFT, 76,
             "Per-keystroke search cost: vim-regex path vs native Rust "
             "matcher", 12.5, MUTED)
    )
    parts.append(
        text(LEFT, 93,
             f"{total_cases} generated mixed-CJK windows · characters "
             "sampled from the plugin's data tables · lower is better",
             11.5, MUTED)
    )

    # speedup callout: headline = ratio of means; secondary = tail ratio
    cw, ch, cx, cy = 204, 84, RIGHT - 204, 26
    parts.append(rounded(cx, cy, cw, ch, 10, CALLOUT_BG))
    parts.append(text(cx + 16, cy + 34, fmt_x(overall["mean_ratio"]),
                      28, CALLOUT_INK, 700))
    parts.append(text(cx + 94, cy + 30, "lower mean cost", 11, CALLOUT_INK))
    parts.append(
        text(cx + 16, cy + 56,
             f"per keystroke: {fmt_ms(overall['vim_ms']['mean'])} to "
             f"{fmt_ms(overall['rust_ms']['mean'])} ms",
             9.5, CALLOUT_INK)
    )
    parts.append(
        text(cx + 16, cy + 72,
             f"p95 tail: {fmt_ms(overall['vim_ms']['p95'])} to "
             f"{fmt_ms(overall['rust_ms']['p95'])} ms "
             f"({fmt_x(overall['p95_ratio'])})",
             9.5, CALLOUT_INK)
    )

    # ---------------------------------------------------------------- legend
    ly = 118
    parts.append(rounded(LEFT, ly - 9, 12, 12, 3, VIM_COLOR))
    parts.append(text(LEFT + 18, ly, "vim-regex (pure Lua path)", 11, MUTED))
    parts.append(rounded(LEFT + 172, ly - 9, 12, 12, 3, RUST_COLOR))
    parts.append(
        text(LEFT + 190, ly, "Rust binary (process spawn included)", 11, MUTED)
    )
    parts.append(
        text(RIGHT, ly, "bar scale per category", 9.5, FAINT, 400, "end")
    )
    y = 152
    for cat_id, cat in cats:
        label = CATEGORY_LABELS[cat_id]
        vim_ms = cat["vim_ms"]["mean"]
        rust_ms = cat["rust_ms"]["mean"]
        vmax = max(vim_ms, rust_ms)
        # nice ceiling for tick labels
        ceiling = vmax * 1.12

        parts.append(text(LEFT, y, label, 13, INK, 700))
        parts.append(
            text(RIGHT, y, f"{cat['cases']} cases", 10.5, FAINT, 400, "end")
        )
        y += 12

        for bar_i, (ms, color, name) in enumerate(
            ((vim_ms, VIM_COLOR, "vim-regex"), (rust_ms, RUST_COLOR, "Rust"))
        ):
            y += 12
            # grid ticks + track; numeric tick labels only on the first
            # bar of the group (both bars share the same scale)
            for frac in (0.25, 0.5, 0.75, 1.0):
                gx = LEFT + BODY * frac
                parts.append(
                    f"<line x1='{gx:.1f}' y1='{y:.1f}' x2='{gx:.1f}' "
                    f"y2='{y + 18:.1f}' stroke='{TRACK}' stroke-width='1'/>"
                )
                if bar_i == 0:
                    parts.append(text(gx, y - 3, f"{fmt_ms(ceiling * frac)}",
                                      8.5, FAINT, 400, "middle"))
            parts.append(rounded(LEFT, y, BODY, 18, 9, TRACK))
            bw = max(10.0, BODY * (ms / ceiling))
            parts.append(rounded(LEFT, y, bw, 18, 9, color))
            # value label inside the bar when it fits, outside otherwise
            label_s = f"{name}  {fmt_ms(ms)} ms"
            if bw > 150:
                parts.append(text(LEFT + 14, y + 13, label_s, 11.5,
                                  "#ffffff", 700))
            else:
                parts.append(text(LEFT + bw + 10, y + 13, label_s, 11.5,
                                  INK, 700))
            y += 26
        y += 14

    # ---------------------------------------------------------------- footnote
    fy = H - 96
    parts.append(
        f"<line x1='{LEFT}' y1='{fy - 14}' x2='{RIGHT}' y2='{fy - 14}' "
        f"stroke='{BORDER}' stroke-width='1'/>"
    )
    foot = [
        f"Methodology: {total_cases} cases (20-60 lines each, characters "
        "sampled from the plugin's own data tables), patterns of 1-6 "
        "plausible keystrokes, deterministic seed.",
        "Per case: warmup pass, then the median of 3 measured passes. "
        "Rust timings include the per-keystroke process spawn "
        "(vim.system + JSON round-trip), exactly as in live use.",
        f"Short prefixes favor the vim-regex path (overall p50 "
        f"{fmt_ms(overall['vim_ms']['p50'])} ms vs "
        f"{fmt_ms(overall['rust_ms']['p50'])} ms); the native path trades "
        "that for a flat worst case.",
    ]
    if failures:
        foot.append(
            f"{failures} of {total_cases} patterns exceeded Vim's NFA "
            "capture-group limit (E872) and have no vim-regex timing; "
            "the Rust matcher handled all of them."
        )
    foot.append(
        f"{meta['cpu']} · {meta['os']} · Neovim {meta['neovim']} · "
        f"spawn {fmt_ms(meta.get('process_spawn_ms', 0))} ms + binary "
        f"startup {fmt_ms(meta.get('binary_startup_ms', 0))} ms floor · "
        f"{meta['date']} · rerun: nvim -l benches/compare.lua"
    )
    for i, line in enumerate(foot):
        parts.append(text(LEFT, fy + i * 15, line, 9.8, MUTED))

    parts.append("</svg>")
    svg = "\n".join(parts)

    if len(svg.encode("utf-8")) > 300_000:
        fail(
            f"generated SVG is {len(svg.encode('utf-8'))} bytes "
            "(> 300 KB budget)"
        )

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(svg)
    print(
        f"wrote {OUT} ({len(svg.encode('utf-8')) / 1024:.0f} KB, "
        f"mean ratio {fmt_x(overall['mean_ratio'])}, "
        f"p95 ratio {fmt_x(overall['p95_ratio'])})"
    )


if __name__ == "__main__":
    main()
