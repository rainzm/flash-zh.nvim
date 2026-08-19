<div align="center">

# flash-cjk.nvim

Jump to any Chinese, Japanese, or Korean character in Neovim by typing its
pinyin, romaji, or romanization — no IME switching. Built on
[flash.nvim](https://github.com/folke/flash.nvim), forked from
[flash-zh.nvim](https://github.com/rainzm/flash-zh.nvim).

[English](README.md) · [简体中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md)

[![Validate](https://github.com/fang2hou/flash-cjk.nvim/actions/workflows/validate.yml/badge.svg)](https://github.com/fang2hou/flash-cjk.nvim/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)

</div>

## Why

Typing CJK text to jump to CJK text means fighting your IME mid-motion.
flash-cjk keeps your hands in ASCII: `ni` lands on 日 / に / ニ, `r` hits 日
by pinyin initial, `dkss` hits 안녕 by two-set keys — while plain letters still
match literally, exactly like flash.nvim.

- In scope: Chinese pinyin (flypy and initials), Japanese romaji (kanji
  readings plus kana, Hepburn and kunrei-shiki), Korean (revised romanization
  and dubeolsik key sequences), literal ASCII — all simultaneously and
  independently toggleable
- Out of scope: replacing flash.nvim's own features (treesitter jumps,
  remote, …); IME integration; NFD Korean filenames (see known limitations)
- Status: actively developed

## Install

Requires [flash.nvim](https://github.com/folke/flash.nvim); install with
[lazy.nvim](https://github.com/folke/nvim-lazy):

```lua
return {{
    "fang2hou/flash-cjk.nvim",
    event = "VeryLazy",
    dependencies = "folke/flash.nvim",
    -- Optional Rust accelerator (see "Rust acceleration"): built on
    -- install/update; without cargo the plugin silently uses the vim-regex
    -- path instead. Delete this line to skip the build entirely.
    build = "cargo build --release --manifest-path=rust/Cargo.toml",
    keys = {{
        "s",
        mode = {"n", "x", "o"},
        function()
            require("flash-cjk").jump()
        end,
        desc = "Flash between Chinese/Japanese/Korean"
    }}
}, {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
        highlight = {
            backdrop = false,
            matches = false
        }
    }
}}
```

The legacy module name still works: `require("flash-zh")` forwards to
`flash-cjk`; existing configurations need no changes.

## Use it

Press `s`, type, and jump — same flow as flash.nvim. If your target shows no
label yet, keep typing (like a search); labels use lowercase letters and never
collide with a plausible next input letter for a visible match.

**With an AI coding agent** — paste this into the agent to hand it the repository:

```text
Work in this repository. Read AGENTS.md at the repository root first and follow it.
```

### Forcing a language mid-typing

While typing, press `C-c` / `C-j` / `C-k` / `C-e` to lock matching to
Chinese / Japanese / Korean / English and recompute instantly:

- `ti` matches both Chinese (梯/踢…) and Japanese (ち, kunrei-shiki); after
  `C-c` only the Chinese readings remain — ち no longer matches
- Locks stack into the input string: **backspacing over the marker releases
  it**; pressing another lock key switches directly
- Literal English matching is unaffected while locked
- Keys are configurable (or `false` to disable):

```lua
require("flash-cjk").setup({
    force_keys = {
        cn = "<C-c>",
        jp = "<C-j>",
        ko = "<C-k>",
        en = "<C-e>",
    },
})
```

### Language switches

Each matcher toggles independently — globally via setup, or per jump via a
language-code array:

```lua
require("flash-cjk").setup({
    cn = "xiaohe",   -- Chinese pinyin; true / false, or a scheme name
    jp = "roma",     -- Japanese romaji (kanji readings + kana)
    ko = "roma",     -- Korean (romanization + two-set keys)
    en = true,       -- literal ASCII letters (plain flash.nvim behavior)
    alpha_mixing = true,
})

require("flash-cjk").jump({ "jp", "ko", "en" })  -- this jump: no Chinese
```

`cn`/`jp`/`ko` accept `true` (the default scheme), `false` (off), or a scheme
name — `"xiaohe"` for Chinese, `"roma"` for Japanese/Korean (the only schemes
today; more can plug in later). `jump()` without an array uses the
setup-enabled set; a given array fully decides that jump's set (`"kr"` is an
alias of `"ko"`) and overrides the setup switches. The second argument passes
flash options through: `jump(nil, { force_keys = { cn = "<C-d>" } })`.

Single-language users keep one switch on. Notes:

- With `en` off, digits and uppercase still match literally; uninterpretable
  input (like `n.`) degrades to literal matching.
- Punctuation follows the language switches: with `cn` off, `,` matches 、
  (Japanese) instead of ，(fullwidth comma); `。` is shared by zh/ja and always
  matches; `-` → ー belongs to `jp`.
- `alpha_mixing = false` (performance): drops interpretations that mix literal
  letters with language segments (e.g. some `nihao` variants inherited from
  flash-zh); 40–60% lower worst-case latency on long trilingual inputs, at the
  cost of some mixed-chain reachability.

### Matching rules

- **Chinese**: flypy two-key codes and pinyin initials — `ni` → 你, `r` → 日.
- **Japanese**: kanji readings from Unicode Unihan (`kJapanese`/`On`/`Kun`,
  ~13,000 kanji) matched by romaji prefix up to 3 letters (`n`/`ni`/`nic` all
  hit 日); kana match all common romanizations of their syllable
  (`si`/`shi`, `tu`/`tsu`); youon pairs match as one unit (`sha` → しゃ/シャ);
  `-` matches ー, `[`/`]` → 「」『』, `,` → 、, `!` → ！.
- **Korean**: syllables decompose programmatically into jamo (initial × medial
  × final) — no dictionary data. Romanization: revised (2000) plus common
  McCune-Reischauer spellings (`kim`/`gim` → 김), matched per-syllable by
  prefix; two-set (두벌식) keys work alongside (`dkss` → 안녕, `gkrry` → 학교,
  `dkswek` → 앉다); tense jamo need shift — use romanization (`kk`) instead;
  single-vowel segments work mid-input like Japanese vowels (`ai` → 아이).

### Custom match characters

Override or append to the default punctuation/character maps:

```lua
require('flash-cjk').setup {
    char_map = {
        comma = {
            [']'] = ']」',   -- override a default flypy.comma entry
            ['!'] = '!！',   -- add a symbol the default table lacks
        },
        append_comma = { ['.'] = '…' },
        append_char1 = { ['a'] = 'äÄ' },
        append_char2 = {},
    }
}
```

## Rust acceleration (optional)

An optional native matcher builds once and turns on automatically: on the
benchmark below it cuts the mean per-keystroke cost by 1.6× and the p95 tail
by 4.1×, and it keeps working on patterns whose regex alternation no longer
compiles in Vim (E872). The `build =` line in the lazy spec above handles it;
manual build:

```sh
cd rust && cargo build --release
```

Without the binary — or after repeated failures — the plugin transparently
falls back to the pure-Lua vim-regex path with identical behavior, guaranteed
by a strict item-by-item cross-validation suite. Details and measurements:
[rust/README.md](rust/README.md).

## Performance

<p align="center">
  <img
    src="assets/benchmark.svg"
    alt="Benchmark: per-keystroke cost of the vim-regex path vs the native Rust matcher across three mixed-CJK window categories"
    width="720"
  />
</p>

Measured on the live per-keystroke paths: 1,050 generated mixed-CJK windows
(20–60 lines each), characters sampled from the plugin's own data tables,
patterns of 1–6 plausible keystrokes, deterministic seed.

| Window mix                            | vim-regex mean |   Rust mean |  Speedup | vim-regex p95 |    Rust p95 |
| ------------------------------------- | -------------: | ----------: | -------: | ------------: | ----------: |
| Chinese + Japanese                    |        10.9 ms |     10.0 ms |     1.1× |       66.5 ms |     17.0 ms |
| Japanese + Korean                     |        24.0 ms |     10.9 ms |     2.2× |       91.8 ms |     19.7 ms |
| Chinese + Japanese + Korean + English |        16.1 ms |     11.1 ms |     1.5× |       74.1 ms |     21.0 ms |
| **Overall**                           |    **17.0 ms** | **10.7 ms** | **1.6×** |   **80.4 ms** | **19.4 ms** |

**Methodology.** Each case runs one warmup pass and reports the median of 3
measured passes (`vim.uv.hrtime`). The vim-regex timing covers everything a
live keystroke pays: pattern segmentation, alternation build, `vim.regex()`
compile, and the match scan over every visible line. The Rust timing also
covers everything: the `vim.system` process spawn and the JSON round-trip,
exactly as the plugin invokes it. 4 of 1,050 patterns produced an alternation
too large for Vim's NFA engine (E872) — they have no vim-regex timing, while
the Rust matcher handled all of them.

**How to read it.** Short prefixes (the first letter or two) are faster on the
vim-regex path — the overall median is 1.7 ms vs 9.3 ms — because the native
path pays a fixed floor on every keystroke: ~0.9 ms of process creation plus
~7.8 ms of binary startup (data-table initialization). What the native path
buys is the tail: long multi-interpretation patterns cost the vim-regex path
60–90+ ms per keystroke (visibly laggy while typing), while the native path
stays under ~20 ms and never hits the E872 compile wall.

**System impact.** The native matcher spawns one short-lived process per
keystroke per visible window (the benchmark above is single-window). Each
invocation costs ~9–11 ms of wall time, almost all of it process creation
(~0.9 ms) plus the binary's data-table startup (~7.8 ms); the DP matching
itself adds sub-millisecond to a few ms, so the CPU/battery footprint is
bounded by how fast you type — roughly one small process launch per key per
window. The binary is ~1.8 MB, statically carries its data tables, has no runtime
dependencies, and is resident only for the duration of a keystroke. If the
binary is missing, fails to build, or fails repeatedly at runtime, a circuit
breaker trips and every keystroke transparently falls back to the vim-regex
path — identical matches, enforced by the cross-validation suite. Prefer the
pure vim-regex path (i.e. simply don't build the binary) when process
creation is expensive or restricted — sandboxes, hardened environments — or
when you mostly type 1–2 letter prefixes, where it is the faster path anyway.

Reproduce on your own machine:

```sh
cargo build --release --manifest-path rust/Cargo.toml
nvim -l benches/compare.lua # writes benches/results.json
uv run benches/gen_svg.py   # regenerates assets/benchmark.svg
```

## Known limitations

- macOS stores Korean filenames in NFD (decomposed jamo); both matching paths
  target NFC precomposed syllables, so jumping in oil/netrw filename buffers
  won't match Korean filenames. Normal code and document buffers are NFC and
  unaffected.

## What to read next

| Goal                     | Read                                                                       |
| ------------------------ | -------------------------------------------------------------------------- |
| Develop and validate     | [DEVELOPMENT.md](./DEVELOPMENT.md)                                         |
| Understand the system    | [ARCHITECTURE.md](./ARCHITECTURE.md)                                       |
| Contribute a change      | [CONTRIBUTING.md](./CONTRIBUTING.md)                                       |
| Give it to an agent      | [AGENTS.md](./AGENTS.md)                                                   |
| Native matcher design    | [rust/README.md](./rust/README.md)                                         |
| Read in another language | [简体中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) |

## Environment Requirements

- Neovim ≥ 0.10 with [flash.nvim](https://github.com/folke/flash.nvim)
- Optional recent Rust (≥ 1.97, cargo) for the native accelerator — everything works
  without it
- Development toolchain: managed by mise (see [DEVELOPMENT.md](./DEVELOPMENT.md))

## License

MIT — see [LICENSE](./LICENSE). Data derived from the
[Unicode Unihan Database](https://www.unicode.org/) (Unicode License).
Thanks to [flash-zh.nvim](https://github.com/rainzm/flash-zh.nvim) and
[hop-zh-by-flypy](https://github.com/zzhirong/hop-zh-by-flypy).
