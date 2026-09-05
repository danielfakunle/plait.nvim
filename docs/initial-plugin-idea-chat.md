# Evaluate Neovim Plugin Idea

## User

I would like to create a neovim plugin and I’m considering whether it would be worthwhile to develop. The motivations behind this plugin are this

- Building a neovim configuration is pretty fragmented. You install one plugin from here, install other from here, do a lot a tinkering and the result a functional configuration. The functionality you want to add, the more complex the configuration becomes. There have been plugins that have been created to address this somewhat, like mini.nvim and snacks.nvim. However these plugins don’t really feel like “a plugin that provides and easy, organized and performant way to create a neovim config, not just plugins, but options and keymaps”
- Some functionality of some features of an editor are too spread out between different plugins. For instance, to add language intelligence, you’ll probably install plugins like mason, mason-lspconfig, nvim-lspconfig, mason-tool-installer, schemastore (for some languages like yaml). To address this, my plugin would provides configuration “modules”, opinionated drop in imports that can be added to a config, tweaked a bit to suit the needs of the user, and it will provide a editor feature (like language intelligence, formatting, git integration, ai etc). The downside of this that I’m predicting now is that building something like this would mean that if I want to provide a centralized interface (i.e., eliminate the need for a user to look at the documentation of another plugin that provides some of the functionality of the module), I may have to basically clone existing plugins or at least expose those plugins’ interfaces through my own plugin. As possible way to address this may be to only implement the absolute basics of these plugins and not the other nice to have features that some of these plugins tend to have.

Those are my main motivations. I want you to help be evaluate whether this is a worthwhile plugin to try and implement.

## Assistant

Your idea is potentially worthwhile, but the key question is **whether it should be a “plugin,” a configuration framework, or a curated module layer on top of existing plugins**. I’m going to compare it against the current Neovim ecosystem, then pressure-test the architecture and suggest an MVP that avoids turning you into a wrapper-maintenance project.

## Assistant

The strongest existing overlap I’m seeing is **LazyVim Extras / AstroCommunity**, not mini.nvim or snacks.nvim. Both already package “capabilities” and language support as importable configuration specs, which means your idea needs to differentiate from *a distro’s optional modules*, not merely from collections of utility plugins. 

A useful opening, though, is that those systems are tied to their parent configuration frameworks. Your concept could instead make the **module system itself** the product.

## Assistant

Yes — **I think this is worth prototyping**, but I would change the product definition slightly.

The compelling version is not:

> “One giant Neovim plugin that replaces lots of other plugins.”

It is:

> **A composable Neovim configuration framework that lets users build their own config from cohesive editor capabilities.**

That distinction solves much of the interface-cloning problem you're anticipating.

## Where your idea fits

The Neovim ecosystem roughly has four layers today:

| Layer | Examples | What it solves |
|---|---|---|
| Plugin management | `lazy.nvim`, `vim.pack` | Installing/loading plugins |
| Individual functionality | Telescope, conform, gitsigns, blink.cmp, etc. | One particular capability |
| Plugin suites | `mini.nvim`, `snacks.nvim` | Many capabilities with consistent APIs |
| Distributions/frameworks | LazyVim, AstroNvim, NvChad | A complete prebuilt editor experience |

Your project could occupy a somewhat underdeveloped space **between the plugin-manager and distro layers**:

> **Reusable configuration composition.**

Neovim itself is moving toward more native infrastructure. For example, Neovim 0.12 now has the experimental `vim.pack` plugin manager, and modern LSP setup uses `vim.lsp.config()` / `vim.lsp.enable()` directly.

But that doesn't solve:

- organizing options
- organizing mappings
- organizing autocmds
- deciding which plugins collectively implement a feature
- configuring those plugins so they cooperate
- installing external tools
- configuring a language holistically
- maintaining consistent mappings/UI conventions across capabilities

That's where your idea has value.

---

# The biggest competitor is actually LazyVim

This is the part I would pay the most attention to.

LazyVim already separates:

```text
lua/config/options.lua
lua/config/keymaps.lua
lua/config/autocmds.lua
lua/plugins/*
```

