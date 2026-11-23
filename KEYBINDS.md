# Neovim (VS Code Style) Keybind Guide

The **Leader key** is **`Space`** (`<leader>`).  
Press and release `Space`, then press the subsequent keys.

---

## 1. VS Code Muscle Memory

| Action | Neovim Keybind | VS Code Equivalent | Example |
| :--- | :--- | :--- | :--- |
| **Quick Open File** | `<C-p>` (working directory) or `<leader><space>` (project root) | `Ctrl+P` | Press `Ctrl+P`, type `app.py`, hit `Enter`. |
| **Toggle Sidebar / Tree** | `<C-b>` or `<C-n>` or `<leader>e` | `Ctrl+B` | Press `Ctrl+b` to hide or show your project files. |
| **Toggle Terminal** | `<C-\>` or ``<C-`>`` | `Ctrl+`` | Press `Ctrl+\` to open a terminal drawer at the bottom. |
| **Global Text Search** | `<leader>sg` | `Ctrl+Shift+F` | Press `Space s g`, type `import torch`, see all matches across files. |
| **Commands / History** | `<leader>sC` / `<leader>:` | `Ctrl+Shift+P` (commands) | Press `Space s C` to search commands or `Space :` for command history. |
| **Save File** | `<C-s>` or `:w` | `Ctrl+S` | `Space w` opens window shortcuts; it does not save. |

---

## 2. File Explorer (`neo-tree.nvim`)

Open or toggle with `<C-b>`, `<C-n>`, or `<leader>e`. When the tree sidebar is focused:

| Key | What it does | Example |
| :--- | :--- | :--- |
| `Enter` or `l` | Open file or expand folder | Press `Enter` on a folder to expand it. |
| `h` | Collapse folder | Press `h` on an expanded folder to collapse it. |
| `a` | **Add** file or folder | Press `a`, type `src/utils.py` (folders auto-create if needed). |
| `d` | **Delete** file/folder | Press `d`, confirm with `y` to delete. |
| `r` | **Rename** file/folder | Press `r`, edit the name, hit `Enter`. |
| `c` | **Copy** file | Press `c`, enter target destination name. |
| `m` | **Move / Cut** file | Press `m`, enter new directory path. |
| `Y` / `y` | Copy path to system clipboard / copy entry inside Neo-tree | Use `Y` to paste the path outside Neovim. |
| `q` | Close sidebar | Returns focus back to your code. |

---

## 3. Fuzzy Finding & Navigation (`telescope.nvim`)

File names are matched fuzzily and case-insensitively with the native sorter. Live Grep searches file contents as a ripgrep regex using smart case.

All search commands start with `<leader>f` (files) or `<leader>s` (search):

| Keybind | What it searches | Example |
| :--- | :--- | :--- |
| `<leader>ff` | Search files by name | `Space f f` → type `main` → jump directly to `main.cpp`. |
| `<leader>sg` | Search code contents (Live Grep) | `Space s g` → type `def calculate` → find where function is defined or called. |
| `<leader>fb` | Active tabs / buffers | `Space f b` → switch between files currently opened in memory. |
| `<leader>fr` | Recent files | `Space f r` → pick from files you worked on earlier. |
| `<leader>sw` | Search word under cursor | Place cursor on `UserSession`, press `Space s w` to find all occurrences. |

**Inside any Telescope search window:**
- Move up / down: `Ctrl+n` / `Ctrl+p` (or arrow keys).
- Open file: `Enter`.
- Open in horizontal split: `Ctrl+x`.
- Open in vertical split: `Ctrl+v`.
- Close from Insert mode: `Ctrl+c`. From Normal mode: `Esc`.

---

## 4. Code Completion (`blink.cmp`)

The completion menu appears automatically as you type code.

| Key | Action |
| :--- | :--- |
| `Enter` / `<C-y>` | Accept the selected completion / accept the selected or first completion. |
| `<C-n>` / `<C-p>` | Move down / up in the suggestion list. |
| `<Tab>` | Accept the selected suggestion — or the **first** one when none is selected. Inside a snippet: jump forward to the next parameter instead (accepts only a manually selected item). |
| `<S-Tab>` | Jump backward inside snippet parameters. |
| `<C-space>` | Manually trigger the completion popup if closed. |

---

## 5. Code Intelligence & Refactoring (LSP + `mason.nvim`)

| Keybind | What it does | VS Code Equivalent | Example |
| :--- | :--- | :--- | :--- |
| `gd` | **Go to Definition** | `F12` | Put cursor on `MyClass()` and hit `gd` to jump to its source. |
| `gr` | **Find References** | `Shift+F12` | Hit `gr` to open a Telescope list of every place this variable is used. |
| `K` / `gK` | **Hover / Signature Help** (Normal mode) | | Inspect a symbol or a function call. |
| `<C-k>` | **Signature Help** (insert mode) | `Ctrl+Shift+Space` | Shows the overloads/docs of the function being called on demand; the window is capped at 12×70 so it does not cover the code. No auto-popup while typing. |
| `<leader>cr` | **Rename Symbol** | `F2` | Press `Space c r`, type the new variable name, and it updates across files. |
| `<leader>ca` | **Code Actions / Quick Fix** | `Ctrl+.` | Fix imports, auto-apply linter fixes. |
| `<leader>cf` | **Format Code** | `Shift+Alt+F` | C++ uses clangd formatting. |
| `]d` / `[d` | **Next / Previous Warning** | `F8` | Cycle directly to the next syntax error or warning. |

---

## 6. Problems & Diagnostics (`trouble.nvim`)

| Keybind | What it does |
| :--- | :--- |
| `<leader>xx` | Toggle the Problems / Diagnostics list (whole project). |
| `<leader>xX` | Toggle diagnostics for the current file only. |
| `<leader>cs` | Document symbols outline (see classes and functions in current file). |
| `<leader>xL` / `<leader>xQ` | Location list / Quickfix list. |
| `q` | Close the Trouble panel. |

---

## 7. Integrated Terminal (`toggleterm.nvim`)

| Keybind | Mode | Action |
| :--- | :--- | :--- |
| `<C-\>` or ``<C-`>`` | Normal / Insert | Toggle terminal drawer at bottom (size 15 lines). |
| `<C-\>` or ``<C-`>`` | Terminal mode | Hide terminal (process keeps running in background). |
| `<C-\><C-n>` | Plain terminal / CP runner | Leave Terminal mode. In ToggleTerm, `<C-\>` alone toggles the drawer. |

---

## 8. Git Gutters & Diff (`gitsigns.nvim`)

Gutter marks show added, changed, and deleted lines; their colors follow the wallpaper palette.

| Keybind | Action | Example |
| :--- | :--- | :--- |
| `]h` / `[h` | Jump to next / previous git change. | Skip directly between modified sections. |
| `<leader>ghp` | Preview hunk diff inline. | View what was deleted/changed without opening git diff. |
| `<leader>ghs` | Stage current hunk. | Stage just these few lines for commit. |
| `<leader>ghr` | Reset / undo current hunk. | Revert edits on the current block back to git HEAD. |
| `<leader>ghb` / `<leader>gb` | Gitsigns line blame / line history picker. | See who changed a line. |

---

## 9. Competitive programming

Launch Neovim inside `~/Github/CompetitiveProgramming` and click Competitive Companion.
New files open in Insert mode below the comment: type `cp` or `cpt`, then accept the snippet with `Tab`.
`cp` calls `solve()` once; `cpt` reads a test count. Use `i64` for 64-bit integers and `MOD` for the default modulus.

| Key | Action |
| --- | --- |
| `<leader>ct` | Compile with GNU C++20 and run all imported samples. |
| `<leader>cp` | Open or focus the Pretest panel. `Enter` runs the selected case; `q` closes it. |
| `<leader>rr` | Compile with GNU C++20 and run with `input.txt` beside the `.cpp`, or terminal input. The program gets 5 seconds. |
| `:vsplit %:p:h/input.txt` | Open or create the input file beside the current solution. |
| `:CPListen` | Check or restart the Companion listener. |

Pretest supports non-interactive stdin/stdout judging. Local C++/Python sample runs and manual C++ runs have a 1 GiB address-space ceiling; that is not the judge’s RSS limit.
Move or rename CP solutions with `:Pretest move` or `:Pretest rename` so their path-keyed tests follow them.
---

## 10. Editing with mini.surround

| Key | Example |
| --- | --- |
| `gsaiw)` | Wrap the word under the cursor in parentheses. |
| `gsr"'` | Change surrounding double quotes to single quotes. |
| `gsd)` | Delete the surrounding parentheses, keeping the contents. |
| `gsf)` / `gsF)` | Jump to the surrounding parenthesis on the right / left. |

