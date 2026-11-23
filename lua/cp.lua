local root = vim.fs.normalize(vim.env.HOME .. "/Github/CompetitiveProgramming")
root = vim.uv.fs_realpath(root) or root
local compiler = { "g++", "-std=gnu++20", "-O2", "-Wall", "-Wextra" }
-- A local safety ceiling, not a replacement for the judge's RSS limit.
local memory_cap = "--as=1073741824"
local merge_samples = require("cp_samples")
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
  local saved = stat and vim.json.decode(table.concat(vim.fn.readfile(metadata), "\n")) or {}
  local ui = package.loaded["pretest.ui"]
  local session = ui and ui.get_session()
  if session and session.src_path ~= path then session = nil end
  local current = session and session.problem.tests[session.index]
  if current then
    -- Apply only dirty editor fields to the latest disk state; flush_edits writes the entire cache.
    local edit
    for field, buf in pairs({ input = session.bufs.input, output = session.bufs.expected }) do
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
        if not edit then
          saved.tests = saved.tests or {}
          for _, test in ipairs(saved.tests) do
            if test.id == current.id then edit = test; break end
          end
          if not edit then
            edit = vim.deepcopy(current)
            table.insert(saved.tests, edit)
          end
        end
        edit[field] = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      end
    end
  end
  local tests, originals = merge_samples(saved, task.tests)
  local problem = vim.tbl_extend("force", saved, task, {
    srcPath = path, tests = tests, companionSamples = originals, ["local"] = false,
  })
  save_metadata(metadata, problem)
  if session then
    local index = #tests > 0 and 1 or 0
    if current then
      for i, test in ipairs(tests) do
        if test.id == current.id then index = i; break end
      end
    end
    local previous = session.problem
    local changed = not vim.deep_equal(previous.tests, tests) or previous.name ~= problem.name
      or previous.timeLimit ~= problem.timeLimit or previous.memoryLimit ~= problem.memoryLimit
    if changed then require("pretest.runner").stop(path) end
    if ui.is_open() and changed then
      local win = vim.api.nvim_get_current_win()
      ui.apply_problem(path, problem)
      if index > 1 then ui.goto_case(index) end
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win) end
    else
      session.problem, session.prob_path, session.index = problem, metadata, index
      if changed then
        session.results = {}
        session.compile_stderr, session.compile_status = "", nil
        for field, buf in pairs({ input = session.bufs.input, output = session.bufs.expected }) do
          local value = tests[index] and tests[index][field] or ""
          vim.bo[buf].modifiable = true
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(value, "\n", { plain = true }))
          vim.bo[buf].modified = false
        end
      end
    end
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
    on_stdout = function(channel, lines)
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
          if message.id then
            vim.fn.chansend(channel, vim.json.encode({ id = message.id, error = not ok and tostring(err) or nil }) .. "\n")
          elseif not ok then
            vim.notify(err, vim.log.levels.ERROR, { title = "Competitive Companion" })
          end
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
    output=$1; limit=$2; shift 2
    "$@" || exit $?
    if [ -f input.txt ]; then exec < input.txt; fi
    timeout --foreground -k 1s 5s prlimit "$limit" -- "$output"
    status=$?
    if [ "$status" = 124 ]; then printf '\nCP: stopped after the 5-second run limit.\n' >&2; fi
    exit "$status"
  ]], "cp-run", output, memory_cap }, compiler)
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
    cpp = {
      compile = { exec = compiler[1], args = vim.list_extend(vim.list_slice(compiler, 2), { "$src", "-o", "$bin" }) },
      run = { exec = "prlimit", args = { memory_cap, "--", "$bin" } },
    },
    python = { run = { exec = "prlimit", args = { memory_cap, "--", "python3", "$src" } } },
  },
}