and automatically manages when those pieces are loaded.

More importantly, **LazyVim Extras are extremely close to your module concept**.

For example:

```lua
{ import = "lazyvim.plugins.extras.lang.python" }
{ import = "lazyvim.plugins.extras.lang.json" }
```

can pull together the necessary plugins and their configurations. Its JSON extra incorporates things such as Tree-sitter, SchemaStore and LSP configuration.

AstroNvim has gone even farther in this direction with AstroCommunity. It describes its community repository as reusable configuration pieces ranging from individual plugins to entire language-support collections.

So I **wouldn't** pitch your plugin as:

> "Neovim doesn't have reusable configuration modules."

It does.

The differentiation should instead be:

> **I want reusable configuration modules without adopting somebody else's Neovim distribution.**

That's substantially more interesting.

---

# The target user I'd build for

There's an important user between these two extremes.

### User A

> "I don't want to configure Neovim. Just give me a good editor."

Use LazyVim/NvChad/AstroNvim.

### User B

> "I want complete control. I'll configure every plugin myself."

Use `vim.pack`/lazy.nvim and raw Lua.

### Your user

> "I want to build *my own* Neovim configuration, but I shouldn't have to reinvent every solved integration."

That's a real niche.

They might want:

```lua
require("foo").setup({
  modules = {
    "editor",
    "git",
    "lsp",
    "formatting",
    "completion",

    { import = "lang.lua" },
    { import = "lang.typescript" },
  }
})
```

while still feeling:

> **This is my Neovim config.**

rather than:

> "This is LazyVim with my customizations."

That psychological distinction is surprisingly important in the Neovim community.

---

# I would separate two concepts in your design

Your original idea mixes these somewhat.

## 1. Configuration primitives

These solve the organization problem.

For example, perhaps a module can declaratively define:

```lua
return {
  options = {
    number = true,
    relativenumber = true,
    signcolumn = "yes",
  },

  globals = {
    mapleader = " ",
  },

  keymaps = {
    { "n", "<leader>w", "<cmd>w<cr>", desc = "Save" },
  },

  autocmds = {
    {
      event = "TextYankPost",
      callback = function()
        vim.highlight.on_yank()
      end,
    },
  },

  plugins = {
    -- ...
  },
}
```

Then your framework owns:

- loading
- merging
- overriding
- ordering
- validation
- conflicts
- module dependencies

This is genuinely useful independently of your prebuilt modules.

## 2. Capability modules

These are curated recipes.

For example:

```text
modules/
  editor.lua
  completion.lua
  formatting.lua
  git.lua
  lsp.lua
  diagnostics.lua
  ai.lua

  lang/
    lua.lua
    typescript.lua
    python.lua
    rust.lua
```

`lang.typescript` might declare:

```text
TypeScript
├── Tree-sitter parser
├── LSP
├── formatter
├── linter
├── debugger
└── relevant mappings
```

The important part is that the user thinks in terms of:

> "I want TypeScript support."

not:

> "I need to learn how six unrelated Neovim plugins interact."

This is the strongest part of your concept.

---

# Don't clone plugin interfaces

I think the concern you raised here is exactly right.

Suppose your git module uses gitsigns.

A dangerous design would be:

```lua
git = {
  signs = {...},
  signs_staged = {...},
  signs_staged_enable = true,
  signcolumn = true,
  numhl = false,
  linehl = false,
  word_diff = false,
  watch_gitdir = {...},
  attach_to_untracked = true,
  ...
}
```

At that point you've just recreated `gitsigns.setup()`.

And every gitsigns release potentially creates work for you.

Don't do that.

Instead, have three levels.

## Level 1: intent-level configuration

Your API should cover things users conceptually care about.

Something like:

```lua
git = {
  signs = true,
  blame = true,
  keymaps = true,
}
```

This is **your API**.

It should remain small.

## Level 2: provider selection

Perhaps:

```lua
git = {
  provider = "gitsigns",
}
```

Eventually another implementation could exist.

Same for:

```lua
completion = {
  provider = "blink",
}
```

or:

```lua
picker = {
  provider = "snacks",
}
```

