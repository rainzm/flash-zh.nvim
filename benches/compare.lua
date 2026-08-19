-- Benchmark: vim-regex matcher path vs native Rust matcher path.
--
-- Measures the honest per-keystroke cost of both implementations on
-- generated mixed-CJK windows:
--   * vim path  : make_mix_mode(langs)(pattern)  -> regex build +
--                 vim.regex compile + match_str scan over every line
--   * rust path : require("flash-cjk.rust").search(pattern, lines, langs)
--                 (spawns the real flash-cjk-search binary per call,
--                 exactly like a live keystroke does)
--
-- Usage (from the repo root):
--   cargo build --release --manifest-path rust/Cargo.toml
--   nvim -l benches/compare.lua
--
-- Writes benches/results.json. Deterministic: fixed seed, own RNG.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local rust = require("flash-cjk.rust")
local fc = require("flash-cjk")
local flypy = require("flash-cjk.flypy")
local jp_data = require("flash-cjk.jp_data")
local ko = require("flash-cjk.ko")

if not rust.available() then
	io.stderr:write(
		"ERROR: flash-cjk-search release binary not found.\n"
			.. "Build it first: cargo build --release --manifest-path rust/Cargo.toml\n"
	)
	os.exit(1)
end

-- ---------------------------------------------------------------------------
-- deterministic RNG (xorshift32; math.random portability is not trusted
-- across builds, and the corpus must be reproducible from the seed)
local rng_state = 42
local function rng()
	rng_state = bit.bxor(rng_state, bit.lshift(rng_state, 13))
	rng_state = bit.bxor(rng_state, bit.rshift(rng_state, 17))
	rng_state = bit.bxor(rng_state, bit.lshift(rng_state, 5))
	rng_state = rng_state % 2147483648
	return rng_state / 2147483648
end
local function ri(a, b) -- inclusive integer
	return a + math.floor(rng() * (b - a + 1))
