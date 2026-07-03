---@module 'pickers.health'
---@brief :checkhealth pickers — verify engines, CLI tools, config, and collections.

local M = {}

function M.check()
  -- ── Dependency: lib.nvim ─────────────────────────────────────────────────
  vim.health.start("pickers.nvim — dependencies")

  if pcall(require, "lib.nvim.notify") then
    vim.health.ok("lib.nvim available")
  else
    vim.health.error("lib.nvim not found — add 'github.com/StefanBartl/lib.nvim' as a dependency")
  end

  -- ── Picker engines ────────────────────────────────────────────────────────
  vim.health.start("pickers.nvim — picker engines")

  local has_telescope = pcall(require, "telescope.builtin")
  local has_fzf = pcall(require, "fzf-lua")

  if has_telescope then
    vim.health.ok("telescope.nvim available")
  else
    vim.health.warn("telescope.nvim not found")
  end

  if has_fzf then
    vim.health.ok("fzf-lua available")
  else
    vim.health.warn("fzf-lua not found")
  end

  if not has_telescope and not has_fzf then
    vim.health.error("No picker engine found — install telescope.nvim or fzf-lua")
  end

  -- ── CLI tools ─────────────────────────────────────────────────────────────
  vim.health.start("pickers.nvim — CLI tools")

  if vim.fn.executable("rg") == 1 then
    vim.health.ok("ripgrep (rg) found")
  else
    vim.health.warn("ripgrep (rg) not found — live_grep will not work")
  end

  if vim.fn.executable("fd") == 1 then
    vim.health.ok("fd found")
  elseif vim.fn.executable("fdfind") == 1 then
    vim.health.ok("fdfind found")
  else
    vim.health.warn("fd / fdfind not found — system source and dir-picker will not work")
  end

  -- ── Configuration ─────────────────────────────────────────────────────────
  vim.health.start("pickers.nvim — configuration")

  local ok, cfg_mod = pcall(require, "pickers.config")
  if not ok then
    vim.health.error("pickers.config failed to load")
    return
  end

  local cfg = cfg_mod.get()
  vim.health.info("default engine: " .. tostring(cfg.engine))

  if cfg.repos_dir then
    if vim.fn.isdirectory(cfg.repos_dir) == 1 then
      vim.health.ok("repos_dir exists: " .. cfg.repos_dir)
    else
      vim.health.warn("repos_dir set but not found: " .. cfg.repos_dir)
    end
  else
    vim.health.info("repos_dir not set — repos source unavailable")
  end

  local alias_count = 0
  for _ in pairs(cfg.depth_aliases) do
    alias_count = alias_count + 1
  end
  vim.health.info("depth_aliases: " .. alias_count .. " registered")

  -- ── Collections ───────────────────────────────────────────────────────────
  vim.health.start("pickers.nvim — collections")

  local collections = cfg.collections or {}
  if #collections == 0 then
    vim.health.info("No collections configured (optional — add them in setup())")
  else
    vim.health.info(#collections .. " collection(s) configured")
    for _, coll in ipairs(collections) do
      local label = coll.name .. " → " .. (coll.dir or "?")
      if vim.fn.isdirectory(coll.dir or "") == 1 then
        local detail = ""
        if coll.prefix ~= nil then
          detail = "  prefix=" .. (coll.prefix == "" and '""' or coll.prefix)
        end
        if coll.only_git then detail = detail .. "  only_git=true" end
        vim.health.ok(label .. detail)
      else
        vim.health.warn(label .. "  [directory not found]")
      end
    end
  end
end

return M