You don't even need multiple providers initially. The abstraction simply keeps the module centered on capability rather than implementation.

## Level 3: escape hatch

This is crucial.

Let advanced users configure the underlying plugin directly.

Something conceptually like:

```lua
git = {
  provider = "gitsigns",

  provider_opts = {
    current_line_blame_opts = {
      delay = 300,
    },
  },
}
```

Or even better:

```lua
git = {
  extend = function(ctx)
    ctx.plugins.gitsigns.opts.current_line_blame = true
  end,
}
```

Then your documentation says:

> Foo configures the common use case. For advanced gitsigns configuration, use `extend` and refer to gitsigns' documentation.

**You don't need to pretend the underlying plugin doesn't exist.**

That's probably the single most important architectural decision I'd make.

---

# Think of modules as recipes, not wrappers

This would be my guiding principle.

Your module doesn't provide:

```lua
foo.lsp.hover()
foo.lsp.rename()
foo.git.stage_hunk()
foo.git.reset_hunk()
```

Those would become wrapper APIs you must maintain.

Instead your module says:

> "Here is a good integrated LSP setup."

And creates mappings directly against native APIs:

```lua
vim.lsp.buf.hover
vim.lsp.buf.rename
vim.lsp.buf.code_action
```

When it relies on a plugin, reference the plugin's API directly internally.

This significantly lowers your maintenance cost.

---

# Your LSP example is particularly interesting

You mentioned something like:

```text
mason
mason-lspconfig
nvim-lspconfig
mason-tool-installer
schemastore
```

Historically that's a good example of Neovim's configuration fragmentation.

But interestingly, the ecosystem is changing in a direction favorable to your concept.

Neovim now natively supports:

```lua
vim.lsp.config(...)
vim.lsp.enable(...)
```

and config files on `runtimepath`; nvim-lspconfig increasingly serves as a repository of server configurations rather than an abstraction over the LSP client itself.

Likewise, Neovim 0.12 now includes `vim.pack`, although it is still marked experimental.

So instead of endlessly composing abstraction on abstraction, your project could have a philosophy like:

> **Use native Neovim wherever possible. Add external plugins only when Neovim doesn't provide the capability.**

That could become a strong differentiator.

For example:

```text
language.typescript

Native:
  vim.lsp
  vim.diagnostic
  vim.pack

External:
  nvim-lspconfig       → LSP definitions
  conform.nvim         → formatting
  SchemaStore.nvim     → schemas
  nvim-treesitter      → parsing
```

As Neovim gains capabilities, your module gets simpler.

---

# I would also avoid making a plugin manager

Especially now.

`lazy.nvim` already has an extremely sophisticated specification system, including module imports, dependencies, merging, lazy-loading and scoped specs.

And Neovim is developing `vim.pack`.

You don't gain much by competing there.

Instead, your architecture could eventually support:

```text
Your modules
     ↓
configuration resolver
     ↓
┌─────────────┬─────────────┐
│ lazy.nvim   │ vim.pack    │
└─────────────┴─────────────┘
```

For an MVP, however, I would support **exactly one**.

Probably lazy.nvim initially simply because its spec-composition features are mature.

Later you could introduce a `vim.pack` backend.

---

# What I would actually build first

Don't start by trying to create:

```text
AI
Git
LSP
DAP
Formatting
Testing
Files
Buffers
Sessions
Terminal
Completion
Snippets
20 languages
...
```

You'll drown in maintenance before discovering whether the architecture is good.

I'd build roughly five things.

### Core

The module composition system itself:

```lua
require("foo").setup({
  modules = {...},

  options = {...},
  keymaps = {...},
})
```

with:

- deep merging
- module dependencies
- user overrides
- plugin specs
- keymaps
- options
- autocmds

### Editor

Only native settings:

```text
sensible options
basic mappings
autocommands
diagnostics UI
```

No large dependencies.

### LSP

A generic language-intelligence module.

### Formatting

Probably using something like conform.nvim.

### Git

A small integrated configuration.

### Two languages

Perhaps:

```text
Lua
TypeScript
```

because they're complex enough to test the architecture but familiar enough to debug easily.

