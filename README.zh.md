<div align="center">

# flash-cjk.nvim

在 Neovim 中输入拼音、罗马音或罗马字，即可跳转到任意中、日、韩字符——无需切换输入法。基于
[flash.nvim](https://github.com/folke/flash.nvim) 构建，fork 自
[flash-zh.nvim](https://github.com/rainzm/flash-zh.nvim)。

[English](README.md) · [简体中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md)

[![Validate](https://github.com/fang2hou/flash-cjk.nvim/actions/workflows/validate.yml/badge.svg)](https://github.com/fang2hou/flash-cjk.nvim/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)

</div>

## 为什么

为了跳转到 CJK 文本而再去输入 CJK 文本，意味着操作中途还得与输入法缠斗。flash-cjk 让你的双手始终停留在 ASCII 上：`ni` 落在 日 / に / ニ，`r` 按拼音首字母命中 日，`dkss` 按两拼（두벌식）键位命中 안녕——同时普通字母依然按字面匹配，与 flash.nvim 的行为完全一致。

- 覆盖范围：中文拼音（小鹤双拼与拼音首字母）、日语罗马音（汉字读音与假名，黑本式与训令式）、韩语（修订版罗马字与两拼（두벌식）键序）、ASCII 字面匹配——全部同时生效，且可各自独立开关
- 不在范围内：取代 flash.nvim 自带功能（treesitter 跳转、remote 等）；输入法集成；NFD 形式的韩文文件名（见已知限制）
- 状态：活跃开发中

## 安装

需要 [flash.nvim](https://github.com/folke/flash.nvim)；使用
[lazy.nvim](https://github.com/folke/nvim-lazy) 安装：

```lua
return {{
    "fang2hou/flash-cjk.nvim",
    event = "VeryLazy",
    dependencies = "folke/flash.nvim",
    -- 可选的 Rust 加速器（见“Rust 加速”）：随安装/更新自动构建；
    -- 若没有 cargo，插件会静默改走 vim-regex 路径。
    -- 删除这一行即可完全跳过构建。
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

旧模块名依然可用：`require("flash-zh")` 会转发到
`flash-cjk`；已有配置无需任何改动。

## 使用

按下 `s`，输入，跳转——流程与 flash.nvim 一致。如果目标上还没出现标签，继续输入即可（就像搜索一样）；标签使用小写字母，且绝不会与可见匹配项可能出现的下一个输入字母冲突。

**配合 AI 编程代理**——把下面这段话粘贴给代理，把仓库交给它：

```text
Work in this repository. Read AGENTS.md at the repository root first and follow it.
```

### 输入中途强制锁定语言

输入过程中，按 `C-c` / `C-j` / `C-k` / `C-e` 可将匹配锁定为中文 / 日语 / 韩语 / 英语，并立即重新计算：

- `ti` 同时匹配中文（梯/踢…）与日语（ち，训令式）；按下 `C-c` 后只剩中文读音——ち 不再匹配
- 锁定会叠加进输入串：**退格删过标记即解除锁定**；按其他锁定键可直接切换
- 锁定期间，英文字面匹配不受影响
- 按键可配置（设为 `false` 可禁用）：

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

### 语言开关

每个匹配器都可独立开关——全局经 setup 设置，或通过语言代码数组只作用于某次跳转：

```lua
require("flash-cjk").setup({
    cn = "xiaohe",   -- 中文拼音；true / false，或方案名
    jp = "roma",     -- 日语罗马音（汉字读音 + 假名）
    ko = "roma",     -- 韩语（罗马字 + 两拼（두벌식）键位）
    en = true,       -- ASCII 字面字母（纯 flash.nvim 行为）
    alpha_mixing = true,
})

require("flash-cjk").jump({ "jp", "ko", "en" })  -- 本次跳转：不匹配中文
```

`cn`/`jp`/`ko` 接受 `true`（默认方案）、`false`（关闭）或方案名字符串——中文为 `"xiaohe"`，日语/韩语为 `"roma"`（目前仅有的方案，今后可扩展）。不带数组的 `jump()` 使用 setup 启用集；给定数组即完整决定该次跳转的启用集（`"kr"` 是 `"ko"` 的别名），并优先于 setup 开关。第二个参数用于透传 flash 选项：`jump(nil, { force_keys = { cn = "<C-d>" } })`。

单语言用户只需保留一个开关。注意事项：

- 关闭 `en` 后，数字与大写字母仍按字面匹配；无法解读的输入（如 `n.`）会退化为字面匹配。
- 标点跟随语言开关：关闭 `cn` 时，`,` 匹配 、（日文）而非 ，（全角逗号）；`。` 为中日共用，始终匹配；`-` → ー 归属 `jp`。
- `alpha_mixing = false`（性能选项）：丢弃字面字母与语言片段混排的解释（例如某些继承自 flash-zh 的 `nihao` 变体）；三语长输入下最坏情况延迟降低 40–60%，代价是部分混合链路不可达。

### 匹配规则

- **中文**：小鹤双拼两键编码与拼音首字母——`ni` → 你，`r` → 日。
- **日语**：汉字读音取自 Unicode Unihan（`kJapanese`/`On`/`Kun`，约 13,000 个汉字），按最长 3 个字母的罗马音前缀匹配（`n`/`ni`/`nic` 均命中 日）；假名匹配其音节的所有常见罗马字拼法（`si`/`shi`、`tu`/`tsu`）；拗音成对作为一个整体匹配（`sha` → しゃ/シャ）；`-` 匹配 ー，`[`/`]` → 「」『』，`,` → 、，`!` → ！。
- **韩语**：音节按规则程序化分解为韩文字母（初声 × 中声 × 终声）——无需词典数据。罗马字：修订版（2000 年式），外加常见的 McCune-Reischauer 拼法（`kim`/`gim` → 김），逐音节按前缀匹配；两拼（두벌식）键位可同时使用（`dkss` → 안녕，`gkrry` → 학교，`dkswek` → 앉다）；紧音字母需按 shift——请改用罗马字（`kk`）；单元音片段可像日语元音一样出现在输入中间（`ai` → 아이）。

### 自定义匹配字符

覆盖或追加默认的标点/字符映射表：

```lua
require('flash-cjk').setup {
    char_map = {
        comma = {
            [']'] = ']」',   -- 覆盖一条默认的 flypy.comma 条目
            ['!'] = '!！',   -- 添加默认表中没有的符号
        },
        append_comma = { ['.'] = '…' },
        append_char1 = { ['a'] = 'äÄ' },
        append_char2 = {},
    }
}
```

## Rust 加速（可选）

可选的原生匹配器一次构建、自动启用：按下方基准测试，每次按键的平均开销降低
1.6×、p95 尾部延迟降低 4.1×，并且对正则选择分支已超出 Vim 编译上限（E872）的模式依然可用。上面
lazy 配置中的 `build =` 行会自动处理；手动构建：

```sh
cd rust && cargo build --release
```

[rust/README.md](rust/README.md)。

## 性能

<p align="center">
  <img
    src="assets/benchmark.svg"
    alt="基准测试：vim-regex 路径与原生 Rust 匹配器在三类混合 CJK 窗口下的每次按键开销"
    width="720"
  />
</p>

在真实的按键路径上测量：1,050 个生成的混合 CJK 窗口（每个 20–60 行），字符取样自插件自带的数据表，按键序列为
1–6 个合理键击，固定随机种子。

| 窗口内容                  | vim-regex 平均 |   Rust 平均 |     提速 | vim-regex p95 |    Rust p95 |
| ------------------------- | -------------: | ----------: | -------: | ------------: | ----------: |
| 中文 + 日文               |        10.9 ms |     10.0 ms |     1.1× |       66.5 ms |     17.0 ms |
| 日文 + 韩文               |        24.0 ms |     10.9 ms |     2.2× |       91.8 ms |     19.7 ms |
| 中文 + 日文 + 韩文 + 英文 |        16.1 ms |     11.1 ms |     1.5× |       74.1 ms |     21.0 ms |
| **总体**                  |    **17.0 ms** | **10.7 ms** | **1.6×** |   **80.4 ms** | **19.4 ms** |

**方法。** 每个用例先跑一次预热，再取 3 次测量遍的中位数（`vim.uv.hrtime`）。vim-regex
计时覆盖真实按键付出的全部成本：模式分段、选择分支正则的构建、`vim.regex()`
编译，以及对每个可见行的匹配扫描。Rust 计时同样覆盖全部成本：`vim.system`
进程创建与 JSON 往返，与插件实际调用方式一致。1,050 个模式中有 4 个产生的选择分支超出了
Vim NFA 引擎的上限（E872）——它们没有 vim-regex 计时，而 Rust 匹配器全部处理成功。

**如何解读。** 短前缀（头一两个字母）在 vim-regex 路径上更快——总体中位数为 1.7 ms
对 9.3 ms——因为原生路径每次按键都要支付固定下限：约 0.9 ms 的进程创建加约 7.8 ms
的二进制启动（数据表初始化）。原生路径换来的是尾部：长的多解释模式让 vim-regex
路径每键花费 60–90+ ms（打字时明显卡顿），而原生路径保持在 ~20 ms 以内，且永远不会撞上
E872 编译墙。

**系统影响。** 原生匹配器每个按键、每个可见窗口创建一个短命进程（上方基准测试为单窗口）。每次调用约
9–11 ms 墙钟时间，几乎全部来自进程创建（约 0.9 ms）与二进制的数据表启动（约
7.8 ms）；DP 匹配本身只增加亚毫秒到几毫秒，因此 CPU/电池开销取决于打字速度——大约每个键、每个窗口一次小型进程启动。二进制约 1.8
MB，数据表静态内嵌，无运行时依赖，只在一次按键期间驻留内存。若二进制缺失、构建失败或运行时反复失败，熔断器会触发，每次按键透明回退到
vim-regex 路径——匹配结果完全一致，由交叉验证套件保证。当进程创建昂贵或受限（沙箱、加固环境），或你主要输入
1–2 字母前缀（此时它本来就更快）时，优先选择纯 vim-regex 路径（即干脆不构建二进制）。

在自己的机器上复现：

```sh
cargo build --release --manifest-path rust/Cargo.toml
nvim -l benches/compare.lua # 写入 benches/results.json
uv run benches/gen_svg.py   # 重新生成 assets/benchmark.svg
```

## 已知限制

- macOS 以 NFD（分解的韩文字母序列）存储韩文文件名；两条匹配路径都针对 NFC 预组合音节，因此在 oil/netrw 的文件名缓冲区中跳转时无法匹配韩文文件名。普通代码与文档缓冲区为 NFC，不受影响。

## 延伸阅读

| 目标             | 阅读                                                                       |
| ---------------- | -------------------------------------------------------------------------- |
| 开发与验证       | [DEVELOPMENT.md](./DEVELOPMENT.md)                                         |
| 了解系统         | [ARCHITECTURE.md](./ARCHITECTURE.md)                                       |
| 参与贡献         | [CONTRIBUTING.md](./CONTRIBUTING.md)                                       |
| 交给 AI 代理     | [AGENTS.md](./AGENTS.md)                                                   |
| 原生匹配器设计   | [rust/README.md](./rust/README.md)                                         |
| 阅读其他语言版本 | [简体中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) |

## 环境要求

- Neovim ≥ 0.10，配合 [flash.nvim](https://github.com/folke/flash.nvim)
- 可选：较新的 Rust（≥ 1.97，cargo）用于原生加速器——没有它一切功能照常可用
- 开发工具链：由 mise 管理（参见 [DEVELOPMENT.md](./DEVELOPMENT.md)）

## 许可证

MIT——见 [LICENSE](./LICENSE)。数据衍生自
[Unicode Unihan 数据库](https://www.unicode.org/)（Unicode License）。感谢
[flash-zh.nvim](https://github.com/rainzm/flash-zh.nvim) 与
[hop-zh-by-flypy](https://github.com/zzhirong/hop-zh-by-flypy)。
