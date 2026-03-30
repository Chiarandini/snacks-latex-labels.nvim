# snacks-latex-labels.nvim

A [Snacks.nvim](https://github.com/folke/snacks.nvim) picker for fast LaTeX
label navigation. This is the Snacks-native companion to
[telescope-latex-labels.nvim](https://github.com/Chiarandini/telescope-latex-reference.nvim).

Both plugins share the same on-disk cache, so the project is only scanned once
regardless of which picker you open first.

## Dependencies

| Plugin | Role |
|---|---|
| [folke/snacks.nvim](https://github.com/folke/snacks.nvim) | Picker UI |
| [Chiarandini/latex-nav-core.nvim](https://github.com/Chiarandini/latex-nav-core.nvim) | Shared cache utilities and Snacks factory |
| [Chiarandini/telescope-latex-reference.nvim](https://github.com/Chiarandini/telescope-latex-reference.nvim) | Cache I/O, scanner, and smart-jump utilities |

## Installation

**lazy.nvim**

```lua
{
  "Chiarandini/snacks-latex-labels.nvim",
  dependencies = {
    "folke/snacks.nvim",
    "Chiarandini/latex-nav-core.nvim",
    "Chiarandini/telescope-latex-reference.nvim",
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
[telescope-latex-labels.nvim](https://github.com/Chiarandini/telescope-latex-reference.nvim#configuration-reference).
If you use both pickers, pass the same table to both `setup()` calls to ensure
they share the same cache.

## Shared cache

Both this plugin and `telescope-latex-labels.nvim` call
`latex_nav_core.cache.get_cache_path` with the same arguments, so they resolve
to the exact same `.labels` file. The project is scanned only on the first open,
whichever picker triggers it.
