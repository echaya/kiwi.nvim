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
-- 1. Converts the entire path to lowercase.
-- 2. Converts all backslashes (`\`) to forward slashes (`/`).
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
-- This function is designed to be used as an autocmd callback.
local function setup_keymaps_for_wiki_file()
	-- 1. Ensure the filetype is markdown.
	if vim.bo.filetype ~= "markdown" then
		return
	end

	-- 2. Get the full, absolute path of the current buffer.
	local buf_path = vim.api.nvim_buf_get_name(0)
	if not buf_path or buf_path == "" then
		return
	end
	local current_file_path = vim.fn.fnamemodify(buf_path, ":p")
	local normalized_current_path = normalize_path_for_comparison(current_file_path)
	vim.notify("normalized_current_path: " .. normalized_current_path)

	-- 3. Collect all configured wiki directory paths.
	local wiki_paths = {}
	if config.path and config.path ~= "" then
		table.insert(wiki_paths, vim.fn.fnamemodify(config.path, ":p"))
	end
	if config.folders then
		for _, folder in ipairs(config.folders) do
			if folder.path then
				table.insert(wiki_paths, vim.fn.fnamemodify(folder.path, ":p"))
			end
		end
	end

	-- 4. Check if the current file's path is inside any wiki directory.
	local is_in_wiki_dir = false
	for _, wiki_dir in ipairs(wiki_paths) do
		local normalized_wiki_dir = normalize_path_for_comparison(wiki_dir)
		vim.notify("normalized_wiki_dir: " .. normalized_wiki_dir)

		-- Ensure the wiki directory path ends with a slash for a clean "starts with" check.
		if not normalized_wiki_dir:find("/$") then
			normalized_wiki_dir = normalized_wiki_dir .. "/"
		end

		-- Check if the normalized file path starts with the normalized wiki directory path.
		if normalized_current_path:find(normalized_wiki_dir, 1, true) == 1 then
			is_in_wiki_dir = true
			break
		end
	end

	-- 5. If it's a match, call the internal function to create the keymaps.
	if is_in_wiki_dir then
		create_buffer_keymaps(0) -- The '0' signifies the current buffer.
	end
end

M.setup = function(opts)
	-- Perform the original setup from your utils file.
	utils.setup(opts, config)

	-- Create a dedicated, clearable augroup for your plugin's autocommands.
	local kiwi_augroup = vim.api.nvim_create_augroup("Kiwi", { clear = true })

	-- Create the autocmd to run on entering a markdown buffer.
	vim.api.nvim_create_autocmd("BufEnter", {
		group = kiwi_augroup,
		pattern = "*.md", -- Pattern to only trigger for markdown files.
		callback = setup_keymaps_for_wiki_file,
		desc = "Set Kiwi keymaps for markdown files in wiki directories.",
	})
end

M.open_wiki_index = wiki.open_wiki_index
M.create_or_open_wiki_file = wiki.create_or_open_wiki_file
M.open_link = wiki.open_link

return M