end
local function pick(t)
	return t[ri(1, #t)]
end

-- ---------------------------------------------------------------------------
-- character pools sampled from the plugin's own data tables

-- Splits a vim char-class string like "[哀矮...]" into single characters,
-- skipping escape backslashes.
local function class_chars(s)
	local chars = {}
	local i = s:find("[", 1, true)
	local j = s:find("]", 1, true)
	if i and j then
		s = s:sub(i + 1, j - 1)
	end
	i = 1
	while i <= #s do
		local b = s:byte(i)
		local size = (b >= 0xF0 and b <= 0xF4) and 4
			or (b >= 0xE0 and b <= 0xEF) and 3
			or (b >= 0xC0 and b <= 0xDF) and 2
			or 1
		local ch = s:sub(i, i + size - 1)
		if ch ~= "\\" and ch ~= "-" and ch ~= "^" then
			chars[#chars + 1] = ch
		end
		i = i + size
	end
	return chars
end

-- zh: han chars straight out of the flypy tables; the table key they
-- came from IS a plausible keystroke spelling for that char.
local zh_pool = {}
for key, class in pairs(flypy.char2patterns) do
	for _, ch in ipairs(class_chars(class)) do
		zh_pool[#zh_pool + 1] = { char = ch, spell = key }
	end
end
for key, class in pairs(flypy.char1patterns) do
	for _, ch in ipairs(class_chars(class)) do
		zh_pool[#zh_pool + 1] = { char = ch, spell = key }
	end
end

-- ja: kana + kanji with their Unihan readings (jp_data is the same table
-- the matcher consults, so these keystrokes are plausible by construction)
local jp_pool = {}
for ch, readings in pairs(jp_data.readings) do
	jp_pool[#jp_pool + 1] = { char = ch, spell = readings[1], readings = readings }
end

-- ko: random Hangul syllables composed through the plugin's own
-- L*588 + V*28 + T encoding, spelled via ko.strs (romanization or
-- two-set keys — both are matched simultaneously in real usage)
local ko_pool = {}
for _ = 1, 600 do
	local l, v, t = ri(0, 18), ri(0, 20), ri(0, 27)
	local ch = vim.fn.nr2char(0xAC00 + l * 588 + v * 28 + t)
	local strs = ko.strs(ch, 8)
	ko_pool[#ko_pool + 1] = { char = ch, spell = strs[1] or "a" }
end

-- en: plain ASCII words (code identifiers + prose) for the mixed category
local en_pool = {
	"function", "value", "return", "local", "require", "config", "window",
	"buffer", "label", "match", "pattern", "state", "editor", "cursor",
	"jump", "search", "result", "plugin", "flash", "table", "index",
	"loop", "line", "note", "quick", "brown", "fox", "jumps", "over",
	"lazy", "dog", "while", "value", "name", "user", "text", "input",
}

local POOLS = { zh = zh_pool, jp = jp_pool, ko = ko_pool }

-- ---------------------------------------------------------------------------

local CATEGORIES = {
	{ id = "zh_ja", labels = { "zh", "jp" }, cases = 350 },
	{ id = "ja_ko", labels = { "jp", "ko" }, cases = 350 },
	{ id = "zh_ja_ko_en", labels = { "zh", "jp", "ko", "en" }, cases = 350 },
}
local CASES_TOTAL = 1050
local WARMUP_PASSES = 1
local MEASURED_PASSES = 3
local langs = { cn = true, jp = true, ko = true, en = true, alpha_mixing = true }

-- One CJK token: 1-3 chars from one language (words run together in
-- real CJK text, spaces only appear between words/segments).
local function token(lang)
	local pool = POOLS[lang]
	local n = ri(1, 3)
	local out = {}
	for i = 1, n do
		out[i] = pick(pool).char
	end
	return table.concat(out)
end

local function gen_case(cat)
	local n_lines = ri(20, 60)
	local lines = {}
	-- candidate (lang, spell) pairs harvested while generating, so most
	-- patterns target text that is actually present in the window
	local targets = {}
	for _ = 1, n_lines do
		local n_tokens = ri(4, 14)
		local parts = {}
		for t = 1, n_tokens do
			local lang = pick(cat.labels)
			local part
			if lang == "en" then
				local w = pick(en_pool)
				part = w
				targets[#targets + 1] = { lang = "en", spell = w }
			else
				local pool = POOLS[lang]
				local entry = pick(pool)
				part = entry.char
				if rng() < 0.35 then -- two-char word from the same language
					part = part .. pick(pool).char
				end
				targets[#targets + 1] = { lang = lang, spell = entry.spell }
			end
			parts[t] = part
		end
		lines[#lines + 1] = table.concat(parts, " ")
	end

	-- pattern: 1-6 plausible keystrokes
	local pattern
	if rng() < 0.8 and #targets > 0 then
		-- prefix of a real spelling (what a user types heading toward a
		-- match); sometimes two segments concatenated (typing a word)
		local t1 = pick(targets)
		local spell = t1.spell
		if rng() < 0.3 then
			local t2 = pick(targets)
			if t2.lang == t1.lang then
				spell = spell .. t2.spell
			end
		end
		pattern = spell:sub(1, ri(1, math.min(6, #spell)))
	else
		-- miss / literal path: random ascii letters
		local alphabet = "aeionksthrdglcbmpu"
		local n = ri(1, 6)
		local buf = {}
		for i = 1, n do
			buf[i] = alphabet:sub(ri(1, #alphabet), ri(1, #alphabet))
		end
		pattern = table.concat(buf)
	end
	return { lines = lines, pattern = pattern }
end

-- ---------------------------------------------------------------------------

local function vim_path(mode, pattern, lines)
	local t0 = vim.uv.hrtime()
	local regex = mode(pattern)
	-- very long multi-interpretation patterns can exceed vim's NFA
	-- capture-group limit (E872): the regex never compiles, so there is
	-- no vim-regex timing for the case (counted as a vim failure)
	local ok, re = pcall(vim.regex, regex)
	if not ok then
		return nil
	end
	for _, line in ipairs(lines) do
		local col = 0
		while true do
			local s, e = re:match_str(line:sub(col + 1))
			if not s then
				break
			end
			col = col + e
			if e <= s then
				break
			end
		end
	end
	return (vim.uv.hrtime() - t0) / 1e6
end

local function rust_path(pattern, lines)
	local t0 = vim.uv.hrtime()
	local resp = rust.search(pattern, lines, langs)
	local dt = (vim.uv.hrtime() - t0) / 1e6
	assert(resp and type(resp.matches) == "table", "rust search failed")
	return dt
end

local function median3(t)
	local a, b, c = t[1], t[2], t[3]
	if a > b then
		a, b = b, a
	end
	if b > c then
		b, c = c, b
	end
	if a > b then
		a, b = b, a
	end
	return b
end

local function stats(values)
	local sorted = {}
	for i, v in ipairs(values) do
		sorted[i] = v
	end
	table.sort(sorted)
	local function pct(p)
		local idx = math.min(#sorted, math.max(1, math.ceil(p * #sorted)))
		return sorted[idx]
	end
	local sum = 0
	for _, v in ipairs(sorted) do
		sum = sum + v
	end
	return { mean = sum / #sorted, p50 = pct(0.50), p95 = pct(0.95) }
end

local function round(x)
	return math.floor(x * 1000 + 0.5) / 1000
end

-- ---------------------------------------------------------------------------

-- machine metadata (best effort)
local uname = vim.uv.os_uname() or {}
local cpu = ""
do
	local ok, p = pcall(io.popen, "sysctl -n machdep.cpu.brand_string 2>/dev/null")
	if ok and p then
		cpu = (p:read("*l") or ""):gsub("^%s+", "")
		p:close()
	end
end
local nvim_ver = "unknown"
do
	local ok, v = pcall(function()
		return vim.version()
	end)
	if ok and type(v) == "table" then
		nvim_ver = ("%d.%d.%d"):format(v.major, v.minor, v.patch)
	end
end
-- floor costs, measured once up front: they explain the shape of the
-- rust curve (spawn is cheap; the binary's own startup dominates)
local spawn_ms, startup_ms = 0, 0
do
	local bin = vim.fn.exepath("rust/target/release/flash-cjk-search")
	local function med(fn, n)
		local ts = {}
		for _ = 1, n do
			local t0 = vim.uv.hrtime()
			fn()
			ts[#ts + 1] = (vim.uv.hrtime() - t0) / 1e6
		end
		table.sort(ts)
		return ts[math.ceil(#ts / 2)]
	end
	spawn_ms = med(function()
		vim.system({ "/usr/bin/true" }):wait()
	end, 5)
	local tiny = vim.json.encode({
		pattern = "a",
		lines = { "a" },
		langs = { cn = true, jp = true, ko = true, en = true, alpha_mixing = true },
	})
	startup_ms = med(function()
		vim.system({ bin }, { stdin = tiny }):wait()
	end, 5)
end

print(("generating %d cases across %d categories..."):format(CASES_TOTAL, #CATEGORIES))
local results = {
	meta = {
		date = os.date("%Y-%m-%d"),
		os = ("%s %s (%s)"):format(uname.sysname or "?", uname.release or "?", uname.machine or "?"),
		cpu = cpu ~= "" and cpu or (uname.machine or "?"),
		neovim = nvim_ver,
		seed = 42,
		cases = CASES_TOTAL,
		lines_per_case = "20-60",
		warmup_passes = WARMUP_PASSES,
		measured_passes = MEASURED_PASSES,
		statistic = "median of 3 passes, per case",
		process_spawn_ms = round(spawn_ms),
		binary_startup_ms = round(startup_ms),
		note = "rust path includes the per-keystroke process spawn (vim.system + JSON), same as live usage",
	},
	categories = {},
}

local all_vim, all_rust, all_speedup = {}, {}, {}
local done = 0
local t_start = os.time()

for _, cat in ipairs(CATEGORIES) do
	local cat_vim, cat_rust, cat_speedup = {}, {}, {}
	local vim_failed = 0
	for _ = 1, cat.cases do
		local case = gen_case(cat)
		local mode = fc.make_mix_mode(langs)

		collectgarbage("collect")

		-- warmup
		vim_path(mode, case.pattern, case.lines)
		rust_path(case.pattern, case.lines)

		-- measured passes, alternating implementations to spread any
		-- thermal / scheduler drift evenly between them; a vim regex
		-- that cannot compile (E872) has no timing and is counted
		local vtimes, rtimes = {}, {}
		for _ = 1, MEASURED_PASSES do
			local vt = vim_path(mode, case.pattern, case.lines)
			if vt then
				vtimes[#vtimes + 1] = vt
			end
			rtimes[#rtimes + 1] = rust_path(case.pattern, case.lines)
		end
		local rm = median3(rtimes)
		cat_rust[#cat_rust + 1] = rm
		if #vtimes == MEASURED_PASSES then
			local vm = median3(vtimes)
			cat_vim[#cat_vim + 1] = vm
			cat_speedup[#cat_speedup + 1] = vm / rm
		else
			vim_failed = vim_failed + 1
		end

		done = done + 1
		if done % 100 == 0 then
			print(("  %d/%d cases (%s)"):format(done, CASES_TOTAL, cat.id))
		end
	end
	local vs, rs = stats(cat_vim), stats(cat_rust)
	local sp = 0
	for _, s in ipairs(cat_speedup) do
		sp = sp + s
	end
	sp = sp / #cat_speedup
	results.categories[cat.id] = {
		cases = cat.cases,
		languages = cat.labels,
		vim_ms = { mean = round(vs.mean), p50 = round(vs.p50), p95 = round(vs.p95) },
		rust_ms = { mean = round(rs.mean), p50 = round(rs.p50), p95 = round(rs.p95) },
		speedup_mean = round(sp),
		mean_ratio = round(vs.mean / rs.mean),
		p95_ratio = round(vs.p95 / rs.p95),
		vim_regex_failures = vim_failed,
	}
	for _, v in ipairs(cat_vim) do
		all_vim[#all_vim + 1] = v
	end
	for _, v in ipairs(cat_rust) do
		all_rust[#all_rust + 1] = v
	end
	for _, v in ipairs(cat_speedup) do
		all_speedup[#all_speedup + 1] = v
	end
end

local vs, rs = stats(all_vim), stats(all_rust)
local sp = 0
for _, s in ipairs(all_speedup) do
	sp = sp + s
end
sp = sp / #all_speedup
local total_vim_failed = 0
for _, cat in ipairs(CATEGORIES) do
	total_vim_failed = total_vim_failed + results.categories[cat.id].vim_regex_failures
end
results.overall = {
	cases = CASES_TOTAL,
	vim_ms = { mean = round(vs.mean), p50 = round(vs.p50), p95 = round(vs.p95) },
	rust_ms = { mean = round(rs.mean), p50 = round(rs.p50), p95 = round(rs.p95) },
	speedup_mean = round(sp),
	mean_ratio = round(vs.mean / rs.mean),
	p95_ratio = round(vs.p95 / rs.p95),
	vim_regex_failures = total_vim_failed,
	vim_regex_failures_note = "cases whose alternation exceeded vim's NFA capture-group limit (E872); the Rust path matched them all",
}

local out = io.open("benches/results.json", "w")
local ok, encoded = pcall(vim.json.encode, results, { indent = "  " })
if not ok then
	encoded = vim.json.encode(results)
end
out:write(encoded, "\n")
out:close()

print(("\nwrote benches/results.json (%d s elapsed)"):format(os.time() - t_start))
print(string.format("%-14s %10s %10s %8s", "category", "vim mean", "rust mean", "speedup"))
for _, cat in ipairs(CATEGORIES) do
	local r = results.categories[cat.id]
	print(
		string.format(
			"%-14s %9.2fms %9.2fms %7.1fx",
			cat.id,
			r.vim_ms.mean,
			r.rust_ms.mean,
			r.speedup_mean
		)
	)
end
print(
	string.format(
		"%-14s %9.2fms %9.2fms %7.1fx",
		"overall",
		results.overall.vim_ms.mean,
		results.overall.rust_ms.mean,
		results.overall.speedup_mean
	)
)
