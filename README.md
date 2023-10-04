# flash-zh.nvim

基于[flash.nvim](https://github.com/folke/flash.nvim)以及小鹤双拼，neovim 中文跳转插件。

## 安装

- 依赖于[flash.nvim](https://github.com/folke/flash.nvim)
- 使用 [lazy.nvim](https://github.com/folke/lazy.nvim) 进行安装:
```lua
return {
	{
		"rainzm/flash-zh.nvim",
		event = "VeryLazy",
		dependencies = "folke/flash.nvim",
		keys = {
			{
				"s",
				mode = { "n", "x", "o" },
				function()
					require("flash-zh").jump()
				end,
				desc = "Flash between Chinese",
			},
		},
	},
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {
			highlight = {
				backdrop = false,
				matches = false,
			},
		},
    }
}
```

## 使用

label 使用"1234567890"，这样可以完全避免和拼音冲突。

**如果想要跳转的地方没有 label 出现，接着输入即可，和查找一样。**

## Alternatives

- [hop-zh-by-flypy](https://github.com/zzhirong/hop-zh-by-flypy)
