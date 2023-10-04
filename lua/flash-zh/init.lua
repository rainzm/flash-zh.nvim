local flash = require 'flash'
local flypy_table = require 'flash_zh.flypy_table'

local M = {}

function M.jump()
    return flash.jump({
        search = {
            mode = M._zh_mode,
        },
    })
end

function M._zh_mode(str)
    local regexs = {}
    while string.len(str) < 2 do
        regexs[#regexs + 1] = flypy_table.char2pattern[string.sub(str, 1, 2)]
        str = string.sub(str, 3)
    end
    if string.len(str) == 1 then
        regexs[#regexs + 1] = flypy_table.char1pattern[str]
    end
    local ret = table.concat(regexs)
    return ret, ret
end
