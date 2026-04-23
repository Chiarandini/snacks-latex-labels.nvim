local M = {}

-- ─── Default configuration ─────────────────────────────────────────────────
-- Mirrors telescope-latex-labels.nvim so users can share the same options
-- table (and therefore share the same on-disk cache).

local DEFAULT_CONFIG = {
  cache_strategy    = "global",
  recursive         = true,
  auto_update       = false,
  notify_on_update  = true,
  enable_smart_jump = true,
  smart_jump_window = 200,

  -- ── Export settings ──────────────────────────────────────────────────────
  -- These control the behaviour of :SnacksLatexLabelsExport.
  export_include_line       = true,
  export_include_title      = true,
  export_include_file       = true,
  export_use_relative_paths = false,
  export_exclude_files      = {},

  root_file          = "",
  subfile_toggle_key = "<C-g>",

  copy_label_key = "<C-y>",
  copy_transform = nil,

  transformations = {
    thm      = "th:",
    prop     = "pr:",
    defn     = "df:",
    lem      = "lm:",
    cor      = "co:",
    example  = "ex:",
    exercise = "x:",
  },

  patterns = {
    { pattern = "\\begin{(%w+)}{(.-)}{(.-)}", type = "environment" },
    { pattern = "\\label{(.-)}", type = "standard" },
  },
}

local config = {}

-- ─── Helpers ───────────────────────────────────────────────────────────────

---Apply an optional copy transformation to a label string.
---@param label     string
---@param transform table|function|nil
---@return string
local function apply_transform(label, transform)
  if not transform then return label end
  if type(transform) == "function" then
    return transform(label) or label
  elseif type(transform) == "table" then
    for prefix, fmt in pairs(transform) do
      if vim.startswith(label, prefix) then
        return string.format(fmt, label)
      end
    end
  end
  return label
end

-- ─── Picker ────────────────────────────────────────────────────────────────

