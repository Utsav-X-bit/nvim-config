# Neovim config

A LazyVim setup for general coding and competitive programming. It includes Telescope, Neo-tree, Blink completion, LuaSnip, clangd, C++ Tree-sitter, ToggleTerm, and mini.surround. Plugin revisions are recorded in [`lazy-lock.json`](lazy-lock.json).

## Try it without replacing your config

Use Neovim **0.12+** with LuaJIT and Git **2.19+**. Install `ripgrep` for project search, `fd` for file discovery, and `curl`, `tar`, and the `tree-sitter` CLI **0.26.1+** for parser installation. A C compiler and `make` are needed for native builds. The first launch needs internet access to install plugins and parsers.

```sh
git clone https://github.com/Utsav-X-bit/nvim-config.git "${XDG_CONFIG_HOME:-$HOME/.config}/nvim-config"
NVIM_APPNAME=nvim-config nvim
```

`NVIM_APPNAME` keeps this profile’s config, plugins, and state separate from your normal Neovim profile. If you want to make it your default later, back up your existing `nvim` config directory first, then clone into `${XDG_CONFIG_HOME:-$HOME/.config}/nvim` instead. Launch with plain `nvim` for that profile.

The Matugen wallpaper palette is optional and is not included. On machines without it, the editor uses Neovim’s built-in Habamax theme. Kitty font zoom is optional as well.

## Competitive programming on Linux

Install Node.js 20+, `g++`, `clangd`, GNU `timeout`, and util-linux `prlimit`. For browser imports, install the [Competitive Companion extension](https://github.com/jmerle/competitive-companion#install).

```sh
mkdir -p ~/Github/CompetitiveProgramming
cd ~/Github/CompetitiveProgramming
NVIM_APPNAME=nvim-config nvim
```

Click Competitive Companion on a problem or contest page. Imports go under `contest/` or `practice/`; tests are saved in `.cph/`. A new file opens below its problem comment in Insert mode: type `cp` for a single-case template or `cpt` for a test-count loop, then press `Tab` to complete the snippet. Only one editor can listen on port `27121` at a time; run `:CPListen` to check the listener.

| Keys | Action |
| --- | --- |
| `Space c t` | Compile with GNU C++20 and run all samples in Pretest. |
| `Space c p` | Open or focus the testcase panel. |
| `Space r r` | Compile and run with `input.txt` beside the source, or use terminal input. |
| `gsaiw)` | Wrap the word under the cursor in parentheses. |

See the [keybind guide](KEYBINDS.md) for search, Git, window, terminal, and editing shortcuts.
