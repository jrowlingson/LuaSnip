local fmt = require("luasnip.extras.fmt").fmt
local snippet = require("luasnip").snippet

local M = {}

local function default_override(arg, override)
	arg = arg or {}
	override = override or {}

	return vim.tbl_extend("keep", arg, override)
end

---Override keys in table-arguments of `fn`.
---@param fn any function.
---@vararg Any number of `override_descriptions`:
--- These are tables with keys:
---  - arg_indx: the position of the argument that should be extended
---  - apply_override: fn(direct_arg, override_arg) -> arg. This function is
---    responsible for overriding the arg passed to this specific call with the
---    one provided earlier.
---@return function: fn(...). The varargs are a list of values passed to
--- `apply_override`.
local function override_any(fn, ...)
	local override_descriptions = {...}

	return function(...)
		local override_arg_values = {...}

		return function(...)
			local direct_args = {...}

			-- override values of direct argument.
			for override_indx, od in ipairs(override_descriptions) do
				local arg_indx = od.arg_indx

				-- still allow overriding with directly-passed keys.
				direct_args[arg_indx] = od.apply_override(direct_args[arg_indx], override_arg_values[override_indx])
			end


			-- important: http://www.lua.org/manual/5.3/manual.html#3.4
			-- Passing arguments after the results from `unpack` would mess all this
			-- up.
			return fn(unpack(direct_args))
		end
	end
end


M.fmt = override_any(
	fmt,
	{arg_indx = 3, apply_override = default_override} )

local function context_override(arg, override)
	if type(arg) == "string" then
		arg = {trig = arg}
	end
	-- both are table or nil now.
	return default_override(arg, override)
end
M.snippet = override_any(
	snippet,
	{arg_indx = 1, apply_override = context_override},
	{arg_indx = 3, apply_override = default_override} )

return M
