---@module 'pickers.ui.dir_nav_picker'
---@brief Interactive directory navigation picker via lib.nvim.ui.kit.
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
---@param callback fun(choice: string|nil) Alias name, `"1"`..`"5"`, `"path=<typed>"`, or nil when cancelled.
function M.open(cfg, callback)
  local kit_ok, kit = pcall(require, "lib.nvim.ui.kit")

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
  ---@internal
  ---@param choice string|nil
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
      ---@internal
      ---@param input string|nil
      local function handle_input(input)
        if input and not input:match("^%s*$") then
          callback("path=" .. input)
        else
          callback(nil)
        end
      end
      if kit_ok and kit and type(kit.input) == "function" then
        kit.input({
          title = "path= ",
          on_submit = handle_input,
          on_cancel = function()
            callback(nil)
          end,
        })
      else
        vim.ui.input({ prompt = "path= " }, handle_input)
      end
      return
    end

    -- Alias
    callback(choice)
  end

  -- 4. Show picker
  if kit_ok and kit and type(kit.select) == "function" then
    kit.select({
      title = "Dir — Navigate to",
      items = items,
      on_select = on_select,
    })
  else
    vim.ui.select(items, { prompt = "Navigate to:" }, on_select)
  end
end

return M
