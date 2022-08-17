local fmt = require("luasnip.extras.fmt").fmt
local snippet = require("luasnip").snippet

local M = {}

local function override_any(fn, ...)
	local override_arg_indices = {...}

	return function(...)
		local override_arg_values = {...}

		-- insert missing override-tables.
		-- Prevents `or {}` in vim.tbl_extend, a few lines down.
		for i, _ in ipairs(override_arg_indices) do
			if not override_arg_values[i] then
				override_arg_values[i] = {}
			end
		end

		return function(...)
			local direct_args = {...}

			-- override values of direct argument.
			for i, arg_indx in ipairs(override_arg_indices) do
				direct_args[arg_indx] = direct_args[arg_indx] or {}

				-- still allow overriding with directly-passed keys.
				-- Maybe we should even override in-place here.
				-- Don't do it for now.
				direct_args[arg_indx] = vim.tbl_extend("keep", direct_args[arg_indx], override_arg_values[i])
			end

			-- important: http://www.lua.org/manual/5.3/manual.html#3.4
			-- Passing arguments after the results from `unpack` would mess all this
			-- up.
			return fn(unpack(direct_args))
		end
	end
end


M.fmt = override_any(fmt, 3)

return M