`Ctrl+[` exits Insert mode without reaching for Esc. On a C++ line ending in `{`, `o` opens an indented line below; `O` on `}` opens a line above it.
`yy` and Visual `y` copy to the system clipboard; `d` and `c` leave it alone. `"+p` reads the system clipboard explicitly.

## 11. Split windows and buffers

- **Tab Bar (top of screen):**
  - `<S-h>` or `[b`: Switch to previous file tab.
  - `<S-l>` or `]b`: Switch to next file tab.
  - `<leader>bd`: Close current tab / buffer.
- **Window Navigation (between split panes):**
  - `Ctrl+h`: Focus left window.
  - `Ctrl+j`: Focus bottom window.
  - `Ctrl+k`: Focus top window.
  - `Ctrl+l`: Focus right window.
- **Split Management:**
  - `<leader>-` or `Ctrl+w s`: Split horizontally.
  - `<leader>|` or `Ctrl+w v`: Split vertically.
  - `<leader>wd` or `Ctrl+w c`: Close split window (on the last window it just shows `E444: Cannot close last window` — it never quits nvim).
  - `Ctrl+w o`: Close all other split windows, keep only the current one.
  - `<leader>bd`: Close the file/buffer in the current window while keeping the window layout (`<leader>bo` closes all other buffers).

> **Careful:** `:q` / `:wq` close the window too, but on the *last* window they quit Neovim entirely. Use `<leader>wd` (`Ctrl+w c`) when you only want to close a split.

---

## 12. Zoom (the font is the terminal's job)

Neovim is a TUI — it cannot resize its own font, so kitty does it:

| Keys | Action |
| :--- | :--- |
| `Ctrl+scroll up` / `Ctrl+scroll down` (inside nvim) | Zoom this nvim window in / out |
| `Ctrl+Shift+=` / `Ctrl+Shift+-` | kitty's own zoom in / out (all kitty windows) |
| `Ctrl+Shift+Backspace` | Reset font size |

Ctrl+scroll needs `allow_remote_control socket-only` + `listen_on` in `kitty.conf` (nvim asks kitty to zoom via `kitten @`), so it only works in kitty instances started after that change was added.

> **Tip:** Whenever you forget a keybind, press **`Space`** and pause half a second. **Which-Key** will open an interactive cheatsheet at the bottom showing every available key.
