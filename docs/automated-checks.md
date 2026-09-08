# Automated Checks

Run the repository check from the repository root:

```sh
make check
```

This checks formatting, lint, LuaLS types, generated schema artifacts, and the full test suite in
headless Neovim.

During development, run the focused effective-plan and validation tests:

```sh
make test_file FILE=tests/test_plait.lua
make test_file FILE=tests/test_validation.lua
```

After changing `lua/plait/schema.lua`, regenerate runtime metadata, LuaLS annotations, and reference
facts:

```sh
make schema_generate
```

Use the non-mutating consistency check in automation:

```sh
make schema_check
```
