local config = require("kiwi.config")
local utils = require("kiwi.utils")
local todo = require("kiwi.todo")
local wiki = require("kiwi.wiki")
local processed_wiki_paths = {}

local M = {}

M.todo = todo
M.utils = utils
M.VERSION = "0.4.0"

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
	local current_filename = vim.fn.fnamemodify(buf_path, ":t"):lower()

	local matching_wikis = {}
	for _, wiki_info in ipairs(processed_wiki_paths) do
		local dir_to_check = wiki_info.normalized
		if not dir_to_check:find("/$") then
			dir_to_check = dir_to_check .. "/"
		end

		if normalized_current_path:find(dir_to_check, 1, true) == 1 then
			table.insert(matching_wikis, wiki_info)
		end
	end

	if #matching_wikis == 0 then
		return
	end

	table.sort(matching_wikis, function(a, b)
		return #a.normalized > #b.normalized
	end)

	local wiki_root_to_set = nil
	if current_filename == "index.md" and #matching_wikis >= 2 then
		wiki_root_to_set = matching_wikis[2].resolved
	else
		wiki_root_to_set = matching_wikis[1].resolved
	end

	if wiki_root_to_set then
		vim.b[0].wiki_root = wiki_root_to_set
		wiki._create_buffer_keymaps(0)
	end
end

M.setup = function(opts)
	utils.setup(opts, config)

	processed_wiki_paths = {}
	if config.path and config.path ~= "" then
		local resolved_path = vim.fn.fnamemodify(config.path, ":p")
		table.insert(processed_wiki_paths, {
			resolved = resolved_path,
			normalized = normalize_path_for_comparison(resolved_path),
		})
	end
	if config.folders then
		for _, folder in ipairs(config.folders) do
			if folder.path then
				-- The path from config should already be absolute via utils.ensure_directories
				local resolved_path = vim.fn.fnamemodify(folder.path, ":p")
				table.insert(processed_wiki_paths, {
					resolved = resolved_path,
					normalized = normalize_path_for_comparison(resolved_path),
				})
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
M.jump_to_index = wiki.jump_to_index

return M