And stop.

If those feel elegant, then add more.

---

# The API should make this look dramatically simpler

This is the test I would use.

Imagine someone currently has 1,500 lines of config.

Can you make the conceptual structure become:

```lua
require("foo").setup({
  modules = {
    "editor",
    "git",
    "completion",
    "lsp",
    "formatting",

    "lang.lua",
    "lang.typescript",
  },

  options = {
    relativenumber = false,
  },

  keymaps = {
    { "n", "<leader>e", function()
      -- ...
    end },
  },
})
```

and perhaps:

```lua
require("foo").module("git", {
  blame = false,
})
```

while still letting that person drop a completely arbitrary Neovim plugin into their config?

If yes, you've got something.

If your resulting API looks like:

```lua
require("foo").setup({
  lsp = {
    mason = {
      ...
    },
    lspconfig = {
      ...
    },
    blink = {
      ...
    },
    conform = {
      ...
    },
  },
})
```

you haven't really solved the problem.

You've just moved the config into another table.

---

# One feature I think could make this genuinely compelling

**Capabilities and dependencies.**

Instead of modules merely importing other files:

```lua
typescript.requires = {
  "lsp",
  "formatting",
  "treesitter",
}
```

A module could declare capabilities:

```lua
return {
  provides = {
    "language.typescript",
  },

  requires = {
    "lsp",
    "completion",
    "formatting",
  },
}
```

Your resolver could then construct the required configuration graph.

That allows something like:

```lua
modules = {
  "lang.typescript",
}
```

to implicitly install:

```text
lang.typescript
   ↓
LSP
   ↓
completion

lang.typescript
   ↓
formatting

lang.typescript
   ↓
treesitter
```

Now you're solving an actual configuration-management problem rather than creating a collection of configs.

You could eventually even detect conflicts:

```text
completion.blink
completion.cmp
```

and say:

```text
Conflicting providers for capability `completion`.
```

That's much more interesting architecturally.

---

# There is also an opportunity around introspection

Neovim config gets difficult partly because once enough things are installed, users lose track of **why something exists**.

Imagine:

```vim
:Foo modules
```

showing:

```text
✓ editor
✓ git
✓ lsp
│
├─ blink.cmp
├─ nvim-lspconfig
└─ mason.nvim

✓ lang.typescript
│
├─ requires: lsp
├─ requires: formatting
├─ LSP: vtsls
├─ formatter: prettier
└─ parser: typescript
```

Or:

```vim
:Foo why conform.nvim
```

giving:

```text
conform.nvim
└── formatting
    └── lang.typescript
```

Or:

```vim
:Foo keymaps git
```

That reinforces your central promise:

> **Your configuration is understandable as a system.**

I think that's more compelling than merely reducing lines of Lua.

---

# Where I think the project would fail

There are four particularly dangerous directions.

**Becoming another Neovim distro.** If you ship a theme, statusline, dashboard, 40 plugins and your preferred mappings, people will compare you directly with LazyVim/NvChad/AstroNvim—and those projects have an enormous head start.

**Mirroring every plugin's configuration interface.** This creates an unsustainable maintenance treadmill.

**Supporting too many alternatives.** If your first completion module supports blink.cmp, nvim-cmp and three other engines, every combination multiplies your test surface.

**Promising that users never need underlying documentation.** I wouldn't make that a goal. Your framework should mean users rarely need the underlying documentation for normal configuration. Advanced usage should intentionally escape down one abstraction level.

---

# Your positioning matters enormously

I wouldn't describe it as:

> An all-in-one Neovim plugin.

That sounds like mini.nvim or snacks.nvim.

And I wouldn't describe it as:

> An easy Neovim distribution.

That sounds like LazyVim.

Something closer to:

> **A modular framework for building your own Neovim configuration.**

or:

> **Composable editor capabilities for Neovim.**

or:

> **Build a Neovim config from features, not plugins.**

That last one captures the idea particularly well:

```text
Traditional:

"I need an LSP plugin, package installer,
completion source, formatter, SchemaStore..."

Your model:

"I want TypeScript support."
```

