local config = require("kiwi.config")
local utils = require("kiwi.utils")

local M = {}

-- The single, generic utility to open any file path with an optional command.
-- @param full_path (string): The absolute path to the file to open.
-- @param open_cmd (string|nil): The vim command to use ('vsplit', 'tabnew', etc.).
M._open_file = function(full_path, open_cmd)
	-- Check if the buffer is already loaded and visible in a window.
	local abs_path = vim.fn.fnamemodify(full_path, ":p")
	local buffer_number = vim.fn.bufnr(abs_path)

	if buffer_number ~= -1 then
		local win_nr = vim.fn.bufwinnr(buffer_number)
		if win_nr ~= -1 then
			local win_id = vim.fn.win_getid(win_nr)
			vim.api.nvim_set_current_win(win_id)
			return
		end
	end

	if open_cmd and type(open_cmd) == "string" and #open_cmd > 0 then
		vim.cmd(open_cmd .. " " .. vim.fn.fnameescape(full_path))
	else
		local bn_to_open = vim.fn.bufnr(full_path, true)
		vim.api.nvim_win_set_buf(0, bn_to_open)
	end

	local current_buffer_number = vim.api.nvim_get_current_buf()
end


-- Private handler that finds a link under the cursor and delegates opening to _open_file.
M._open_link_handler = function(open_cmd)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.fn.getline(cursor[1])
	local filename = utils.is_link(cursor, line)

	if filename and filename:len() > 1 then
		if filename:sub(1, 2) == "./" then
			filename = filename:sub(2, -1)
		end
		local full_path = vim.fs.joinpath(config.path, filename)

		-- Delegate to the new utility function
		M._open_file(full_path, open_cmd)
	else
		vim.notify("Kiwi: No link under cursor.", vim.log.levels.WARN)
	end
end

M.open_wiki_index = function(name)
	local function open_index_from_path(wiki_path)
		if not wiki_path then
			return
		end
		config.path = wiki_path
		local wiki_index_path = vim.fs.joinpath(config.path, "index.md")
		M._open_file(wiki_index_path)
	end

	if config.folders then
		if name then
			-- User specified a wiki name directly, find it and proceed.
			local found_path = nil
			for _, props in ipairs(config.folders) do
				if props.name == name then
					found_path = props.path
					break
				end
			end
			open_index_from_path(found_path) -- Open it (or do nothing if not found).
		else
			utils.prompt_folder(config, open_index_from_path)
		end
	else
		open_index_from_path(config.path)
	end
end

-- Create a new Wiki entry in Journal folder on highlighting word and pressing <CR>
M.create_or_open_wiki_file = function(open_cmd)
	local selection_start = vim.fn.getpos("'<")
	local selection_end = vim.fn.getpos("'>")
	local line = vim.fn.getline(selection_start[2], selection_end[2])
	local name = line[1]:sub(selection_start[3], selection_end[3])
	local filename = name:gsub(" ", "_"):gsub("\\", "") .. ".md"
	local new_mkdn = "[" .. name .. "](" .. "./" .. filename .. ")"
	local newline = line[1]:sub(0, selection_start[3] - 1)
		.. new_mkdn
		.. line[1]:sub(selection_end[3] + 1, string.len(line[1]))
	vim.api.nvim_set_current_line(newline)

	local full_path = vim.fs.joinpath(config.path, filename)

	-- Delegate to the new utility function instead of handling opening logic here
	M._open_file(full_path, open_cmd)
end

M.open_link = function(open_cmd)
	M._open_link_handler(open_cmd)
end

return M
