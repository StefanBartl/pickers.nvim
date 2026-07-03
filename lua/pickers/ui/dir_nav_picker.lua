---@module 'pickers.ui.dir_nav_picker'
---@brief Interactive directory navigation picker via hover_select.
---@description
--- Displays:
---   • Named aliases from config.depth_aliases (sorted alphabetically)
---   • "1 up" … "5 up"  (go N directories above cwd)
---   • "path=…"         (type an explicit path)
---
--- The callback receives the chosen nav-arg string exactly as actions/dir.lua
--- expects it:  alias name | "1" … "5" | "path=<typed>" | nil (cancel).

local M = {}

---@param cfg      Pickers.Config
---@param callback fun(string|nil)
function M.open(cfg, callback)
  -- 1. Sorted alias names
  local alias_names = {}
  for k in pairs(cfg.depth_aliases) do
    alias_names[#alias_names + 1] = k
  end
  table.sort(alias_names)

  -- 2. Build item list
  local items = {}
  for _, name in ipairs(alias_names) do
    items[#items + 1] = name
  end
  for i = 1, 5 do
    items[#items + 1] = tostring(i) .. " up"
  end
  items[#items + 1] = "path=…"

  -- 3. on_select handler (shared by both pickers)
  local function on_select(choice)
    if not choice then
      callback(nil)
      return
    end

    -- "N up" → numeric string
    local n = choice:match("^(%d+) up$")
    if n then
      callback(n)
      return
    end

    -- path=… → prompt for explicit path
    if choice == "path=…" then
      vim.ui.input({ prompt = "path= " }, function(input)
        if input and not input:match("^%s*$") then
          callback("path=" .. input)
        else
          callback(nil)
        end
      end)
      return
    end

    -- Alias
    callback(choice)
  end

  -- 4. Show picker
  local ok, hover = pcall(require, "lib.nvim.ui.hover_select")
  if ok and hover and type(hover.open) == "function" then
    hover.open({
      title = "Dir — Navigate to",
      items = items,
      on_select = on_select,
    })
  else
    vim.ui.select(items, { prompt = "Navigate to:" }, on_select)
  end
end

return M
