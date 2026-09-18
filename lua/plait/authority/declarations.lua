return {
  selection = { 'editor', 'language', 'completion', 'formatting', 'tooling', 'lang.lua', 'lang.typescript' },
  module = {
    fields = {
      name = 'string',
      provides = 'string[]',
      requires = 'string[]',
      contribute = 'PlaitContributionDeclarationMap',
    },
  },
  server = {
    fields = { filetypes = 'string[]', tool = 'string' },
    nonempty = { 'filetypes', 'tool' },
    unique = { 'filetypes' },
  },
  formatter = { fields = { tool = 'string' }, nonempty = { 'tool' } },
  tool = {
    fields = {
      executable = 'string',
      version = 'string',
      ownership = 'PlaitOwnership',
      workspace_paths = 'string[]',
      mason = 'string',
    },
    optional = { 'workspace_paths', 'mason' },
  },
  providers = {
    language = { ['vim.lsp'] = { global = true, servers = 'dynamic' } },
    completion = { ['blink.cmp'] = { setup = true } },
    formatting = { ['conform.nvim'] = { setup = true, formatters = 'dynamic' } },
    tooling = { ['mason.nvim'] = { setup = true } },
  },
  override = { language = { 'servers' }, formatting = { 'formatters', 'by_filetype' }, tooling = { 'tools' } },
  records = {
    PlaitProviderDeclarations = {
      fields = {
        language = 'PlaitLanguageProviders',
        completion = 'PlaitCompletionProviders',
        formatting = 'PlaitFormattingProviders',
        tooling = 'PlaitToolingProviders',
      },
      optional = { 'language', 'completion', 'formatting', 'tooling' },
    },
    PlaitLanguageProviders = { fields = { ['vim.lsp'] = 'PlaitLspTargets' }, optional = { 'vim.lsp' } },
    PlaitLspTargets = {
      fields = { global = 'table', servers = 'table<string, table>' },
      optional = { 'global', 'servers' },
    },
    PlaitCompletionProviders = { fields = { ['blink.cmp'] = 'PlaitSetupTarget' }, optional = { 'blink.cmp' } },
    PlaitFormattingProviders = {
      fields = { ['conform.nvim'] = 'PlaitFormatterTargets' },
      optional = { 'conform.nvim' },
    },
    PlaitToolingProviders = { fields = { ['mason.nvim'] = 'PlaitSetupTarget' }, optional = { 'mason.nvim' } },
    PlaitSetupTarget = { fields = { setup = 'table' }, optional = { 'setup' } },
    PlaitFormatterTargets = {
      fields = { setup = 'table', formatters = 'table<string, table>' },
      optional = { 'setup', 'formatters' },
    },
    PlaitContributionDeclarationMap = {
      fields = {
        language = 'PlaitLanguageContributions',
        formatting = 'PlaitFormattingContributions',
        tooling = 'PlaitToolingContributions',
      },
      optional = { 'language', 'formatting', 'tooling' },
    },
    PlaitLanguageContributions = {
      fields = { servers = 'table<string, PlaitServerDeclaration>' },
      optional = { 'servers' },
    },
    PlaitFormattingContributions = {
      fields = { formatters = 'table<string, PlaitFormatterDeclaration>', by_filetype = 'table<string, string[]>' },
      optional = { 'formatters', 'by_filetype' },
    },
    PlaitToolingContributions = { fields = { tools = 'table<string, PlaitToolDeclaration>' }, optional = { 'tools' } },
    PlaitOverrides = {
      fields = {
        language = 'PlaitLanguageOverrides',
        formatting = 'PlaitFormattingOverrides',
        tooling = 'PlaitToolingOverrides',
      },
      optional = { 'language', 'formatting', 'tooling' },
    },
    PlaitLanguageOverrides = {
      fields = { servers = 'table<string, PlaitOverrideOperation>' },
      optional = { 'servers' },
    },
    PlaitFormattingOverrides = {
      fields = {
        formatters = 'table<string, PlaitOverrideOperation>',
        by_filetype = 'table<string, PlaitOverrideOperation>',
      },
      optional = { 'formatters', 'by_filetype' },
    },
    PlaitToolingOverrides = { fields = { tools = 'table<string, PlaitOverrideOperation>' }, optional = { 'tools' } },
  },
}
