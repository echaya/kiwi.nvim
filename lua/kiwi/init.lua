local config = require("kiwi.config")
local utils = require("kiwi.utils")
local todo = require("kiwi.todo")
local wiki = require("kiwi.wiki")

local M = {}


M.todo = todo
M.utils = utils
M.VERSION = "0.4.0"

local create_buffer_keymaps = function(buffer_number)
	local opts = { noremap = true, silent = true, nowait = true }

	-- Visual mode keymaps for create or following links
	vim.api.nvim_buf_set_keymap(
		buffer_number,
		"v",
		"<CR>",
		":'<,'>lua require('kiwi').create_or_open_wiki_file()<CR>",
		opts
	)
	vim.api.nvim_buf_set_keymap(
		buffer_number,
		"v",
		"<S-CR>",
		":'<,'>lua require('kiwi').create_or_open_wiki_file('vsplit')<CR>",
		opts
	)
	vim.api.nvim_buf_set_keymap(
		buffer_number,
		"v",
		"<C-CR>",
		":'<,'>lua require('kiwi').create_or_open_wiki_file('split')<CR>",
		opts
	)

	-- Normal mode keymaps for following links
	vim.api.nvim_buf_set_keymap(buffer_number, "n", "<CR>", ':lua require("kiwi").open_link()<CR>', opts)
	vim.api.nvim_buf_set_keymap(buffer_number, "n", "<S-CR>", ':lua require("kiwi").open_link("vsplit")<CR>', opts)
	vim.api.nvim_buf_set_keymap(buffer_number, "n", "<C-CR>", ':lua require("kiwi").open_link("split")<CR>', opts)
	vim.api.nvim_buf_set_keymap(buffer_number, "n", "<Tab>", ':let @/="\\\\[.\\\\{-}\\\\]"<CR>nl', opts)
end

-- Normalizes a file path for reliable comparison on any OS.
-- @param path (string) The file path to normalize.
-- @return (string) The normalized path.
local function normalize_path_for_comparison(path)
	if not path then
		return ""
	end
	return path:lower():gsub("\\", "/"):gsub("//", "/")
end

-- Checks if the current buffer is a markdown file within a configured wiki
-- directory and, if so, applies the buffer-local keymaps.
local function setup_keymaps_for_wiki_file()
	if vim.bo.filetype ~= "markdown" then
		return
	end

	local buf_path = vim.api.nvim_buf_get_name(0)
	if not buf_path or buf_path == "" then
		return
	end
	local current_file_path = vim.fn.fnamemodify(buf_path, ":p")
	local normalized_current_path = normalize_path_for_comparison(current_file_path)

	local is_in_wiki_dir = false
	for _, normalized_wiki_dir in ipairs(processed_wiki_paths) do
		-- Ensure the wiki directory path ends with a slash for a clean "starts with" check.
		local dir_to_check = normalized_wiki_dir
		if not dir_to_check:find("/$") then
			dir_to_check = dir_to_check .. "/"
		end

		if normalized_current_path:find(dir_to_check, 1, true) == 1 then
			is_in_wiki_dir = true
			break
		end
	end

	if is_in_wiki_dir then
		create_buffer_keymaps(0)
	end
end

local processed_wiki_paths = {}
M.setup = function(opts)
	utils.setup(opts, config)

	processed_wiki_paths = {}
	if config.path and config.path ~= "" then
		local p = vim.fn.fnamemodify(config.path, ":p")
		table.insert(processed_wiki_paths, normalize_path_for_comparison(p))
	end
	if config.folders then
		for _, folder in ipairs(config.folders) do
			if folder.path then
				local p = vim.fn.fnamemodify(folder.path, ":p")
				table.insert(processed_wiki_paths, (normalize_path_for_comparison(p)))
			end
		end
	end

	local kiwi_augroup = vim.api.nvim_create_augroup("Kiwi", { clear = true })

	vim.api.nvim_create_autocmd("BufEnter", {
		group = kiwi_augroup,
		pattern = "*.md",
		callback = setup_keymaps_for_wiki_file,
		desc = "Set Kiwi keymaps for markdown files in wiki directories.",
	})
end

M.open_wiki_index = wiki.open_wiki_index
M.create_or_open_wiki_file = wiki.create_or_open_wiki_file
M.open_link = wiki.open_link

return M