That's the abstraction you should protect.

---

# How I rate the idea

| Dimension | My assessment |
|---|---:|
| Problem is real | **9/10** |
| Existing competition | **8/10** |
| Differentiation as originally described | **5/10** |
| Differentiation as distro-agnostic capability framework | **8/10** |
| MVP feasibility | **8/10** |
| Maintenance risk if tightly scoped | **6/10** |
| Maintenance risk if you wrap everything | **10/10** |
| Interesting open-source project | **9/10** |

So **yes, I'd build it**.

But I'd build the **configuration framework first and the modules second**.

The framework itself should solve:

```text
composition
dependency resolution
overrides
options
keymaps
autocommands
plugin declarations
capabilities
providers
introspection
```

Then `lsp`, `git`, `typescript`, etc. become demonstrations of that architecture rather than the architecture itself.

And I would explicitly adopt the rule:

> **80% use case through our API; 20% advanced use case through an escape hatch to the underlying plugin.**

That prevents the project from turning into a compatibility wrapper for the entire Neovim ecosystem.

The result would sit in a fairly attractive middle ground: **much less fragmented than raw Neovim, much more ownership and composability than adopting LazyVim/AstroNvim wholesale, and fundamentally different from mini.nvim/snacks.nvim because you're organizing functionality rather than reimplementing it.**

## User

regarding your statement on "modules as recipes, not wrappers", let's say a module using mason internally. Requiring the using to type `:Mason` to access to tool installer window doesn't seem elegant to me.

## Assistant

I agree. Requiring the user to know that your `language` module happens to use Mason undermines the abstraction.

“Recipes, not wrappers” shouldn’t mean **leaking implementation details into the user experience**. I’d distinguish between wrapping a plugin’s *entire API* and providing a small **capability-level facade**.

For example, if your plugin were called `hvn`, I’d much rather expose:

```vim
:Hvn tools
```

than expect:

```vim
:Mason
```

Internally:

```text
:Hvn tools
    ↓
language/tooling capability
    ↓
Mason provider
    ↓
:Mason
```

The user thinks:

> “I want to manage development tools.”

They shouldn't have to think:

> “Which package-management plugin did HVN choose?”

That abstraction is valuable.

## What I would wrap

I'd wrap **user intentions**, not Mason's API.

For example:

```vim
:Hvn tools
:Hvn tools install
:Hvn tools update
:Hvn tools status
```

Those are concepts belonging to your framework.

Internally they could translate to Mason functionality.

Likewise:

```vim
:Hvn format
:Hvn diagnostics
:Hvn git
:Hvn languages
:Hvn ai
```

could be stable entry points regardless of the implementation.

What I would *not* do is recreate:

```lua
mason-registry.get_package(...)
package:get_installed_version()
package:on(...)
package:install(...)
...
```

as:

```lua
hvn.tools.get_package(...)
hvn.tools.get_installed_version(...)
hvn.tools.on(...)
hvn.tools.install(...)
```

That would be the problematic wrapper I was warning about.

---

## Think of it as a facade

Your architecture could have three layers:

```text
User-facing HVN interface
        ↓
Capability/module interface
        ↓
Provider implementation
```

For example:

```text
:Hvn tools

       ↓

capability: tooling

       ↓

provider: mason.nvim
```

And:

```text
:Hvn git

       ↓

capability: git

       ↓

provider: gitsigns.nvim
```

This is actually a good abstraction because you can potentially change the implementation without changing normal user behavior.

Imagine someday Mason becomes unnecessary because Neovim gets sufficient native package-management capabilities.

You could change:

```text
tooling
  provider = Mason
```

to:

```text
tooling
  provider = native
```

while:

```vim
:Hvn tools
```

continues working.

That's precisely the sort of abstraction your project should provide.

---

## Commands are especially worth abstracting

I think commands are somewhat different from configuration APIs.

Suppose your language module installs:

- Mason
- nvim-lspconfig
- SchemaStore
- conform.nvim
- blink.cmp

You probably don't want the normal user experience to become:

```vim
:Mason
:LspInfo
:ConformInfo
:BlinkCmpStatus
```

