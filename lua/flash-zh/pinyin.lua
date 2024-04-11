local flypy = require("flash-zh.flypy")

local M = {}

local py_table = {}

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
			py_table[char] = k
		end
	end
	for k, v in pairs(flypy.comma) do
		local start_char, end_char = v:find("%[(.-)%]")
		v = v:sub(start_char + 1, end_char - 1)
		for i = 1, utf8_len(v) do
			local char = utf8_sub(v, i, 1)
			py_table[char] = k
		end
	end
end

function M.pinyin(chars, separator)
	separator = separator or " "
	local pinyin = {}
	for i = 1, utf8_len(chars) do
		local char = utf8_sub(chars, i, 1)
		--要寻找的字符串
		if string.len(char) == 1 then
			pinyin[i] = char
		else
			pinyin[i] = py_table[char] or char
		end
	end
	return table.concat(pinyin, separator)
end

init_py_table()
return M