---Open the Snacks picker for the current LaTeX project.
---@param overrides table|nil  Internal overrides for toggle: { mode, origin_filepath, root_filepath }
M.open = function(overrides)
  local core_snacks = require("latex_nav_core.snacks")
  local utils       = require("latex_nav_core.latex")
  -- All business logic (cache I/O, label scanner, latex helpers) lives in
  -- latex-nav-core. telescope-latex-references is no longer a runtime
  -- dependency of this plugin.
  local cache   = require("latex_nav_core.latex_labels.cache")
  local scanner = require("latex_nav_core.latex_labels.scanner")

  overrides = overrides or {}
  local mode = overrides.mode or "global"

  local origin_filepath = overrides.origin_filepath
    or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")

  if not origin_filepath or origin_filepath == "" then
    vim.notify("[snacks_latex_labels] No file associated with current buffer.", vim.log.levels.WARN)
    return
  end

  -- ── Root detection ────────────────────────────────────────────────────────
  local root_filepath = overrides.root_filepath
  if root_filepath == nil then
    root_filepath = utils.get_root_file()

    if root_filepath == origin_filepath then
      local sub_root = utils.find_root_via_subfiles(origin_filepath)
      if sub_root then root_filepath = sub_root end
    end

    if root_filepath == origin_filepath
        and config.root_file and config.root_file ~= "" then
      local abs = vim.fn.fnamemodify(config.root_file, ":p")
      if vim.fn.filereadable(abs) == 1 then root_filepath = abs end
    end
  end

  local is_subfile = root_filepath ~= nil and root_filepath ~= origin_filepath

  -- ── Cache load / generate ─────────────────────────────────────────────────
  local scan_from, cache_from
  if mode == "local" then
    scan_from  = origin_filepath
    cache_from = origin_filepath
  else
    scan_from  = root_filepath or origin_filepath
    cache_from = root_filepath or origin_filepath
  end

  local cache_path = cache.get_cache_path(cache_from, config.cache_strategy)
  local entries    = cache.read_cache(cache_path)

  if not entries then
    local scan_config = mode == "local"
      and vim.tbl_extend("force", config, { recursive = false })
      or config
    entries = scanner.scan_project(scan_from, scan_config)
    cache.write_cache(cache_path, entries)
  end

  if #entries == 0 then
    vim.notify("[snacks_latex_labels] No labels found.", vim.log.levels.INFO)
    return
  end

  -- ── Build Snacks items ────────────────────────────────────────────────────
  local items = {}
  for _, e in ipairs(entries) do
    local short = vim.fn.fnamemodify(e.filename, ":t:r")
    table.insert(items, {
      text   = e.id .. " " .. e.context .. " " .. short,
      file   = e.filename,
      pos    = { e.line, 0 },
      _entry = e,
    })
  end

  -- ── Prompt title ─────────────────────────────────────────────────────────
  local toggle_key = config.subfile_toggle_key or "<C-g>"
  local title
  if is_subfile or mode == "local" then
    if mode == "global" then
      title = "LaTeX Labels (full project) [" .. toggle_key .. ": this file]"
    else
      title = "LaTeX Labels (this file) [" .. toggle_key .. ": full project]"
    end
  else
    title = "LaTeX Labels"
  end

  -- ── Format function ───────────────────────────────────────────────────────
  local function format_item(item, _picker)
    local e     = item._entry
    local short = vim.fn.fnamemodify(e.filename, ":t:r")
    return {
      { "[" .. e.id .. "]",                     "Special"   },
      { " :: " .. e.context,                    "Comment"   },
      { "  (" .. short .. ":" .. e.line .. ")", "Directory" },
    }
  end

  -- ── Confirm action (smart jump) ───────────────────────────────────────────
  local function confirm(picker, item)
    picker:close()
    if not item then return end

    local e = item._entry
    local target_line = e.line

    if config.enable_smart_jump then
      local found = utils.verify_or_find_label(
        e.filename, e.line, e.id, config.smart_jump_window
      )

      if found and found ~= e.line then
        target_line = found
        if config.notify_on_update then
          vim.notify("[snacks_latex_labels] Label shifted. Cache auto-updated.", vim.log.levels.INFO)
        end

        local all = cache.read_cache(cache_path)
        if all then
          for _, ce in ipairs(all) do
            if ce.line == e.line and ce.id == e.id and ce.filename == e.filename then
              ce.line = found
              break
            end
          end
          cache.write_cache(cache_path, all)
        end

      elseif not found then
        vim.notify(
          "[snacks_latex_labels] [Warning] Label not found. Please run :LatexLabelsUpdate.",
          vim.log.levels.WARN
        )
      end
    end

    local current = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
    if current ~= e.filename then
      vim.cmd("edit " .. vim.fn.fnameescape(e.filename))
    end
    vim.api.nvim_win_set_cursor(0, { target_line, 0 })
    vim.cmd("normal! zz")
  end

  -- ── Extra actions and keymaps ─────────────────────────────────────────────
  local extra_actions = {}
  local extra_keys    = {}

  local copy_key = config.copy_label_key or "<C-y>"
  extra_actions["copy_label"] = function(picker2, item2)
    if not item2 then return end
    local text = apply_transform(item2._entry.id, config.copy_transform)
    vim.fn.setreg("+", text)
    vim.fn.setreg('"', text)
    picker2:close()
    vim.notify('[snacks_latex_labels] Copied "' .. text .. '" to clipboard.', vim.log.levels.INFO)
  end
  extra_keys[copy_key] = { "copy_label", mode = { "i", "n" } }

  if is_subfile or mode == "local" then
    local opposite = mode == "global" and "local" or "global"
    extra_actions["subfile_toggle"] = function(picker2, _item2)
      picker2:close()
      vim.schedule(function()
        M.open({
          mode            = opposite,
          origin_filepath = origin_filepath,
          root_filepath   = root_filepath,
        })
      end)
    end
    extra_keys[toggle_key] = { "subfile_toggle", mode = { "i", "n" } }
  end

  core_snacks.open({
    title         = title,
    items         = items,
    format        = format_item,
    confirm       = confirm,
    extra_actions = extra_actions,
    extra_keys    = extra_keys,
  })
end

-- ─── Export ────────────────────────────────────────────────────────────────

