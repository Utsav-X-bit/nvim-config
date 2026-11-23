local root = vim.fs.normalize(vim.env.HOME .. "/Github/CompetitiveProgramming")
root = vim.uv.fs_realpath(root) or root
local compiler = { "g++", "-std=gnu++20", "-O2", "-Wall", "-Wextra" }
local job, ready, attempted

local function save_metadata(path, problem)
  local json = vim.json.encode(problem)
  local fd, temp = vim.uv.fs_mkstemp(path .. ".XXXXXX")
  if not fd then error(temp) end
  local written, write_error = vim.uv.fs_write(fd, json)
  local closed, close_error = vim.uv.fs_close(fd)
  if written == #json and closed then
    local renamed, rename_error = vim.uv.fs_rename(temp, path)
    if renamed then return end
    write_error = rename_error
  end
  vim.uv.fs_unlink(temp)
  error(write_error or close_error or "Incomplete write to " .. path)
end

local function open_solution(path)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 then
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if vim.api.nvim_win_get_config(win).relative == "" then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end

  local function can_edit(win)
    local options = vim.bo[vim.api.nvim_win_get_buf(win)]
    return options.buftype == "" and not options.modified and not vim.wo[win].winfixbuf
      and vim.api.nvim_win_get_config(win).relative == ""
  end

  local win = vim.api.nvim_get_current_win()
  if not can_edit(win) then
    win = nil
    for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if can_edit(candidate) then
        win = candidate
        break
      end
    end
  end
  if win then
    vim.api.nvim_set_current_win(win)
    if buf ~= -1 then
      vim.cmd.buffer(buf)
    else
      vim.cmd.edit({ args = { path } })
    end
  elseif buf ~= -1 then
    vim.cmd.sbuffer({ args = { tostring(buf) }, mods = { tab = vim.fn.tabpagenr() } })
  else
    vim.cmd.tabedit({ args = { path } })
  end
end

local function import_problem(message)
  local path, metadata, task = message.path, message.metadata, message.task
  local stat = vim.uv.fs_lstat(metadata)
  if stat and stat.type ~= "file" then error("Not a regular file: " .. metadata) end
  -- Pretest keeps the current problem in memory and flushes it on buffer switches.
  local ui = package.loaded["pretest.ui"]
  local session = ui and ui.get_session()
  local active = session and session.src_path == path
  if active then
    for _, buffer in ipairs({ session.bufs.input, session.bufs.expected }) do
      if vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].modified then
        ui.flush_edits()
        stat = vim.uv.fs_lstat(metadata)
        break
      end
    end
  end
  local saved = stat and vim.json.decode(table.concat(vim.fn.readfile(metadata), "\n")) or {}
  local tests, inputs, id = saved.tests or {}, {}, 0
  for _, test in ipairs(tests) do
    inputs[test.input] = true
    id = math.max(id, tonumber(test.id) or 0)
  end
  for _, test in ipairs(task.tests) do
    if not inputs[test.input] then
      id = id + 1
      table.insert(tests, { id = id, input = test.input, output = test.output })
      inputs[test.input] = true
    end
  end
  local problem = vim.tbl_extend("force", saved, task, { srcPath = path, tests = tests, ["local"] = false })
  if active then
    ui.apply_problem(path, problem)
  else
    save_metadata(metadata, problem)
  end
  if message.open then
    open_solution(path)
    if message.created then
      vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(0), 0 })
      vim.cmd.startinsert()
    end
  end
end

local function listen(manual)
  if job then
    if manual then
      vim.notify(ready and "Competitive Companion listening on port 27121" or "Competitive Companion starting")
    end
    return
  end
  attempted = true
  local partial = ""
  local script = vim.fn.stdpath("config") .. "/companion.mjs"
  local id = vim.fn.jobstart({ "node", script, root }, {
    on_stdout = function(_, lines)
      lines[1] = partial .. lines[1]
      partial = table.remove(lines)
      for _, line in ipairs(lines) do
        local message = vim.json.decode(line)
        if message.event == "ready" then
          ready = true
          if manual then vim.notify("Competitive Companion listening on port 27121") end
        elseif message.event == "error" then
          vim.notify(message.message, vim.log.levels.ERROR, { title = "Competitive Companion" })
        elseif message.event == "import" then
          local ok, err = pcall(import_problem, message)
          if not ok then vim.notify(err, vim.log.levels.ERROR, { title = "Competitive Companion" }) end
        end
      end
    end,
    stderr_buffered = true,
    on_stderr = function(_, lines)
      local message = vim.trim(table.concat(lines, "\n"))
      if message ~= "" then vim.notify(message, vim.log.levels.ERROR, { title = "Competitive Companion" }) end
    end,
    on_exit = function()
      job, ready = nil, false
    end,
  })
  if id > 0 then
    job = id
  else
    vim.notify("Could not start Competitive Companion listener (requires Node.js)", vim.log.levels.ERROR)
  end
end

vim.api.nvim_create_user_command("CPListen", function() listen(true) end, {})
local function in_workspace(path)
  path = vim.uv.fs_realpath(path) or path
  return path == root or vim.startswith(path, root .. "/")
end

vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter", "DirChanged" }, {
  group = vim.api.nvim_create_augroup("CompetitiveProgramming", { clear = true }),
  callback = function(ev)
    if attempted then return end
    if in_workspace(vim.fn.getcwd()) or in_workspace(vim.api.nvim_buf_get_name(ev.buf)) then
      listen(false)
    elseif ev.event == "VimEnter" then
      -- Neo-tree can replace the launch directory buffer before VimEnter.
      for _, arg in ipairs(vim.fn.argv()) do
        if in_workspace(vim.fn.fnamemodify(arg, ":p")) then
          listen(false)
          break
        end
      end
    end
  end,
})

vim.keymap.set("n", "<leader>rr", function()
  local file = vim.api.nvim_buf_get_name(0)
  if vim.bo.filetype ~= "cpp" or file == "" then
    vim.notify("Open a C++ file first", vim.log.levels.WARN)
    return
  end
  vim.cmd.update()
  local output = vim.fn.tempname()
  local dir = vim.fs.dirname(file)
  local command = vim.list_extend({ "sh", "-c", [[
    output=$1; shift
    "$@" && if [ -f input.txt ]; then "$output" < input.txt; else "$output"; fi
  ]], "cp-run", output }, compiler)
  vim.list_extend(command, { file, "-o", output })
  vim.cmd("botright 12new")
  vim.bo.bufhidden = "wipe"
  vim.fn.jobstart(command, {
    cwd = dir,
    term = true,
    on_exit = function() vim.uv.fs_unlink(output) end,
  })
  vim.cmd.startinsert()
end, { desc = "Compile & Run C++" })

return {
  save_dir = root .. "/.cph",
  languages = {
    cpp = { compile = { exec = compiler[1], args = vim.list_extend(vim.list_slice(compiler, 2), { "$src", "-o", "$bin" }) } },
  },
}
