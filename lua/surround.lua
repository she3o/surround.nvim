--- a ux for surrounding character pairs
-- @module surround

local parser = require "parser"
local utils = require "utils"

local OPENING = 1
local CLOSING = 2
local LINE = 1
local COLUMN = 2

--- Surround Visual Selection.
-- Adds a character surrounding the users visual selection
-- @param char The character to surround with
local function surround_add(char)
  local cursor_position = vim.api.nvim_win_get_cursor(0)
  local mode = vim.api.nvim_get_mode()["mode"]

  -- Get context
  local start_line, start_col, end_line, end_col = utils.get_visual_pos()
  local context = vim.api.nvim_call_function("getline", {start_line, end_line})

  -- Get the pair to add
  local surround_pairs = vim.g.surround_pairs
  local all_pairs = table.merge(surround_pairs.nestable, surround_pairs.linear)
  local char_pairs
  for _, pair in ipairs(all_pairs) do
    if table.contains(pair, char) then
      char_pairs = pair
      break
    end
  end

  -- Add surrounding characters
  if (char == "f") then
    -- Handle Functions
    local func_name = utils.user_input("funcname: ")
    if mode == "v" then
      -- Visual Mode
      if #context == 1 then
        -- Handle single line
        local line = context[1]
        line = string.insert(line, start_col, func_name .. "(")
        line = string.insert(line, end_col + #func_name + 1, ")")
        context[1] = line
      else
        -- Handle multiple lines
        local first_line = context[1]
        local last_line = context[#context]
        first_line = string.insert(first_line, start_col, func_name .. "(")
        last_line = string.insert(last_line, end_col + 1, ")")
        context[1] = first_line
        context[#context] = last_line
      end
    end
  else
    if mode == "v" then
      -- Visual Mode
      if #context == 1 then
        -- Handle single line
        local line = context[1]
        line = string.insert(line, start_col, char_pairs[1])
        line = string.insert(line, end_col + 1, char_pairs[2])
        context[1] = line
      else
        -- Handle multiple lines
        local first_line = context[1]
        local last_line = context[#context]
        first_line = string.insert(first_line, start_col, char_pairs[1])
        last_line = string.insert(last_line, end_col + 1, char_pairs[2])
        context[1] = first_line
        context[#context] = last_line
      end
    elseif mode == "V" then
      -- Visual Line Mode
      if #context == 1 then
        -- Handle single line
        local line = context[1]
        local index = 1
        for i = 1, #line do
          local current_char = line:sub(i, i)
          if (current_char ~= " " and current_char ~= "\t") then
            index = i
            break
          end
        end
        line = string.insert(line, index, char_pairs[1])
        line = string.insert(line, #line + 1, char_pairs[2])
        context[1] = line
      else
        -- Handle multiple lines
        local first_line = context[1]
        local last_line = context[#context]

        local index = 1
        -- Skip Leading Spaces and Tabs
        for i = 1, #first_line do
          local current_char = first_line:sub(i, i)
          if (current_char ~= " " and current_char ~= "\t") then
            index = i
            break
          end
        end

        -- Insert the characters
        first_line = string.insert(first_line, index, char_pairs[1])
        last_line = string.insert(last_line, #last_line + 1, char_pairs[2])
        context[1] = first_line
        context[#context] = last_line
      end
    end
  end

  -- Replace buffer with added characters
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, true, context)

  -- Get out of visual mode
  local key = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
  vim.api.nvim_feedkeys(key, "v", true)

  -- Reset Cursor Position
  -- vim.api.nvim_win_set_cursor(0, cursor_position)

  -- Feedback
  print("Added surrounding ", char)

  -- Set Last CMD
  vim.g.surround_last_cmd = {"surround_add", {char}}
end

local function surround_delete(char)
  local cursor_position = vim.api.nvim_win_get_cursor(0)
  local start_line, end_line
  local top_offset = 0
  local surround_pairs = vim.g.surround_pairs
  local context

  -- Get context
  if table.contains(vim.tbl_flatten(surround_pairs.linear), char) then
    start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(0)
  elseif char == "f" then
    start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(0)
  else
    start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(vim.g.surround_context_offset)
  end
  context = vim.api.nvim_call_function("getline", {start_line, end_line})
  local cursor_position_relative = cursor_position
  cursor_position_relative[LINE] = cursor_position[LINE] - top_offset
  cursor_position_relative[COLUMN] = cursor_position[COLUMN] + 1 -- vim indexes columns at 0

  -- Find the surrounding pair
  local indexes
  if char == "f" then
    indexes = parser.get_surround_pair(context, cursor_position_relative, char, {"_", "."})
  else
    indexes = parser.get_surround_pair(context, cursor_position_relative, char)
  end

  -- If no surrounding pairs found bail out
  if not indexes then
    return
  end

  if (char == "f") then
    -- Handle functions
    context[indexes[OPENING][LINE]] =
      string.remove(context[indexes[OPENING][LINE]], indexes[1][COLUMN], indexes[2][COLUMN] + 1)
    context[indexes[3][LINE]] =
      string.remove(context[indexes[3][LINE]], indexes[3][COLUMN] - (indexes[2][COLUMN] - indexes[1][COLUMN]) - 1)
  else
    -- local ns_id =
    -- vim.api.nvim_buf_add_highlight(0, vim.api.nvim_create_namespace("surround.nvim"), "SurroundFeedback", 1, 1, -1)

    -- Remove surrounding character  matches
    context[indexes[OPENING][LINE]] = string.remove(context[indexes[OPENING][LINE]], indexes[OPENING][COLUMN])
    context[indexes[CLOSING][LINE]] = string.remove(context[indexes[CLOSING][LINE]], indexes[CLOSING][COLUMN] - 1)
  end

  -- Replace Buffer
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, true, context)

  -- Reset Cursor Position
  -- vim.api.nvim_win_set_cursor(0, cursor_position)

  -- Feedback
  print("Deleted surrounding ", char)

  -- Set Last CMD
  vim.g.surround_last_cmd = {"surround_delete", {char}}
end

local function surround_replace(char_1, char_2, is_toggle, start_line, end_line, cursor_index, context)
  local cursor_position = vim.api.nvim_win_get_cursor(0)
  local surround_pairs = vim.g.surround_pairs
  local top_offset = 0

  -- Get context
  if table.contains(vim.tbl_flatten(surround_pairs.linear), char_1) then
    start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(0)
  elseif char_1 == "f" then
    start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(0)
  else
    start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(vim.g.surround_context_offset)
  end
  context = vim.api.nvim_call_function("getline", {start_line, end_line})
  local cursor_position_relative = cursor_position
  cursor_position_relative[LINE] = cursor_position[LINE] - top_offset
  cursor_position_relative[COLUMN] = cursor_position[COLUMN] + 1 -- vim indexes columns at 0

  -- Replace surrounding pairs
  if char_1 == "f" and char_2 == "f" then
    local indexes = parser.get_surround_pair(context, cursor_position_relative, char_1, {"_"})

    -- Bail out if no surrounding function found.
    if not indexes then
      print("No surrounding function found")
      return
    end

    -- Get new funcname
    local func_name = utils.user_input("funcname: ")

    -- Replace functions
    context[indexes[OPENING][LINE]] =
      string.remove(context[indexes[OPENING][LINE]], indexes[1][COLUMN], indexes[2][COLUMN])
    context[indexes[OPENING][LINE]] = string.insert(context[indexes[OPENING][LINE]], indexes[1][COLUMN], func_name)
  elseif char_1 == "f" then
    local indexes = parser.get_surround_pair(context, cursor_position_relative, char_1, {"_"})

    -- Bail out if no surrounding function found.
    if not indexes then
      print("No surrounding function found")
      return
    end

    -- Get the pair to replace with
    local all_pairs = table.merge(surround_pairs.nestable, surround_pairs.linear)
    local char_2_pairs
    for _, pair in ipairs(all_pairs) do
      if table.contains(pair, char_2) then
        char_2_pairs = pair
        break
      end
    end

    -- Replace surrounding brackets with char_2 and remove function
    context = string.set(context, indexes[2], char_2_pairs[1])
    context = string.set(context, indexes[3], char_2_pairs[2])
    context = string.remove(context, indexes[1], indexes[2])
  elseif char_2 == "f" then
    local indexes = parser.get_surround_pair(context, cursor_position_relative, char_1)

    -- Bail out if no surrounding pairs found.
    if not indexes then
      print("No surrounding " .. char_1 .. " found")
      return
    end

    -- Get new funcname
    local func_name = utils.user_input("funcname: ")
    context[indexes[OPENING][LINE]] = string.set(context[indexes[OPENING][LINE]], indexes[OPENING][COLUMN], "(")
    context[indexes[CLOSING][LINE]] = string.set(context[indexes[CLOSING][LINE]], indexes[CLOSING][COLUMN], ")")
    context[indexes[OPENING][LINE]] =
      string.insert(context[indexes[OPENING][LINE]], indexes[OPENING][COLUMN], func_name)
  else
    local indexes = parser.get_surround_pair(context, cursor_position_relative, char_1)

    -- Bail out if no surrounding pairs found.
    if not indexes then
      print("No surrounding " .. char_1 .. " found")
      return
    end

    -- Get the pair to replace with
    local all_pairs = table.merge(surround_pairs.nestable, surround_pairs.linear)
    local char_2_pairs
    for _, pair in ipairs(all_pairs) do
      if table.contains(pair, char_2) then
        char_2_pairs = pair
        break
      end
    end
    -- Replace char_1 with char_2
    context[indexes[OPENING][LINE]] =
      string.set(context[indexes[OPENING][LINE]], indexes[OPENING][COLUMN], char_2_pairs[OPENING])
    context[indexes[CLOSING][LINE]] =
      string.set(context[indexes[CLOSING][LINE]], indexes[CLOSING][COLUMN], char_2_pairs[CLOSING])
  end

  -- Replace buffer
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, true, context)

  -- Reset cursor position
  -- vim.api.nvim_win_set_cursor(0, cursor_position)

  -- Feedback
  print("Replaced ", char_1, " with ", char_2)

  -- Set last_cmd if not a toggle triggered the function
  if not is_toggle then
    vim.g.surround_last_cmd = {"surround_replace", {char_1}, {char_2}}
  end
end

local function toggle_quotes()
  local cursor_position = vim.api.nvim_win_get_cursor(0)
  local start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(0)
  local context = vim.api.nvim_call_function("getline", {start_line, end_line})
  local cursor_position_relative = cursor_position
  cursor_position_relative[LINE] = cursor_position[LINE] - top_offset
  cursor_position_relative[COLUMN] = cursor_position[COLUMN] + 1 -- vim indexes columns at 0

  local index
  local _pairs = vim.b.surround_quotes or vim.g.surround_quotes
  for i, pair in ipairs(_pairs) do
    index = parser.get_surround_pair(context, cursor_position_relative, pair)
    if index then
      if i == #_pairs then
        surround_replace(_pairs[i], _pairs[1], true, start_line, end_line, cursor_position_relative, context)
      else
        surround_replace(_pairs[i], _pairs[i + 1], true, start_line, end_line, cursor_position_relative, context)
      end
      vim.g.surround_last_cmd = {"toggle_quotes", {}}
      return
    end
  end
end

local function toggle_brackets()
  local cursor_position = vim.api.nvim_win_get_cursor(0)
  local start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(vim.g.surround_context_offset)
  local context = vim.api.nvim_call_function("getline", {start_line, end_line})
  local cursor_position_relative = cursor_position
  cursor_position_relative[LINE] = cursor_position[LINE] - top_offset
  cursor_position_relative[COLUMN] = cursor_position[COLUMN] + 1 -- vim indexes columns at 0

  local _pairs = vim.b.surround_brackets or vim.g.surround_brackets
  local indexes = {}
  for i, pair in ipairs(_pairs) do
    indexes[i] = parser.get_surround_pair(context, cursor_position_relative, pair)
    if indexes[i] then
      indexes[i] = indexes[i][OPENING]
    else
      indexes[i] = {-1, -1}
    end
  end

  local index = {-1, -1}
  for _, opening_indexes in ipairs(indexes) do
    if opening_indexes[LINE] > index[LINE] then
      if opening_indexes[COLUMN] > index[COLUMN] then
        index = opening_indexes
      end
    end
  end

  if (index[LINE] < 0) then
    return
  end

  for i, val in ipairs(indexes) do
    if index == val then
      if i < #_pairs then
        surround_replace(_pairs[i], _pairs[i + 1], true, start_line, end_line, cursor_position_relative, context)
      else
        surround_replace(_pairs[i], _pairs[1], true, start_line, end_line, cursor_position_relative, context)
      end
      vim.g.surround_last_cmd = {"toggle_brackets", {}}
      return
    end
  end
end

local function repeat_last()
  local cmd = vim.g.surround_last_cmd
  if not cmd then
    print("No previous surround command found.")
    return
  end
  for i = 1, #cmd[2] do
    cmd[2][i] = utils.quote(cmd[2][i])
  end
  vim.cmd("lua surround." .. cmd[1] .. "(" .. utils.get(unpack(cmd[2]), "") .. ")")
end

local function set_keymaps()
  local map_keys = {
    b = "(",
    B = "{",
    f = "f"
  }
  local all_pairs = table.merge(vim.g.surround_pairs.nestable, vim.g.surround_pairs.linear)
  for _, pair in ipairs(all_pairs) do
    map_keys[pair[1]] = pair[2]
    map_keys[pair[2]] = pair[2]
  end
  local keys = {}
  -- Special Maps
  table.insert(keys, {"n", "stq", "<cmd>lua surround.toggle_quotes()<cr>", {noremap = true}})
  table.insert(keys, {"n", "stb", "<cmd>lua surround.toggle_brackets()<cr>", {noremap = true}})
  table.insert(keys, {"n", "stB", "<cmd>lua surround.toggle_brackets()<cr>", {noremap = true}})
  table.insert(keys, {"n", "ss", "<cmd>lua surround.repeat_last()<cr>", {noremap = true}})
  -- Surround Add
  for key, val in pairs(map_keys) do
    -- Handle different quotes
    if key == '"' then
      table.insert(keys, {"v", "s" .. key, "gv<cmd>lua surround.surround_add('" .. val .. "')<cr>", {noremap = true}})
    else
      table.insert(keys, {"v", "s" .. key, 'gv<cmd>lua surround.surround_add("' .. val .. '")<cr>', {noremap = true}})
    end
    -- Surround Delete
    -- Handle different quotes
    if key == '"' then
      table.insert(keys, {"n", "sd" .. key, "<cmd>lua surround.surround_delete('" .. val .. "')<cr>", {noremap = true}})
    else
      table.insert(keys, {"n", "sd" .. key, '<cmd>lua surround.surround_delete("' .. val .. '")<cr>', {noremap = true}})
    end
    -- Surround Replace
    for key_2, val_2 in pairs(map_keys) do
      -- Handle different quotes
      if key == '"' then
        table.insert(
          keys,
          {
            "n", -- Normal Mode
            "sr" .. key .. key_2, -- LHS
            "<cmd>lua surround.surround_replace('" .. val .. '\',"' .. val_2 .. '")<cr>', -- RHS
            {noremap = true} -- Options
          }
        )
      elseif key_2 == '"' then
        table.insert(
          keys,
          {
            "n", -- Normal Mode
            "sr" .. key .. key_2, -- LHS
            '<cmd>lua surround.surround_replace("' .. val .. '",\'' .. val_2 .. "')<cr>", -- RHS
            {noremap = true} -- Options
          }
        )
      else
        table.insert(
          keys,
          {
            "n", -- Normal Mode
            "sr" .. key .. key_2, -- LHS
            "<cmd>lua surround.surround_replace('" .. val .. '\',"' .. val_2 .. '")<cr>', -- RHS
            {noremap = true} -- Options
          }
        )
      end
    end
  end
  utils.load_keymaps(keys)
end

local function load_autogroups(augroups)
  for group_name, group in pairs(augroups) do
    vim.cmd("augroup " .. group_name)
    vim.cmd("autocmd!")
    for _, cmd in ipairs(group) do
      vim.cmd(table.concat(vim.tbl_flatten {"autocmd", cmd}, " "))
    end
    vim.cmd("augroup END")
  end
end

local function setup(opts)
  local function set_default(opt, default)
    if vim.g["surround_" .. opt] ~= nil then
      return
    elseif opts[opt] ~= nil then
      vim.g["surround_" .. opt] = opts[opt]
    else
      vim.g["surround_" .. opt] = default
    end
  end
  vim.cmd("highlight SurroundFeedback cterm=reverse gui=reverse")
  set_default(
    "pairs",
    {
      nestable = {
        {"(", ")"},
        {"[", "]"},
        {"{", "}"}
      },
      linear = {
        {"'", "'"},
        {"`", "`"},
        {'"', '"'}
      }
    }
  )
  set_default("load_autogroups", false)
  if vim.g.surround_load_autogroups then
    load_autogroups {
      surround_nvim = {
        {"FileType", "javascript,typescript", 'let b:surround_quotes = ["\'", \'"\', "`"]'}
      }
    }
  end
  set_default("context_offset", 100)
  set_default("quotes", {"'", '"'})
  set_default("brackets", {"(", "{", "["})
  set_default("load_keymaps", true)
  if vim.g.surround_load_keymaps then
    set_keymaps()
  end
end

return {
  setup = setup,
  surround_delete = surround_delete,
  surround_replace = surround_replace,
  surround_add = surround_add,
  toggle_quotes = toggle_quotes,
  toggle_brackets = toggle_brackets,
  repeat_last = repeat_last
}