# flash-zh.nvim

基于[flash.nvim](https://github.com/folke/flash.nvim)以及小鹤双拼，neovim 中文跳转插件。

![iShot_2023-10-05_19 32 53](https://github.com/rainzm/flash-zh.nvim/assets/22927169/4c3ca124-0fee-48a2-b7c6-17391afe8d0e)

## 安装

- 依赖于[flash.nvim](https://github.com/folke/flash.nvim)
- 使用 [lazy.nvim](https://github.com/folke/lazy.nvim) 进行安装:

```lua
return {{
    "rainzm/flash-zh.nvim",
    event = "VeryLazy",
    dependencies = "folke/flash.nvim",
    keys = {{
        "s",
        mode = {"n", "x", "o"},
        function()
            require("flash-zh").jump({
                chinese_only = false
            })
        end,
        desc = "Flash between Chinese"
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

## 使用

1. ~~label 默认使用大写字母，这样可以避免和拼音冲突。~~ label 现在默认使用小写字母，通过自定义`flash.nvim`的 labeler ，以避免小写 label 和拼音的冲突。
2. 默认工作在中英混杂模式下（由[dirichy](https://github.com/dirichy)实现）；增加选项 `chinese_only` 使其工作在仅中文模式下。
3. `jump`的参数会传递给`flash.nvim`，查看 [issue 2](https://github.com/rainzm/flash-zh.nvim/issues/2) 。

**如果想要跳转的地方没有 label 出现，接着输入即可，和查找一样。**

### 自定义匹配字符

- 你可以覆盖、或是追加字符到默认的匹配字符集。

    ```lua
    require('flash-zh').setup {
        char_map = {
            -- Override default mapping in `flypy.comma`
            comma = {
                [']'] = ']」', -- A string of chars to match for, with no separator. No need to escape.
                ['!'] = '!！', -- You can add a symbol that isn't present in the default table.
            },
            -- Append to `flypy.comma`
            append_comma = {
                ['.'] = '…',
            },
            -- Append to `flypy.char1patterns`
            append_char1 = {
                ['a'] = 'äÄ',
            },
            -- Append to `flypy.char2patterns`
            append_char2 = {},
        }
    }
    ```

## 感谢

- [hop-zh-by-flypy](https://github.com/zzhirong/hop-zh-by-flypy)

## 推荐

- [rime-ls](https://github.com/wlh320/rime-ls) 通过补全的方式输入中文
