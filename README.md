# flash-zh.nvim
基于[flash.nvim](https://github.com/folke/flash.nvim)以及小鹤双拼，neovim 中文跳转插件。


## 安装
- 依赖于[flash.nvim](https://github.com/folke/flash.nvim)
- 使用 [lazy.nvim](https://github.com/folke/lazy.nvim) 进行安装:
```lua
return {
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {
			highlight = {
				-- show a backdrop with hl FlashBackdrop
				backdrop = false,
				matches = false,
			},
			modes = {
				char = {
					enabled = false,
				},
			},
		},
	},
    {
        "rainzm/flash-zh.nvim",
        event = "VeryLazy",
        keys = {
            {"s", mode={"n", "x", "o"}, function() require("flash-zh").jump() end, desc = "Flash between Chinese"}
        }
    }
}
```
## Alternatives

- [hop-zh-by-flypy](https://github.com/zzhirong/hop-zh-by-flypy)
