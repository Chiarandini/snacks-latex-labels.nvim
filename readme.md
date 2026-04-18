# snacks-latex-labels.nvim

A [Snacks.nvim](https://github.com/folke/snacks.nvim) picker for fast LaTeX
label navigation. This is the Snacks-native companion to
[telescope-latex-labels.nvim](https://github.com/Chiarandini/telescope-latex-references).

Both plugins share the same on-disk cache, so the project is only scanned once
regardless of which picker you open first.

## Dependencies

| Plugin | Role |
|---|---|
| [folke/snacks.nvim](https://github.com/folke/snacks.nvim) | Picker UI |
| [Chiarandini/latex-nav-core.nvim](https://github.com/Chiarandini/latex-nav-core.nvim) | Shared cache utilities and Snacks factory |
| [Chiarandini/telescope-latex-references](https://github.com/Chiarandini/telescope-latex-references) | Cache I/O, scanner, and smart-jump utilities |

## Installation

**lazy.nvim**

```lua
{
  "Chiarandini/snacks-latex-labels.nvim",
  dependencies = {
    "folke/snacks.nvim",
    "Chiarandini/latex-nav-core.nvim",
    "Chiarandini/telescope-latex-references",
  },
  config = function()
    require("snacks_latex_labels").setup({
      -- all keys are optional; defaults shown below
      cache_strategy    = "global",
      recursive         = true,
      auto_update       = false,
      enable_smart_jump = true,
      smart_jump_window = 200,

      root_file          = "",
      subfile_toggle_key = "<C-g>",
      copy_label_key     = "<C-y>",
      copy_transform     = nil,

      transformations = {
        thm = "th:", prop = "pr:", defn = "df:",
        lem = "lm:", cor = "co:", example = "ex:", exercise = "x:",
      },
    })
  end,
}
```

## Usage

```
:SnacksLatexLabels
```

Or map it:

```lua
vim.keymap.set("n", "<leader>fl",
  "<cmd>SnacksLatexLabels<cr>",
  { desc = "Find LaTeX labels (Snacks)" })
```

The picker behaviour is identical to the Telescope version:

- **Enter** — smart jump to the label (verifies position, auto-patches cache if shifted)
- **`<C-y>`** — copy the label id to the system clipboard (with optional `copy_transform`)
- **`<C-g>`** — subfile toggle (full project ↔ this file) when editing a subfile

## Configuration

All options are identical to
[telescope-latex-labels.nvim](https://github.com/Chiarandini/telescope-latex-references#configuration-reference).
If you use both pickers, pass the same table to both `setup()` calls to ensure
they share the same cache.

## Label Export

Export the current project's labels to JSON, CSV, TSV, or plain text with
`:SnacksLatexLabelsExport`. With no arguments, three sequential prompts guide
you through the format, output path, and path style. Every prompt can be
bypassed by passing `key=value` arguments on the command line.

```
:SnacksLatexLabelsExport [key=value ...]
```

Use `!` (bang) to force the full interactive UI regardless of any arguments:

```
:SnacksLatexLabelsExport!
```

### Arguments

| Argument | Values | Description |
|---|---|---|
| `format=` | `json` `csv` `tsv` `txt` | Output format; skips the format prompt |
| `path=` | any path | Output file or directory; skips the path prompt. `~`, `$VAR`, relative paths, and directories (default filename appended) are all accepted |
| `relative=` | `true` `false` | Path style; skips the path-style prompt |
| `line=` | `true` `false` | Include/omit line numbers (overrides config) |
| `title=` | `true` `false` | Include/omit label titles (overrides config) |
| `file=` | `true` `false` | Include/omit file paths (overrides config) |
| `exclude=` | `pat1,pat2,...` | Lua patterns — labels whose filename matches are omitted |

Tab-completion is available for all arguments.

### Examples

```vim
" Interactive — all three prompts
:SnacksLatexLabelsExport

" Silent JSON export to the project root
:SnacksLatexLabelsExport format=json path=. relative=false

" Minimal CSV — IDs and titles only
:SnacksLatexLabelsExport format=csv line=false file=false path=~/labels.csv

" Exclude archived files from the export
:SnacksLatexLabelsExport format=json exclude=archive,backup
```

### Export configuration

These keys can be set in `setup()` to provide defaults that the export command
uses when the corresponding argument is not supplied:

| Option | Type | Default | Description |
|---|---|---|---|
| `export_include_line` | `boolean` | `true` | Include line numbers in exported records |
| `export_include_title` | `boolean` | `true` | Include label titles in exported records |
| `export_include_file` | `boolean` | `true` | Include file paths in exported records |
| `export_use_relative_paths` | `boolean` | `false` | Use paths relative to project root |
| `export_exclude_files` | `table` | `{}` | Lua patterns — matching filenames are excluded |

## Shared cache

Both this plugin and `telescope-latex-labels.nvim` call
`latex_nav_core.cache.get_cache_path` with the same arguments, so they resolve
to the exact same `.labels` file. The project is scanned only on the first open,
whichever picker triggers it.
