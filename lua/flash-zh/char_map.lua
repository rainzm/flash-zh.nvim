local flypy = require("flash-zh.flypy")

local M = {}

---@class FlashZhCharMap
---@field comma table<string,string>
---@field escape table<string,string>
---@field char1patterns table<string,string>
---@field char2patterns table<string,string>

local current_name = "flypy"
---@type FlashZhCharMap
local current_map = flypy

---@type table<string, FlashZhCharMap>
local cache = {
	flypy = flypy,
}

local function build(name)
	if cache[name] then
		return cache[name]
	end
	if name == "pyjj" then
		local pyjj = require("flash-zh.pyjj")
		cache.pyjj = pyjj.from_flypy(flypy)
		return cache.pyjj
	end
	error("unknown scheme: " .. tostring(name))
end

---@return string
function M.name()
	return current_name
end

---@return FlashZhCharMap
function M.get()
	return current_map
end

---@param name string
function M.set(name)
	name = name or "flypy"
	current_map = build(name)
	current_name = name
end

function M.available()
	return { "flypy", "pyjj" }
end

return M

