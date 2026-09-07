DEPS_DIR := deps
MINI_DIR := $(DEPS_DIR)/mini.nvim

.PHONY: install clean test test_file lint typecheck check format format_fix

$(MINI_DIR):
	mkdir -p $(DEPS_DIR)
	git clone --filter=blob:none https://github.com/nvim-mini/mini.nvim $(MINI_DIR)

install: $(MINI_DIR)

test:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

test_file:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

typecheck:
	VIMRUNTIME="$${VIMRUNTIME:-$$(nvim --clean --headless --cmd 'lua io.write(vim.env.VIMRUNTIME)' --cmd 'quit')}" lua-language-server --check "$(PWD)/lua" --checklevel=Warning --configpath="$(PWD)/.luarc.json"
	@echo

lint:
	luacheck lua scripts tests
	@echo

format:
	stylua --color always --respect-ignores --check .
	@echo

format_fix:
	stylua --color always --respect-ignores .
	@echo

check: format lint typecheck test

clean:
	rm -rf $(DEPS_DIR)
