local M = {}
M.__index = M

function M.new(state)
	local self
	self = setmetatable({}, M)
	self.state = state
	self.used = {}
	self:reset()
	return self
end

function M:update()
	self:reset()

	if #self.state.pattern() < self.state.opts.label.min_pattern_length then
		return
	end

	local matches = self:filter()

	for _, match in ipairs(matches) do
		self:label(match, true)
	end

	for _, match in ipairs(matches) do
		if not self:label(match) then
			break
		end
	end
end

local pingyin = require("flash-zh.pinyin")
-- Returns valid labels for the current search pattern
-- in this window.
---@param labels string[]
---@return string[] returns labels to skip or `nil` when all labels should be skipped
function M:skip1(win, labels)
	local prefix = self.state.pattern.pattern
	for _, match in ipairs(self.state.results) do
		if match.win == win then
			local buf = vim.api.nvim_win_get_buf(match.win)
			local start_line, end_line = match.pos[1], match.end_pos[1]
			local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
			local start_col, end_col = match.pos[2] + 1, match.end_pos[2] + 2
			local line = lines[1]
			local substring = string.sub(line, start_col, end_col + 4)
			local py = pinyin(substring, "")
			local prefix_len = string.len(prefix)
			local char = string.sub(py, prefix_len + 1, prefix_len + 1)
			labels = vim.tbl_filter(function(c)
				-- when ignorecase is set, we need to skip
				-- both the upper and lower case labels
				if vim.go.ignorecase then
					return c:lower() ~= char:lower()
				end
				return c ~= char
			end, labels)
		end
	end
	return labels
end

function M:reset()
	local skip = {} ---@type table<string, boolean>
	self.labels = {}

	for _, l in ipairs(self.state:labels()) do
		if not skip[l] then
			self.labels[#self.labels + 1] = l
			skip[l] = true
		end
	end
	if not self.state.opts.search.max_length or #self.state.pattern() < self.state.opts.search.max_length then
		for _, win in pairs(self.state.wins) do
			self.labels = self:skip1(win, self.labels)
		end
	end
	for _, m in ipairs(self.state.results) do
		if m.label ~= false then
			m.label = nil
		end
	end
end

function M:valid(label)
	return vim.tbl_contains(self.labels, label)
end

function M:use(label)
	self.labels = vim.tbl_filter(function(c)
		return c ~= label
	end, self.labels)
end

---@param m Flash.Match
---@param used boolean?
function M:label(m, used)
	if m.label ~= nil then
		return true
	end
	local pos = m.pos:id(m.win)
	local label ---@type string?
	if used then
		label = self.used[pos]
	else
		label = self.labels[1]
	end
	if label and self:valid(label) then
		self:use(label)
		local reuse = self.state.opts.label.reuse == "all"
			or (self.state.opts.label.reuse == "lowercase" and label:lower() == label)

		if reuse then
			self.used[pos] = label
		end
		m.label = label
	end
	return #self.labels > 0
end

function M:filter()
	---@type Flash.Match[]
	local ret = {}

	local target = self.state.target

	local from = vim.api.nvim_win_get_cursor(self.state.win)
	---@type table<number, boolean>
	local folds = {}

	-- only label visible matches
	for _, match in ipairs(self.state.results) do
		-- and don't label the first match in the current window
		local skip = (target and match.pos == target.pos)
			and not self.state.opts.label.current
			and match.win == self.state.win

		-- Only label the first match in each fold
		if not skip and match.fold then
			if folds[match.fold] then
				skip = true
			else
				folds[match.fold] = true
			end
		end

		if not skip then
			table.insert(ret, match)
		end
	end

	-- sort by current win, other win, then by distance
	table.sort(ret, function(a, b)
		local use_distance = self.state.opts.label.distance and a.win == self.state.win

		if a.win ~= b.win then
			local aw = a.win == self.state.win and 0 or a.win
			local bw = b.win == self.state.win and 0 or b.win
			return aw < bw
		end
		if use_distance then
			local dfrom = from[1] * vim.go.columns + from[2]
			local da = a.pos[1] * vim.go.columns + a.pos[2]
			local db = b.pos[1] * vim.go.columns + b.pos[2]
			return math.abs(dfrom - da) < math.abs(dfrom - db)
		end
		if a.pos[1] ~= b.pos[1] then
			return a.pos[1] < b.pos[1]
		end
		return a.pos[2] < b.pos[2]
	end)
	return ret
end

return M
