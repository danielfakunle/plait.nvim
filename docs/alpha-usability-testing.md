# Alpha Usability Testing

This procedure tests the implemented Alpha surface:

- Configuration collection and validation
- Explicit module dependency resolution
- Deterministic plan generation
- Inspection and health reporting
- Editor options, mappings, actions, clipboard policy, and yank highlighting
- Lifecycle and error feedback

Language, completion, formatting, tooling, package management, and provider activation are not runtime features yet. They should appear in plans, but should not configure plugins or tools.

## 1. Create an isolated environment

Use a fresh terminal so your normal Neovim configuration cannot affect the results:

```sh
export PLAIT_REPO=/Users/daniel/Developer/plait.nvim
export PLAIT_UX="$(mktemp -d /tmp/plait-alpha-ux.XXXXXX)"
export XDG_CONFIG_HOME="$PLAIT_UX/config"
export XDG_DATA_HOME="$PLAIT_UX/data"
export XDG_STATE_HOME="$PLAIT_UX/state"
export XDG_CACHE_HOME="$PLAIT_UX/cache"

mkdir -p "$XDG_CONFIG_HOME/nvim"
```

Confirm the tested Neovim is in the supported range:

```sh
nvim --version
```

Expected: Neovim `>=0.12.5,<0.13.0`.

## 2. Create the test configuration

Create `$XDG_CONFIG_HOME/nvim/init.lua` with:

```lua
vim.opt.runtimepath:prepend(vim.env.PLAIT_REPO)

local plait = require('plait')
local config = plait.config()
local profile = vim.env.PLAIT_PROFILE or 'default'

_G.plait = plait
_G.plait_config = config

if profile == 'invalid' then
  config:select({ 'completion' })
  config:configure({
    editor = {
      indentation = {
        width = 0,
      },
    },
  })

  _G.plait_validation = config:validate()
  return
end

config:select({
  'editor',
  'language',
  'completion',
  'formatting',
  'tooling',
  'lang.lua',
  'lang.typescript',
})

local editor = {}

if profile == 'custom' then
  editor = {
    line_numbers = 'off',
    persistent_undo = false,
    yank_highlight = false,
    splits = {
      horizontal = 'above',
      vertical = 'left',
    },
    indentation = {
      style = 'tabs',
      width = 4,
    },
    wrap = true,
    clipboard = 'disabled',
    mappings = {
      save = '<leader>w',
      clear_search = false,
      focus_left = false,
    },
  }
end

config:configure({
  editor = editor,
})

_G.plait_validation = config:validate()
_G.plait_apply = config:apply()
```

## Default journey

### 3. Start Neovim

```sh
PLAIT_PROFILE=default nvim "$PLAIT_UX/notes.txt"
```

Record whether startup is clean and whether any messages are confusing.

Inspect the startup results:

```vim
:lua vim.print(_G.plait_validation)
:lua vim.print(_G.plait_apply)
```

Expected:

- Validation status is `valid`.
- Apply status is `performed`.
- Both report the same 64-character plan ID.
- Completed effects include native options, actions, mappings, and yank highlighting.
- No failed or skipped effects appear.

### 4. Inspect the effective plan

Run:

```vim
:Plait inspect modules
:Plait inspect capabilities
:Plait inspect effects
:Plait inspect packages
:Plait inspect tools
:Plait inspect diagnostics
```

Expected:

- Every selected module appears exactly once.
- Dependencies are explicit and deterministically ordered.
- The editor capability shows its default configuration.
- Every editor effect is `completed`.
- Packages and tools are empty in Alpha.
- Diagnostics are empty.
- Output is understandable without consulting implementation code.

Also run:

```vim
:Plait inspect capabilities editor
:Plait inspect effects editor/native-options
```

Consider whether finding a specific record feels natural.

### 5. Test editor defaults

Check the managed settings:

```vim
:set termguicolors?
:set ignorecase?
:set smartcase?
:set signcolumn?
:set number?
:set relativenumber?
:set undofile?
:set splitbelow?
:set splitright?
:set expandtab?
:set shiftwidth?
:set tabstop?
:set softtabstop?
:set wrap?
:set linebreak?
:set breakindent?
:set clipboard?
```

Expected default highlights:

- Absolute line numbers
- Persistent undo enabled
- New horizontal splits below
- New vertical splits right
- Spaces with width 2
- Wrapping disabled
- `unnamedplus` clipboard outside SSH
- `termguicolors`, smart-case searching, and permanent sign column enabled

### 6. Test editing behavior

Perform these manually:

