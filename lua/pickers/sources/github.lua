---@module 'pickers.sources.github'
---@brief GitHub issues and pull requests of the current repository as
---`pick_item` lists, through the `gh` CLI -- the telescope/fzf-lua half of
---the `gh_*` builtins that used to be snacks-only.
---@description
--- `gh issue list` / `gh pr list` with `--json` give the same rows on every
--- engine, so this source shells out once (async, `vim.system`), turns the
--- JSON into `Pickers.Item`s and hands them to the resolved engine's
--- `pick_item`. Picking an entry opens it in the browser (`vim.ui.open`),
--- which is what `gh <kind> view --web` does without a second process.
---
--- Snacks keeps its native `gh_issue`/`gh_pr` sources (they preview the
--- body); this module is what telescope and fzf-lua dispatch to. It needs
--- `gh` on `$PATH` and a cwd inside a GitHub repository -- both failures
--- come back as one notification with gh's own message.

local notify = require("lib.nvim.notify").create("[pickers]")

local M = {}

---@alias Pickers.GithubKind "issue"|"pr"

---@class Pickers.GithubItem: Pickers.Item
---@field number integer
---@field url string
---@field state string
---@field kind Pickers.GithubKind

---@type integer
M.LIMIT = 100

---The `gh` argv for `kind`/`state`.
---@param kind Pickers.GithubKind
---@param state "open"|"closed"|"merged"|"all"|nil
---@param limit integer|nil
---@return string[]
function M.command(kind, state, limit)
  return {
    "gh",
    kind == "pr" and "pr" or "issue",
    "list",
    "--state",
    state or "open",
    "--limit",
    tostring(limit or M.LIMIT),
    "--json",
    "number,title,state,url,author,updatedAt",
  }
end

---Turn gh's JSON into items, newest first as gh returns them. Pure.
---@param json string
---@param kind Pickers.GithubKind
---@return Pickers.GithubItem[]|nil items
---@return string|nil err
function M.parse(json, kind)
  local ok, rows = pcall(vim.json.decode, json)
  if not ok or type(rows) ~= "table" then return nil, "gh returned no JSON" end
  local items = {}
  for _, row in ipairs(rows) do
    if type(row) == "table" and row.number then
      local author = type(row.author) == "table" and row.author.login or ""
      local state = tostring(row.state or ""):lower()
      items[#items + 1] = {
        text = ("#%-5d %-7s %s%s"):format(
          row.number,
          state,
          tostring(row.title or ""),
          author ~= "" and ("  @" .. author) or ""
        ),
        number = row.number,
        url = row.url,
        state = state,
        kind = kind,
      }
    end
  end
  return items, nil
end

---Whether `gh` is on the PATH.
---@return boolean
function M.available()
  return vim.fn.executable("gh") == 1
end

---Fetch the list asynchronously; `cb(items, err)` on the main loop.
---@param kind Pickers.GithubKind
---@param state string|nil
---@param cb fun(items: Pickers.GithubItem[]|nil, err: string|nil)
function M.fetch(kind, state, cb)
  if not M.available() then
    cb(nil, "gh is not on $PATH (https://cli.github.com)")
    return
  end
  vim.system(M.command(kind, state), { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        local msg = (res.stderr or ""):gsub("%s+$", "")
        cb(nil, msg ~= "" and msg or ("gh exited with " .. tostring(res.code)))
        return
      end
      cb(M.parse(res.stdout or "", kind))
    end)
  end)
end

---Open the picked entry in the browser.
---@param item Pickers.GithubItem|string
function M.open(item)
  if type(item) ~= "table" or not item.url then return end
  local ok = pcall(vim.ui.open, item.url)
  if not ok then notify.warn("could not open " .. item.url) end
end

---Fetch and pick on `engine_mod` (default: the resolved engine).
---@param kind Pickers.GithubKind
---@param state string|nil
---@param engine_mod table|nil
function M.pick(kind, state, engine_mod)
  engine_mod = engine_mod or require("pickers.engines").load()
  if not engine_mod then return end
  local label = kind == "pr" and "Pull requests" or "Issues"
  M.fetch(kind, state, function(items, err)
    if not items then
      notify.error(("GitHub %s: %s"):format(label:lower(), tostring(err)))
      return
    end
    if #items == 0 then
      notify.info(("GitHub %s (%s): none"):format(label:lower(), state or "open"))
      return
    end
    engine_mod.pick_item({
      prompt = ("GitHub %s (%s)"):format(label, state or "open"),
      items = items,
      on_select = M.open,
    })
  end)
end

return M
