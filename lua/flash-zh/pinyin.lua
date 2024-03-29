local cclib = {
	utf8 = {},
}

local utf8 = cclib.utf8

function cclib.GetCharSize(char) --获取单个字符长度
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

function cclib.utf8.len(str) --获取中文字符长度
	local len = 0
	local currentIndex = 1
	while currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + cclib.GetCharSize(char)
		len = len + 1
	end
	return len
end

function cclib.utf8.sub(str, startChar, numChars) --截取中文字符串
	local startIndex = 1
	while startChar > 1 do
		local char = string.byte(str, startIndex)
		startIndex = startIndex + cclib.GetCharSize(char)
		startChar = startChar - 1
	end

	local currentIndex = startIndex

	while numChars > 0 and currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + cclib.GetCharSize(char)
		numChars = numChars - 1
	end

	return string.sub(str, startIndex, currentIndex - 1)
end

local pyTable = {}
local flypy = require("flash-zh.flypy")
function getPyTable()
	for k, v in pairs(flypy.char2patterns) do
		local start_char, end_char = v:find("%[(.-)%]") -- 找到中括号中的内容
		v = v:sub(start_char + 1, end_char - 1)
		for i = 1, utf8.len(v) do
			local char = utf8.sub(v, i, 1)
			--要寻找的字符串
			pyTable[char] = k
		end
	end
end

getPyTable()

function pinyin(chars, separator)
	separator = separator or " "
	local pinyin = {}
	for i = 1, utf8.len(chars) do
		local char = utf8.sub(chars, i, 1)
		--要寻找的字符串
		if string.len(char) == 1 then
			pinyin[i] = char
		else
			pinyin[i] = pyTable[char]
		end
	end
	return table.concat(pinyin, separator)
end

return pinyin
