local flash = require("flash")
local char_map = require("flash-zh.char_map")

local M = {}

function M.jump(opts)
	opts = opts or {}

	-- Allow per-jump override so users can verify schemes quickly,
	-- and so it still works even if setup() was not called (common with lazy.nvim misconfig).
	if opts.scheme then
		require("flash-zh.char_map").set(opts.scheme)
		opts.scheme = nil
	end

	local mode = M.mix_mode
	if opts.chinese_only then
		mode = M.zh_mode
	end
	opts = vim.tbl_deep_extend("force", {
		labels = "asdfghjklqwertyuiopzxcvbnm",
		search = {
			mode = mode,
		},
		labeler = function(_, state)
			require("flash-zh.labeler").new(state):update()
		end,
	}, opts)
	flash.jump(opts)
end

function M.mix_mode(str)
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

function M.zh_mode(str)
	local map = char_map.get()
	local regexs = {}
	while string.len(str) > 1 do
		local k = string.sub(str, 1, 2)
		-- Be defensive: unknown keys should not crash the search.
		regexs[#regexs + 1] = map.char2patterns[k] or ("[" .. k .. string.upper(k) .. "]")
		str = string.sub(str, 3)
	end
	if string.len(str) == 1 then
		regexs[#regexs + 1] = map.char1patterns[str] or ("[" .. str .. string.upper(str) .. "]")
	end
	local ret = table.concat(regexs)
	return ret, ret
end

local function get_nodes(map)
	return {
		alpha = function(str)
			return "[" .. str .. string.upper(str) .. "]"
		end,
		pinyin = function(str)
			return map.char2patterns[str]
		end,
		comma = function(str)
			return map.comma[str]
		end,
		singlepin = function(str)
			return map.char1patterns[str]
		end,
		other = function(str)
			str = map.escape[str] or str
			return str
		end,
	}
end

function M.regex(parser)
	local map = char_map.get()
	local nodes = get_nodes(map)
	local regexs = {}
	for _, v in ipairs(parser) do
		regexs[#regexs + 1] = nodes[v.type](v.str)
	end
	return table.concat(regexs)
end

function M.parser(str, prefix)
	local map = char_map.get()
	prefix = prefix or {}
	local firstchar = string.sub(str, 1, 1)
	local chars = {}
	for k, _ in pairs(map.comma) do
		table.insert(chars, k)
	end
	if firstchar == "" then
		return { prefix }
	elseif string.match(firstchar, "%l") then
		local secondchar = string.sub(str, 2, 2)
		if secondchar == "" then
			local prefix2 = M.copy(prefix)
			prefix[#prefix + 1] = { str = firstchar, type = "alpha" }
			prefix2[#prefix2 + 1] = { str = firstchar, type = "singlepin" }
			return { prefix, prefix2 }
		elseif string.match(secondchar, "%a") then
			if map.char2patterns[firstchar .. secondchar] then
				local prefix2 = M.copy(prefix)
				prefix2[#prefix2 + 1] = { str = firstchar, type = "alpha" }
				prefix[#prefix + 1] = { str = firstchar .. secondchar, type = "pinyin" }
				local str2 = string.sub(str, 2, -1)
				str = string.sub(str, 3, -1)
				return M.merge_table(M.parser(str, prefix), M.parser(str2, prefix2))
			else
				prefix[#prefix + 1] = { str = firstchar, type = "alpha" }
				str = string.sub(str, 2, -1)
				return (M.parser(str, prefix))
			end
		elseif vim.list_contains(chars, secondchar) then
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
	elseif vim.list_contains(chars, firstchar) then
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

-- @param opts table
-- @field[opt] opts.scheme string Choose the built-in shuangpin scheme. One of: "flypy", "pyjj".
-- @field opts.char_map table Char map for flypy.
-- @field[opt] opts.char_map.comma table Override the default comma map.
-- @field[opt] opts.char_map.append_comma table Append to the default comma map.
-- @field[opt] opts.char_map.append_char1 table Append to the default char1patterns map.
-- @field[opt] opts.char_map.append_char2 table Append to the default char2patterns map.
function M.setup(opts)
	opts = opts or {}

	if opts.scheme then
		char_map.set(opts.scheme)
	end

	if not opts.char_map then
		return
	end

	local map = char_map.get()
	local to_escape = "\\^$*+?.%|[]()"
	if opts.char_map.comma then
		for k, v in pairs(opts.char_map.comma) do
			if #k ~= 1 then
				error("comma key must be a single character")
			else
				v = vim.fn.escape(v, to_escape)
				map.comma[k] = "[" .. v .. "]"
			end
		end
	end
	if opts.char_map.append_comma then
		for k, v in pairs(opts.char_map.append_comma) do
			if #k ~= 1 then
				error("append_comma key must be a single character")
			else
				local chars = map.comma[k] or ""
				chars = string.sub(chars, 2, -2) .. vim.fn.escape(v, to_escape)
				map.comma[k] = "[" .. chars .. "]"
			end
		end
	end
	if opts.char_map.append_char1 then
		for k, v in pairs(opts.char_map.append_char1) do
			if #k ~= 1 then
				error("append_char1 key must be a single character")
			else
				local chars = map.char1patterns[k] or ""
				chars = string.sub(chars, 2, -2) .. vim.fn.escape(v, to_escape)
				map.char1patterns[k] = "[" .. chars .. "]"
			end
		end
	end
	if opts.char_map.append_char2 then
		for k, v in pairs(opts.char_map.append_char2) do
			if #k ~= 2 then
				error("append_char2 key must be two characters")
			else
				local chars = map.char2patterns[k] or ""
				chars = string.sub(chars, 2, -2) .. vim.fn.escape(v, to_escape)
				map.char2patterns[k] = "[" .. chars .. "]"
			end
		end
	end
end

return M