---Parse a command-line argument string into a pre_filled table for export_ui.
---Mirrors the identical helper in telescope-latex-reference.nvim.
---@param args_str string
---@return table
local function parse_export_args(args_str)
  if not args_str or args_str == "" then return {} end
  local result = {}
  for token in args_str:gmatch("%S+") do
    local key, val = token:match("^(%w+)=(.+)$")
    if key and val then
      if key == "format" then
        if ({ json=true, csv=true, tsv=true, txt=true })[val] then
          result.format = val
        end
      elseif key == "path" then
        result.path = vim.fn.expand(val)
      elseif key == "relative" then
        result.relative = (val == "true")
      elseif key == "line" then
        result.line = (val == "true")
      elseif key == "title" then
        result.title = (val == "true")
      elseif key == "file" then
        result.file = (val == "true")
      elseif key == "exclude" then
        result.exclude_files = vim.split(val, ",", { plain = true })
      end
    end
  end
  return result
end

local EXPORT_COMPLETIONS = {
  "format=json", "format=csv", "format=tsv", "format=txt",
  "path=",
  "relative=true", "relative=false",
  "line=true",     "line=false",
  "title=true",    "title=false",
  "file=true",     "file=false",
  "exclude=",
}

---Resolve the current project's root, load (or generate) its label cache,
---and open the export UI (or run directly when pre_filled is complete).
---@param pre_filled table  Output of parse_export_args (may be empty).
M.export_labels = function(pre_filled)
  local cache     = require("latex_nav_core.latex_labels.cache")
  local scanner   = require("latex_nav_core.latex_labels.scanner")
  local utils     = require("latex_nav_core.latex")
  local export_ui = require("latex_nav_core.export_ui")

  local root_file = utils.get_root_file()
  if not root_file then
    vim.notify("[snacks_latex_labels] No file associated with current buffer.", vim.log.levels.WARN)
    return
  end

  local cache_path = cache.get_cache_path(root_file, config.cache_strategy)
  local entries    = cache.read_cache(cache_path)

  if not entries then
    entries = scanner.scan_project(root_file, config)
    cache.write_cache(cache_path, entries)
  end

  if #entries == 0 then
    vim.notify("[snacks_latex_labels] No labels found for export.", vim.log.levels.WARN)
    return
  end

  export_ui.open(
    entries,
    root_file,
    {
      include_line       = config.export_include_line,
      include_title      = config.export_include_title,
      include_file       = config.export_include_file,
      use_relative_paths = config.export_use_relative_paths,
      exclude_files      = config.export_exclude_files,
    },
    pre_filled
  )
end

-- ─── Setup ─────────────────────────────────────────────────────────────────

---Configure the plugin and register commands.
---@param user_config table|nil  Overrides for DEFAULT_CONFIG.
M.setup = function(user_config)
  if not pcall(require, "latex_nav_core.cache") then
    vim.notify(
      "[snacks_latex_labels] Missing required dependency: latex-nav-core.nvim\n"
        .. "  Add 'Chiarandini/latex-nav-core.nvim' to your plugin manager.",
      vim.log.levels.ERROR
    )
    return
  end

  config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, user_config or {})

  vim.api.nvim_create_user_command("SnacksLatexLabels", function()
    M.open()
  end, { desc = "Open latex-labels Snacks picker" })

  -- :SnacksLatexLabelsExport [key=value ...] — export labels with optional args.
  -- Bang (!) forces the full interactive UI regardless of arguments.
  vim.api.nvim_create_user_command("SnacksLatexLabelsExport", function(cmd_opts)
    local pre_filled = cmd_opts.bang and {} or parse_export_args(cmd_opts.args)
    M.export_labels(pre_filled)
  end, {
    nargs    = "*",
    bang     = true,
    complete = function(arglead)
      local matches = {}
      for _, c in ipairs(EXPORT_COMPLETIONS) do
        if c:sub(1, #arglead) == arglead then
          table.insert(matches, c)
        end
      end
      return matches
    end,
    desc = "Export LaTeX labels to JSON / CSV / TSV / TXT",
  })
end

return M
