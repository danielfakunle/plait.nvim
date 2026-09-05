# Plait

**Build your Neovim configuration from capabilities, not plugins.**

Plait is a modular, distro-agnostic configuration framework for Neovim. It lets users assemble their own editor from cohesive capabilities such as Git, formatting, language intelligence, completion, and TypeScript support without manually integrating every underlying plugin.

```lua
require("plait").setup({
  modules = {
    "editor",
    "git",
    "language",
    "formatting",
    "lang.lua",
    "lang.typescript",
  },
})
```

Plait resolves dependencies between these modules and composes their:

- Neovim options
- Keymaps and autocmds
- Plugin specifications
- External development tools
- Provider configuration
- Commands and health checks

Users interact with stable, capability-level workflows:

```vim
:Plait tools
:Plait format
:Plait language
:Plait git
:Plait modules
:Plait health
```

For example, `:Plait tools` might use Mason internally, but users do not need to understand Mason for normal operation. Provider-specific commands, options, and APIs remain available as escape hatches.

Plait also makes the resulting configuration explainable:

- Which modules are active?
- Why was a plugin installed?
- Which provider implements a capability?
- Which tools does a language require?
- Which keymaps came from a module?
- Are all required tools available?

Plait occupies the space between raw Neovim configuration and a full distribution: it packages solved integrations while preserving user ownership of the editor.

## Non-goals

Plait is not:

- A complete Neovim distribution
- A plugin manager
- A replacement for its underlying plugins
- A duplicate of every provider's API
- An attempt to support every provider or language immediately

## Initial Scope

A focused first release should include the composition core, native editor behavior, language intelligence, formatting, Git, and Lua and TypeScript support, using one opinionated provider per capability.
