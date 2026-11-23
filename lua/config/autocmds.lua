-- Copy ordinary yanks to the system clipboard without syncing deletes or changes.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("SystemClipboardYank", { clear = true }),
  callback = function()
    local event = vim.v.event
    if event.operator == "y" and event.regname == "" and vim.fn.has("clipboard") == 1 then
      vim.fn.setreg("+", event.regcontents, event.regtype)
    end
  end,
})
