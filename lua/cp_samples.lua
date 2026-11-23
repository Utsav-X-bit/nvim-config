local function same(a, b)
  return a.input == b.input and a.output == b.output
end

-- Save each official case's original bytes separately from the editable Pretest case.
return function(saved, incoming)
  local tests, old = saved.tests or {}, saved.companionSamples or {}
  local originals, used, assigned = {}, {}, {}
  local max_id = 0
  for _, test in ipairs(tests) do
    max_id = math.max(max_id, tonumber(test.id) or 0)
  end
  for _, sample in ipairs(old) do originals[sample.id] = sample end

  local function match(predicate)
    for i, sample in ipairs(incoming) do
      if not assigned[i] then
        for _, test in ipairs(tests) do
          if test.id and not used[test] and predicate(sample, test, originals[test.id]) then
            used[test], assigned[i] = true, test
            break
          end
        end
      end
    end
  end

  -- Match exact official samples before corrections, including repeated stdin.
  match(function(sample, _, original) return original and same(sample, original) end)
  -- Older metadata lacks provenance. Adopt only exact matches; keep other cases.
  if saved.companionSamples == nil then
    match(function(sample, test) return same(sample, test) end)
  end
  match(function(sample, test, original)
    return original and same(test, original) and sample.input == original.input
  end)

  local refreshed = {}
  for i, sample in ipairs(incoming) do
    local test = assigned[i]
    if test then
      local original = originals[test.id]
      if original and same(test, original) then test.input, test.output = sample.input, sample.output end
    else
      max_id = max_id + 1
      test = { id = max_id, input = sample.input, output = sample.output }
      tests[#tests + 1] = test
      used[test] = true
    end
    refreshed[#refreshed + 1] = { id = test.id, input = sample.input, output = sample.output }
  end

  -- An empty parse is not proof the official cases were removed.
  if #incoming == 0 then return tests, old end
  return vim.tbl_filter(function(test)
    local original = test.id and originals[test.id]
    return used[test] or not original or not same(test, original)
  end, tests), refreshed
end
