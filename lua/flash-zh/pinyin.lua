local flypy = require("flash-zh.flypy")

local M = {}

local py_table = {}
local mt = {}
setmetatable(py_table, { __index = mt })

function py_table:insert(char, pinyin)
	if not self[char] then
		self[char] = {}
	end
	table.insert(self[char], pinyin)
end

function py_table:find(char)
	return self[char]
end

local function get_char_size(char) --获取单个字符长度
	if not char then
		return 0
	elseif char > 240 then
		return 4
	elseif char > 225 then
		return 3
	elseif char > 192 then
		return 2
	else
		return 1
	end
end

local function utf8_len(str) --获取中文字符长度
	local len = 0
	local currentIndex = 1
	while currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + get_char_size(char)
		len = len + 1
	end
	return len
end

local function utf8_sub(str, startChar, numChars) --截取中文字符串
	local startIndex = 1
	while startChar > 1 do
		local char = string.byte(str, startIndex)
		startIndex = startIndex + get_char_size(char)
		startChar = startChar - 1
	end

	local currentIndex = startIndex

	while numChars > 0 and currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + get_char_size(char)
		numChars = numChars - 1
	end

	return string.sub(str, startIndex, currentIndex - 1)
end

local function init_py_table()
	for k, v in pairs(flypy.char2patterns) do
		local start_char, end_char = v:find("%[(.-)%]")
		v = v:sub(start_char + 1, end_char - 1)
		for i = 1, utf8_len(v) do
			local char = utf8_sub(v, i, 1)
			py_table:insert(char, k)
		end
	end
	for k, v in pairs(flypy.comma) do
		local start_char, end_char = v:find("%[(.-)%]")
		v = v:sub(start_char + 1, end_char - 1)
		for i = 1, utf8_len(v) do
			local char = utf8_sub(v, i, 1)
			py_table:insert(char, k)
		end
	end
end

local function append_to_pinyins(pinyins, suffixes)
	local result = {}
	if #pinyins == 0 then
		pinyins = { "" }
	end
	for i = 1, #pinyins do
		for j = 1, #suffixes do
			table.insert(result, pinyins[i] .. suffixes[j])
		end
	end
	return result
end

function M.pinyin(chars)
	local pinyins = {}
	for i = 1, utf8_len(chars) do
		local char = utf8_sub(chars, i, 1)
		--要寻找的字符串
		if string.len(char) == 1 then
			pinyins = append_to_pinyins(pinyins, { char })
		else
			local char_pinyins = py_table:find(char)
			if not char_pinyins then
				pinyins = append_to_pinyins(pinyins, { char })
			else
				pinyins = append_to_pinyins(pinyins, char_pinyins)
			end
		end
	end
	local result = {}
	for i = 1, #pinyins do
		table.insert(result, pinyins[i])
	end
	return result
end

init_py_table()
return M