1. Enter insert mode and type several lines.
2. Press `<C-s>` while still in insert mode.
3. Modify text, visually select it, and press `<C-s>`.
4. Confirm the file was written without leaving the current workflow unexpectedly.
5. Search for a visible word using `/word`.
6. Press `<Esc>` from normal mode.
7. Confirm search highlighting clears.
8. Yank a line with `yy`.
9. Confirm the yanked region briefly receives `IncSearch` highlighting.
10. Confirm Enter and Tab retain normal Neovim behavior.

### 7. Test splits and focus

Run:

```vim
:vsplit
:split
```

Expected:

- The vertical split opens on the right.
- The horizontal split opens below.

Exercise:

- `<C-h>`
- `<C-j>`
- `<C-k>`
- `<C-l>`

Expected: focus moves geometrically between windows.

Close all but one window and run:

```vim
:lua vim.print(require('plait').actions.editor.focus('right'))
```

Expected: `performed`, even though focus remains in the same window.

### 8. Test public actions

Run:

```vim
:lua vim.print(require('plait').actions.editor.save())
:lua vim.print(require('plait').actions.editor.clear_search())
:lua vim.print(require('plait').actions.editor.focus('left'))
```

Expected: each returns a closed result containing `status`, `operation`, and `details`.

Try an invalid direction:

```vim
:lua require('plait').actions.editor.focus('diagonal')
```

Expected:

```text
plait: editor focus direction must be left, down, up, or right
```

Evaluate whether the returned results and error make the next action obvious.

### 9. Test persistent undo

1. Add a recognizable line.
2. Save and quit.
3. Restart with the same command.
4. Press `u`.

Expected: the previous-session change can be undone.

## Customization journey

### 10. Start the custom profile

Quit and run:

```sh
PLAIT_PROFILE=custom nvim "$PLAIT_UX/custom.txt"
```

Verify:

- Line numbers are off.
- Persistent undo is off.
- New splits open above and left.
- Indentation uses tabs with width 4.
- Wrapping, line breaking, and break indentation are enabled together.
- Clipboard integration is disabled.
- Yank highlighting does not occur.
- `<leader>w` saves.
- `<C-s>` is unmanaged.
- `<Esc>` does not receive Plait's clear-search mapping.
- `<C-h>` does not receive Plait's focus-left mapping.
- The other default focus mappings still work.

Inspect the configuration:

```vim
:Plait inspect capabilities editor
```

Expected: the inspected values accurately explain the behavior you observed.

## Diagnostics journey

### 11. Start an invalid configuration

Quit and run:

```sh
PLAIT_PROFILE=invalid nvim
```

Run:

```vim
:lua vim.print(_G.plait_validation)
:Plait validate
:Plait inspect diagnostics
:Plait inspect modules
```

Expected diagnostics:

- `completion` reports its missing `language` dependency.
- Editor indentation width `0` reports `config.invalid`.
- Diagnostics identify the configuration path and source.
- The invalid snapshot has no effective modules or effects.
- The error text is bounded and actionable.

Assess whether you could repair both problems without reading Plait's source.

### 12. Test lifecycle feedback

In the invalid session, invoke apply after startup:

```vim
:lua _G.plait_config:apply()
```

Expected:

```text
plait: apply is only available during synchronous init.lua startup
```

Try changing the sealed collector:

```vim
:lua _G.plait_config:select({ 'editor' })
```

Expected:

```text
plait: configuration collector is sealed
```

Try creating another collector:

```vim
:lua require('plait').config()
```

Expected:

```text
plait: a configuration collector already exists
```

## Health journey

### 13. Review health output

Restart the default profile and run:

```vim
:checkhealth plait
```

Verify that it reports:

- Plait and Neovim versions
- Configured status
- Platform compatibility
- Git availability
- Provider presence and revisions
- External tool paths and versions
- Clipboard strategy
- Blink fuzzy implementation status

Missing providers and tools are expected during Alpha. Evaluate whether health clearly distinguishes:

- Required failures
- Compatibility warnings
- Expected missing future integrations
- Informational details

## Feedback rubric

For each section, record:

| Area | Pass | Hesitation | Failure | Notes |
| --- | --- | --- | --- | --- |
| Initial configuration readability | | | | |
| Module/dependency model | | | | |
| Validation errors | | | | |
| Inspection discoverability | | | | |
| Inspection readability | | | | |
| Editor defaults | | | | |
| Customization predictability | | | | |
| Action result clarity | | | | |
| Lifecycle errors | | | | |
| Health usefulness | | | | |

Also record:

- Anything you expected to work that did not
- Any output requiring source-code knowledge
- Any surprising default
- Any configuration name you had to reread
- Any point where Plait's ownership boundary was unclear
- Whether you would trust the inspected plan to explain your editor state

The Alpha usability test passes if the editor journey works end-to-end, invalid configurations are repairable from diagnostics alone, inspection accurately explains observed behavior, and missing Beta functionality is not mistaken for a broken Alpha feature.