or whatever commands each dependency exposes.

That recreates the fragmentation you're trying to solve.

Instead:

```vim
:Hvn language
```

could provide a unified interface:

```text
Language

Lua
  LSP          lua_ls       ✓ running
  Formatter    stylua       ✓ installed
  Parser       lua          ✓ installed

TypeScript
  LSP          vtsls        ✓ running
  Formatter    prettier     ✓ installed
  Parser       typescript   ✓ installed
```

And perhaps:

```vim
:Hvn tools
```

provides:

```text
Development Tools

Installed
  ✓ lua-language-server
  ✓ stylua
  ✓ vtsls
  ✓ prettier

Available
  ○ eslint_d
  ○ pyright
  ...
```

Maybe clicking/selecting one installs it.

At that point Mason has become an **implementation detail**, which is exactly where I think it should be for your default experience.

---

# But keep provider commands available

I wouldn't actively hide Mason either.

If someone knows Mason and wants:

```vim
:Mason
```

it should still work.

So you get two levels:

```text
Normal HVN user:

:Hvn tools


Advanced user:

:Mason
```

That philosophy can apply everywhere.

For example, the normal API might be:

```lua
require("hvn").setup({
  modules = {
    "language",
  },

  language = {
    auto_install = true,
  },
})
```

But advanced configuration could allow:

```lua
require("hvn").setup({
  language = {
    mason = {
      opts = {
        -- raw Mason configuration
      }
    }
  }
})
```

or, perhaps preferably:

```lua
language = {
  providers = {
    tooling = {
      name = "mason",
      opts = {
        ...
      },
    },
  },
}
```

The important thing is that users only encounter `mason` when they **choose to descend into provider-specific configuration**.

---

# This suggests modules may need a UI layer

Your observation actually changes one part of how I'd think about the project.

Initially I described modules primarily as recipes:

```text
module
├── plugins
├── options
├── mappings
└── autocmds
```

I think that's incomplete.

I'd instead make a module something like:

```text
module
├── capabilities
├── dependencies
├── configuration
├── commands
├── keymaps
├── status/introspection
└── providers
```

For example:

```lua
return {
  name = "language",

  provides = {
    "language-intelligence",
    "tool-management",
  },

  commands = {
    tools = ...,
    languages = ...,
  },

  providers = {
    tools = "mason",
    lsp = "native",
  },
}
```

This makes the module feel like an actual **editor feature**, rather than merely a Lua configuration snippet.

And I think that aligns much better with your original motivation.

---

# There's a useful rule here

I'd formulate the abstraction boundary as:

> **If an operation belongs conceptually to an editor capability, HVN should expose it. If it belongs specifically to the implementation plugin, don't duplicate it.**

For Mason:

| Operation | HVN should expose? |
|---|---|
| Open tool manager | **Yes** |
| Install a development tool | **Yes** |
| See installed tools | **Yes** |
| Update tools | **Probably** |
| Check whether language requirements are satisfied | **Definitely** |
| Get Mason registry object | No |
| Subscribe to Mason package events | No |
| Manipulate Mason package objects | No |
| Every Mason configuration option | No |

For gitsigns:

| Operation | HVN should expose? |
|---|---|
| Next/previous change | **Yes** |
| Stage current change | **Yes** |
| Reset current change | **Yes** |
| Toggle blame | **Probably** |
| `gitsigns.get_hunks()` | No need |
| Every sign customization field | No |
| Internal attachment callbacks | No |

That distinction gives you a clean UX without inheriting every dependency's API surface.

---

# This could become one of the project's strongest features

Consider what happens when a user installs:

```lua
modules = {
  "git",
  "language",
  "formatting",
  "completion",
  "typescript",
}
```

Instead of learning commands from five plugins, they get one discoverable namespace:

```vim
:Hvn
```

with completion:

```text
:Hvn git
:Hvn language
:Hvn tools
:Hvn format
:Hvn diagnostics
:Hvn modules
:Hvn health
```

Then:

```vim
:Hvn tools
```

could launch your UI, backed by Mason.

And:

```vim
:Hvn health
```

could say:

```text
typescript
  ✓ LSP provider configured
  ✓ vtsls installed
  ✓ prettier installed
  ✓ treesitter parser installed

lua
  ✓ lua_ls installed
  ✗ stylua missing
      Run :Hvn tools install stylua
```

Now you're not merely reducing configuration. You're giving the Neovim configuration a **coherent control plane**.

I think that's substantially more compelling.

So I would revise my earlier advice slightly: **don't wrap plugin APIs, but absolutely wrap their user-facing functionality when doing so preserves your capability abstraction.** `:Hvn tools` delegating to or replacing `:Mason` is exactly the kind of abstraction I think your framework *should* provide.

## User

What should I call this plugin? Give me plugin name suggestions.

## Assistant

Since the core idea is **building a Neovim config from cohesive capabilities/modules rather than stitching together individual plugins**, I’d favor names that suggest composition, structure, systems, or foundations.

Here are the strongest options I’d consider:

- **plait.nvim** — probably my favorite. “Plait” means to braid/interweave strands, which maps very naturally to composing plugins, options, keymaps, and modules into one coherent config. Short, distinctive, and feels like a real Neovim project name.
- **weave.nvim** — similar idea, but more immediately understandable. “Weave your Neovim config together.” Slightly more generic than Plait.
- **loom.nvim** — the tool that turns threads into something structured. Great metaphor for a framework that composes many pieces into a finished editor.
- **forge.nvim** — suggests constructing your own editor rather than adopting a distro. Strong name, though “forge” is common in developer tooling.
- **frame.nvim** — emphasizes that this is a framework/foundation, not a distro. Very clean, but perhaps too generic.
- **kit.nvim** — “a toolkit for building your Neovim.” Extremely simple and memorable, though probably harder to distinguish/search for.
- **scaffold.nvim** — accurately describes providing structure without dictating the finished configuration. A little long.
- **compose.nvim** — extremely descriptive: compose an editor from modules. The downside is the strong association with Docker Compose.
- **mosaic.nvim** — individual pieces becoming one coherent whole. Nice conceptual fit and visually brandable.
- **facet.nvim** — modules expose different facets of the editor: language, git, formatting, AI, etc. More abstract but elegant.
- **mesh.nvim** — interconnected capabilities/providers. Short and technical.
- **splice.nvim** — joining separate pieces into one system. Has a nice developer-tool feel.
- **stack.nvim** — your editor capability stack. Excellent conceptually but very generic.
- **layer.nvim** — build the editor in layers. Simple, but also generic.
- **modular.nvim** — completely obvious, though less distinctive as a brand.
- **hive.nvim** — many independent units cooperating as one system. Could work well if modules are central.
- **hvn.nvim** — given your existing HVN open-source brand, this could simply become one of the flagship `hvn-oss` projects. The downside is that the name itself communicates nothing about what the plugin does.

### My top 5

I’d rank them:

1. **plait.nvim**
2. **loom.nvim**
3. **weave.nvim**
4. **mosaic.nvim**
5. **forge.nvim**

And **plait.nvim** stands out to me quite a bit.

It captures your architecture unusually well:

```text
plugins ───────┐
options ───────┤
keymaps ───────┤
autocmds ──────┼──► plait.nvim ──► coherent editor
LSP ───────────┤
formatting ────┤
git ───────────┘
```

It also works with the concept of modules:

```lua
require("plait").setup({
  modules = {
    "editor",
    "git",
    "language",
    "formatting",
    "lang.typescript",
  },
})
```

and commands don't look awkward:

```vim
:Plait
:Plait tools
:Plait modules
:Plait health
```

The README tagline practically writes itself:

> **plait.nvim — Build your Neovim config from capabilities, not plugins.**

or:

> **plait.nvim — A modular framework for composing your Neovim configuration.**

There is one thing I’d verify before committing to any of these: **GitHub/Neovim ecosystem name collisions**. In particular, I’d check `plait.nvim`, `loom.nvim`, `weave.nvim`, `mosaic.nvim`, and their non-`.nvim` names across GitHub, LuaRocks, and Neovim plugin indexes before choosing.
