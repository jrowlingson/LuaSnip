-- store snippets by some key.
-- also ordered by filetype, eg.
-- {
--	key = {
--		ft1 = {...},
--		ft2 = {...}
--	}
-- }
local by_key = {}

-- stores snippets/autosnippets by priority.
local by_prio = {
	snippets = {
		-- stores sorted keys, eg 1=1000, 2=1010, 3=1020,..., used for
		-- quick iterating.
		order = {
			1000,
		},
		[1000] = {
			all = {},
		},
	},
	autosnippets = {
		order = {
			1000,
		},
		[1000] = {
			all = {},
		},
	},
}

-- this isn't in util/util.lua due to circular dependencies. Would be cleaner
-- to include it there, but it's alright to keep here for now.
--
-- this is linear, binary search would certainly be nicer, but for our
-- applications this should easily be enough.
local function insert_sorted_unique(t, k)
	local tbl_len = #t

	local i = 1
	-- k does not yet exist in table, find first i so t[i] > k.
	for _ = 1, tbl_len do
		if t[i] > k then
			break
		end
		i = i + 1
	end

	-- shift all t[j] with j > i back by one.
	for j = tbl_len, i, -1 do
		t[j + 1] = t[j]
	end

	t[i] = k
end

local sort_mt = {
	__newindex = function(t, k, v)
		-- update priority-order as well.
		insert_sorted_unique(t.order, k)
		rawset(t, k, v)
	end,
}

setmetatable(by_prio.snippets, sort_mt)
setmetatable(by_prio.autosnippets, sort_mt)

local by_ft = {
	snippets = {},
	autosnippets = {},
}

M = {
	by_key = by_key,
	by_prio = by_prio,
	by_ft = by_ft,
}

-- ft: any filetype, optional.
function M.clear_snippets(ft)
	if ft then
		-- remove all ft-(auto)snippets for all priorities.
		-- set to empty table so we won't need to rebuild/clear the order-table.
		for _, prio in ipairs(M.by_prio.snippets.order) do
			M.by_prio.snippets[prio][ft] = {}
		end
		for _, prio in ipairs(M.by_prio.autosnippets.order) do
			M.by_prio.autosnippets[prio][ft] = {}
		end

		M.by_ft.snippets[ft] = nil
		M.by_ft.autosnippets[ft] = nil

		for key, _ in pairs(by_key) do
			by_key[key][ft] = nil
		end
	else
		-- remove all (auto)snippets for all priorities.
		for _, prio in ipairs(M.by_prio.snippets.order) do
			M.by_prio.snippets[prio] = {}
		end
		for _, prio in ipairs(M.by_prio.autosnippets.order) do
			M.by_prio.autosnippets[prio] = {}
		end

		M.by_ft.snippets = {}
		M.by_ft.autosnippets = {}

		by_key = {}
		M.by_key = by_key
	end
end

function M.add_snippets() end

function M.match_snippet(line, fts, type)
	local expand_params

	for _, prio in ipairs(by_prio[type].order) do
		local snippets = by_prio[type][prio]
		for _, ft in ipairs(fts) do
			for _, snip in ipairs(snippets[ft] or {}) do
				expand_params = snip:matches(line)
				if expand_params then
					-- return matching snippet and table with expand-parameters.
					return snip, expand_params
				end
			end
		end
	end

	return nil
end

local function without_invalidated(snippets_by_ft)
	local new_snippets = {}

	for ft, ft_snippets in pairs(snippets_by_ft) do
		new_snippets[ft] = {}
		for _, snippet in ipairs(ft_snippets) do
			if not snippet.invalidated then
				table.insert(new_snippets[ft], snippet)
			end
		end
	end

	return new_snippets
end

M.invalidated_count = 0
local function clean_invalidated(opts)
	opts = opts or {}

	if opts.inv_limit then
		if M.invalidated_count <= opts.inv_limit then
			return
		end
	end

	-- remove invalidated snippets from all tables.
	for _, type_snippets in pairs(by_prio) do
		for _, prio_snippets in pairs(type_snippets) do
			prio_snippets = without_invalidated(prio_snippets)
		end
	end

	for type, type_snippets in pairs(by_ft) do
		by_ft[type] = without_invalidated(type_snippets)
	end

	for key, key_snippets in pairs(by_key) do
		by_key[key] = without_invalidated(key_snippets)
	end

	M.invalidated_count = 0
end

local function invalidate_snippets(snippets_by_ft)
	for _, ft_snippets in pairs(snippets_by_ft) do
		for _, snip in ipairs(ft_snippets) do
			snip:invalidate()
		end
	end
	clean_invalidated({ inv_limit = 100 })
end

function M.add_snippets(snippets, opts)
	local prio_snip_table = by_prio[opts.type]
	for ft, ft_snippets in pairs(snippets) do
		local ft_table = by_ft[opts.type][ft]

		if not ft_table then
			ft_table = {}
			by_ft[opts.type][ft] = ft_table
		end

		-- TODO: not the nicest loop, can it be improved? Do table-checks outside
		-- it, preferably.
		for _, snip in ipairs(ft_snippets) do
			snip.priority = opts.override_prio
				or (snip.priority ~= -1 and snip.priority)
				or opts.default_prio
				or 1000

			if not prio_snip_table[snip.priority] then
				prio_snip_table[snip.priority] = {}
			end

			local prio_ft_table
			if not prio_snip_table[snip.priority][ft] then
				prio_ft_table = {}
				prio_snip_table[snip.priority][ft] = prio_ft_table
			else
				prio_ft_table = prio_snip_table[snip.priority][ft]
			end

			prio_ft_table[#prio_ft_table + 1] = snip

			ft_table[#ft_table + 1] = snip
		end
	end

	if opts.key then
		if by_key[opts.key] then
			invalidate_snippets(by_key[opts.key])
		end
		by_key[opts.key] = snippets
	end
end

return M