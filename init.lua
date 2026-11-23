-- rice-theme-reload socket
if vim.env.XDG_RUNTIME_DIR and vim.uv.fs_stat(vim.env.XDG_RUNTIME_DIR) then
  pcall(vim.fn.serverstart, vim.env.XDG_RUNTIME_DIR .. ("/nvim.%d.0"):format(vim.fn.getpid()))
end

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Configure LazyVim distro and requested plugins
require("lazy").setup({
  spec = {
    -- LazyVim base distro (includes mason.nvim, nvim-lspconfig, trouble.nvim, gitsigns.nvim)
    {
      "LazyVim/LazyVim",
      import = "lazyvim.plugins",
      opts = {
        colorscheme = "matugen",
      },
    },

    -- Extras: neo-tree, blink.cmp, telescope, luasnip
    { import = "lazyvim.plugins.extras.editor.neo-tree" },
    { import = "lazyvim.plugins.extras.coding.blink" },
    { import = "lazyvim.plugins.extras.editor.telescope" },
    { import = "lazyvim.plugins.extras.coding.luasnip" },

    -- Telescope: LazyVim's extra already sorts with fzf-native (fuzzy),
    -- but its default smart_case makes a query with capitals case-sensitive
    -- ("YPR" won't match HyprlandConfig.lua). fzf-native's extension is loaded
    -- before telescope reads `extensions`, so its setup must be re-run after
    -- setup() for case_mode to take effect.
    {
      "nvim-telescope/telescope.nvim",
      opts = {
        extensions = { fzf = { case_mode = "ignore_case" } },
      },
      config = function(_, opts)
        require("telescope").setup(opts)
        require("telescope").load_extension("fzf")
      end,
    },

    -- noice: its LSP signature help auto-opens on every '(' / ',' while typing
    -- and renders in the docs window (default 20 rows x 120 cols), which covers
    -- the code being written. Keep it on demand (<C-k> / K), but small.
    {
      "folke/noice.nvim",
      opts = {
        lsp = { signature = { auto_open = { enabled = false } } },
        views = { hover = { size = { max_width = 70, max_height = 12 } } },
      },
    },

    -- Integrated terminal (VS Code style toggle)
    {
      "akinsho/toggleterm.nvim",
      version = "*",
      cmd = { "ToggleTerm", "TermExec" },
      opts = {
        open_mapping = [[<c-\>]],
        direction = "horizontal",
        size = 15,
      },
      keys = {
        { [[<c-\>]], "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
        { "<c-`>", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
      },
    },
    {
      "skrewbar/pretest.nvim",
      commit = "73ea1e3c09c66dffec429848e48e1eda8ea00fca",
      cmd = "Pretest",
      opts = function() return require("cp") end,
      keys = {
        { "<leader>cp", "<cmd>Pretest<cr>", desc = "CP Testcase Panel" },
        { "<leader>ct", "<cmd>Pretest run<cr>", desc = "CP Run All Samples" },
      },
    },
    -- CP completion: snippets instant, LSP fires on . -> ::
    {
      "saghen/blink.cmp",
      opts = {
        snippets = { score_offset = 10 },
        sources = {
          default = { "snippets", "lsp", "buffer", "path" },
          min_keyword_length = 0,
          providers = {
            snippets = { min_keyword_length = 1, score_offset = 10 },
            lsp = { min_keyword_length = 0 },
            buffer = { min_keyword_length = 3 },
          },
        },
        completion = {
          trigger = { show_on_trigger_character = true, show_on_keyword = true, show_on_insert_on_trigger_character = true },
          list = { selection = { preselect = false, auto_insert = false } },
          ghost_text = { enabled = false },
          documentation = { auto_show = false },
        },
        signature = { enabled = false },
        keymap = {
          -- Tab accepts the selected item, or the first one if none is selected;
          -- inside a snippet it accepts only an explicitly picked item, else jumps
          ["<Tab>"] = {
            function(cmp)
              if cmp.snippet_active() then return cmp.accept() else return cmp.select_and_accept() end
            end,
            "snippet_forward",
            "fallback",
          },
        },
      },
    },
    {
      "neovim/nvim-lspconfig",
      opts = {
        inlay_hints = { enabled = false },
        servers = {
          clangd = {
            root_markers = { ".git" },
            mason = false,
            cmd = {
              "clangd",
              "--header-insertion=never",
              "--completion-style=bundled",
              "--function-arg-placeholders=false",
            },
          },
        },
      },
    },
  },
  defaults = { lazy = false, version = false },
})

require("cp")

vim.keymap.set("n", "<C-p>", "<cmd>Telescope find_files<cr>", { desc = "Find Files" })
vim.keymap.set("n", "<C-n>", "<cmd>Neotree toggle<cr>", { desc = "Toggle Neo-tree" })
vim.keymap.set("n", "<C-b>", "<cmd>Neotree toggle<cr>", { desc = "Toggle Sidebar" })

-- Ctrl+scroll zoom. nvim is a TUI, it cannot change its own font, so the
-- keymaps ask kitty to zoom the window they run in (`kitten @`), which needs
-- `allow_remote_control socket-only` + `listen_on` in kitty.conf.
local function kitty_zoom(delta)
  if not (vim.env.KITTY_LISTEN_ON and vim.env.KITTY_WINDOW_ID) then
    return -- not running inside kitty (e.g. over ssh)
  end
  pcall(
    vim.system,
    { "kitten", "@", "action", "--self", "change_font_size", "current", delta },
    { stdout = false, stderr = false }
  )
end
for _, mode in ipairs({ "n", "i", "v", "t" }) do
  vim.keymap.set(mode, "<C-ScrollWheelUp>", function() kitty_zoom("+1.0") end, { desc = "Zoom In (kitty font)" })
  vim.keymap.set(mode, "<C-ScrollWheelDown>", function() kitty_zoom("-1.0") end, { desc = "Zoom Out (kitty font)" })
end
