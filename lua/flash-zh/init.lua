local flash = require("flash")
local flypy = require("flash-zh.flypy")

local M = {}

function M.jump(opts)
	opts = vim.tbl_deep_extend("force", {
		labels = "asdfghjklqwertyuiopzxcvbnm",
		search = {
			mode = M._zh_mode,
		},
		labeler = function(_, state)
			require("flash-zh.labeler").new(state):update()
		end,
	}, opts or {})
	flash.jump(opts)
end

function M._zh_mode(str)
	local all_possible_splits = M.parser(str)
	local regexs = { [[\(]] }
	for _, v in ipairs(all_possible_splits) do
		regexs[#regexs + 1] = M.regex(v)
		regexs[#regexs + 1] = [[\|]]
	end
	regexs[#regexs] = [[\)]]
	local ret = table.concat(regexs)
	return ret, ret
end
local nodes = {
	alpha = function(str)
		return "[" .. str .. string.upper(str) .. "]"
	end,
	pinyin = function(str)
		return flypy.char2patterns[str]
	end,
	comma = function(str)
		return flypy.char1patterns[str]
	end,
	singlepin = function(str)
		return flypy.char1patterns[str]
	end,
	other = function(str)
		return str
	end,
}
function M.regex(parser)
	local regexs = {}
	for _, v in ipairs(parser) do
		regexs[#regexs + 1] = nodes[v.type](v.str)
	end
	return table.concat(regexs)
end
function M.parser(str, prefix)
	prefix = prefix or {}
	local firstchar = string.sub(str, 1, 1)
	if firstchar == "" then
		return { prefix }
	elseif string.match(firstchar, "%a") then
		local secondchar = string.sub(str, 2, 2)
		if secondchar == "" then
			prefix[#prefix + 1] = { str = firstchar, type = "singlepin" }
			return { prefix }
		elseif string.match(secondchar, "%a") then
			if flypy.char2patterns[firstchar .. secondchar] then
				local prefix2 = M.copy(prefix)
				prefix2[#prefix2 + 1] = { str = firstchar, type = "alpha" }
				prefix[#prefix + 1] = { str = firstchar .. secondchar, type = "pinyin" }
				local str2 = string.sub(str, 2, -1)
				str = string.sub(str, 3, -1)
				return M.merge_table(M.parser(str, prefix), M.parser(str2, prefix2))
			else
				prefix[#prefix + 1] = { str = firstchar, type = "singlepin" }
				str = string.sub(str, 2, -1)
				return (M.parser(str, prefix))
			end
		elseif string.match(secondchar, "[%.,?'\"%[%];:]") then
			prefix[#prefix + 1] = { str = firstchar, type = "alpha" }
			prefix[#prefix + 1] = { str = secondchar, type = "comma" }
			str = string.sub(str, 3, -1)
			return M.parser(str, prefix)
		else
			prefix[#prefix + 1] = { str = firstchar, type = "alpha" }
			prefix[#prefix + 1] = { str = secondchar, type = "other" }
			str = string.sub(str, 3, -1)
			return M.parser(str, prefix)
		end
	elseif string.match(firstchar, "[%.,?'\"%[%];:]") then
		prefix[#prefix + 1] = { str = firstchar, type = "comma" }
		str = string.sub(str, 2, -1)
		return M.parser(str, prefix)
	else
		prefix[#prefix + 1] = { str = firstchar, type = "other" }
		str = string.sub(str, 2, -1)
		return M.parser(str, prefix)
	end
end
function M.merge_table(tab1, tab2)
	for i = 1, #tab2 do
		table.insert(tab1, tab2[i])
	end
	return tab1
end
function M.copy(table)
	local copy = {}
	for k, v in pairs(table) do
		copy[k] = v
	end
	return copy
end

return M
