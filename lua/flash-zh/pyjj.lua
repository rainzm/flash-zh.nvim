-- Build 拼音加加( pyjj ) char map from the existing flypy dataset.
-- This keeps the dictionary/character coverage identical, only re-keys by scheme.

local M = {}

local function strip_brackets(pat)
	-- pat is expected to be like "[...]" (as in the bundled tables).
	return pat:sub(2, -2)
end

local function wrap_brackets(s)
	return "[" .. s .. "]"
end

local function append_pat(dst, src_pat)
	if not dst then
		return src_pat
	end
	-- Merge by concatenation (duplicates are fine for a character-class).
	return wrap_brackets(strip_brackets(dst) .. strip_brackets(src_pat))
end

-- Approximate flypy preedit_format decoding for a *single* 2-key code.
-- This is enough to turn flypy keys into canonical pinyin syllables.
local flypy_preedit_rules = {
	-- Copied from rime-double-pinyin `double_pinyin_flypy.schema.yaml` preedit_format.
	{ "^([bpmfdtnljqx])n$", "%1iao" },
	{ "^(%w)g$", "%1eng" },
	{ "^(%w)q$", "%1iu" },
	{ "^(%w)w$", "%1ei" },
	{ "^([dtnlgkhjqxyvuirzcs])r$", "%1uan" },
	{ "^(%w)t$", "%1ve" },
	{ "^(%w)y$", "%1un" },
	{ "^([dtnlgkhvuirzcs])o$", "%1uo" },
	{ "^(%w)p$", "%1ie" },
	{ "^([jqx])s$", "%1iong" },
	{ "^(%w)s$", "%1ong" },
	{ "^(%w)d$", "%1ai" },
	{ "^(%w)f$", "%1en" },
	{ "^(%w)h$", "%1ang" },
	{ "^(%w)j$", "%1an" },
	{ "^([gkhvuirzcs])k$", "%1uai" },
	{ "^(%w)k$", "%1ing" },
	{ "^([jqxnl])l$", "%1iang" },
	{ "^(%w)l$", "%1uang" },
	{ "^(%w)z$", "%1ou" },
	{ "^([gkhvuirzcs])x$", "%1ua" },
	{ "^(%w)x$", "%1ia" },
	{ "^(%w)c$", "%1ao" },
	{ "^([dtgkhvuirzcs])v$", "%1ui" },
	{ "^(%w)b$", "%1in" },
	{ "^(%w)m$", "%1ian" },
}

local function apply_first_gsub(s, rules)
	for _, r in ipairs(rules) do
		local out, n = s:gsub(r[1], r[2], 1)
		if n > 0 then
			return out
		end
	end
	return s
end

local function flypy_code_to_pinyin(code)
	-- Fast path: already looks like pinyin (e.g. "ai", "an").
	-- Keep as-is; the rewrite rules below will handle the rest.
	local s = apply_first_gsub(code, flypy_preedit_rules)

	-- Collapse duplicated leading vowels, e.g. "aai" -> "ai", "oou" -> "ou".
	s = s:gsub("^([aoe])%1(%w)", "%1%2")
	s = s:gsub("^([aoe])%1$", "%1")

	-- Initial mappings.
	s = s:gsub("^v", "zh")
	s = s:gsub("^i", "ch")
	s = s:gsub("^u", "sh")

	-- v after jqxy => u; v after nl => ü.
	s = s:gsub("^([jqxy])v", "%1u")
	-- Keep output ASCII: represent ü as "v".
	s = s:gsub("^([nl])v", "%1v")
	s = s:gsub("ü", "v")

	return s
end

local function pyjj_pinyin_to_codes(pinyin)
	-- Keep output ASCII (Rime uses "v" internally for ü).
	local base = pinyin:gsub("ü", "v"):gsub("u:", "v")
	local forms = { base }

	-- derive/^([jqxy])u$/$1v/
	do
		local sm = base:match("^([jqxy])u$")
		if sm then
			forms[#forms + 1] = sm .. "v"
		end
	end

	-- derive/^([aoe].*)$/o$1/
	if base:match("^[aoe]") then
		forms[#forms + 1] = "o" .. base
	end

	local out = {}
	local seen = {}

	for _, s in ipairs(forms) do
		-- xform/^([ae])(.*)$/$1$1$2/
		do
			local v, rest = s:match("^([ae])(.*)$")
			if v then
				s = v .. v .. rest
			end
		end

		-- Finals (order matters; copied from rime schema speller.algebra).
		s = s:gsub("iu$", "N")
		s = s:gsub("[iu]a$", "B")
		s = s:gsub("er$", "Q")
		s = s:gsub("ing$", "Q")
		s = s:gsub("[uv]an$", "C")
		s = s:gsub("[uv]e$", "X")
		s = s:gsub("uai$", "X")

		-- Initials.
		s = s:gsub("^sh", "I")
		s = s:gsub("^ch", "U")
		s = s:gsub("^zh", "V")

		s = s:gsub("uo$", "O")
		s = s:gsub("[uv]n$", "Z")
		s = s:gsub("iong$", "Y")
		s = s:gsub("ong$", "Y")
		s = s:gsub("[iu]ang$", "H")
		s = s:gsub("(.)en$", "%1R")
		s = s:gsub("(.)eng$", "%1T")
		s = s:gsub("(.)ang$", "%1G")
		s = s:gsub("ian$", "J")
		s = s:gsub("(.)an$", "%1F")
		s = s:gsub("iao$", "K")
		s = s:gsub("(.)ao$", "%1D")
		s = s:gsub("(.)ai$", "%1S")
		s = s:gsub("(.)ei$", "%1W")
		s = s:gsub("ie$", "M")
		s = s:gsub("ui$", "V")
		s = s:gsub("(.)ou$", "%1P")
		s = s:gsub("in$", "L")

		s = s:lower()

		-- Only keep 2-key codes (plugin expects 2 chars per syllable).
		if #s == 2 and not seen[s] then
			seen[s] = true
			out[#out + 1] = s
		end
	end

	return out
end

local function build_char1_from_char2(char2)
	local acc = {}
	for code, pat in pairs(char2) do
		if #code == 2 then
			local k = code:sub(1, 1)
			acc[k] = append_pat(acc[k], pat)
		end
	end
	return acc
end

---@param flypy table
---@return table
function M.from_flypy(flypy)
	local char2 = {}

	for code, pat in pairs(flypy.char2patterns) do
		local py = flypy_code_to_pinyin(code)
		local codes = pyjj_pinyin_to_codes(py)
		for _, k in ipairs(codes) do
			char2[k] = append_pat(char2[k], pat)
		end
	end

	return {
		comma = flypy.comma,
		escape = flypy.escape,
		char2patterns = char2,
		char1patterns = build_char1_from_char2(char2),
	}
end

return M
