# flash-zh.nvim

基于[flash.nvim](https://github.com/folke/flash.nvim)以及小鹤双拼，neovim 中文跳转插件。

![iShot_2023-10-05_02 37 31](https://github.com/rainzm/flash-zh.nvim/assets/22927169/fdd665ed-0b5e-40d8-97b2-0ec9db04891c)


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

label 使用大写字母，这样可以避免和拼音冲突。

**如果想要跳转的地方没有 label 出现，接着输入即可，和查找一样。**

## 感谢

- [hop-zh-by-flypy](https://github.com/zzhirong/hop-zh-by-flypy)
