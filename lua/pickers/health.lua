---@module 'pickers.health'
---@brief :checkhealth pickers — verify engines, CLI tools, config, and collections.

local M = {}

---Run all `:checkhealth pickers` sections: dependencies, picker engines, CLI
---tools, configuration, and collections.
function M.check()
  -- ── Dependency: lib.nvim ─────────────────────────────────────────────────
  vim.health.start("pickers.nvim — dependencies")

  if pcall(require, "lib.nvim.notify") then
    vim.health.ok("lib.nvim available")
  else
    vim.health.error("lib.nvim not found — add 'github.com/StefanBartl/lib.nvim' as a dependency")
  end

  -- lib.nvim.bindings.usercmd.composer: required — the :Pickers command layer is built
  -- on it, with no raw-API fallback (unlike the compat aliases in
  -- bindings/util.lua, which still degrade gracefully without lib.nvim).
  if pcall(require, "lib.nvim.bindings.usercmd.composer") then
    vim.health.ok("lib.nvim.bindings.usercmd.composer available (:Pickers command layer)")
  else
    vim.health.error(
      ":Pickers will fail to register — lib.nvim.bindings.usercmd.composer not found"
    )
  end

  -- ── Picker engines ────────────────────────────────────────────────────────
  vim.health.start("pickers.nvim — picker engines")

  local has_telescope = pcall(require, "telescope.builtin")
  local has_fzf = pcall(require, "fzf-lua")
  local has_snacks = pcall(require, "snacks.picker")

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

  if has_snacks then
    vim.health.ok("snacks.nvim (picker) available")
  else
    vim.health.warn("snacks.nvim (picker) not found")
  end

  if not has_telescope and not has_fzf and not has_snacks then
    vim.health.error("No picker engine found — install telescope.nvim, fzf-lua, or snacks.nvim")
  end

  -- ── CLI tools ─────────────────────────────────────────────────────────────
  vim.health.start("pickers.nvim — CLI tools")

  local has_rg = vim.fn.executable("rg") == 1
  local has_fd = vim.fn.executable("fd") == 1 or vim.fn.executable("fdfind") == 1

  if has_rg then
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

  -- The smart action (see :help pickers-smart) needs BOTH rg and fd.
  if has_rg and has_fd then
    vim.health.ok("smart action ready (rg + fd both present)")
  else
    vim.health.warn(
      "smart action degraded — it needs BOTH rg and fd; the missing half is skipped"
    )
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

  if cfg.history.enabled then
    if has_telescope or has_fzf then
      vim.health.ok("history enabled (applies to telescope/fzf-lua)")
    end
    if has_snacks then
      vim.health.info(
        "history.enabled has no effect on snacks.nvim — its picker history is "
          .. "built-in and always-on (per-source file under stdpath('data')/snacks/), "
          .. "not configurable via pickers.nvim. See docs/CONFIGURATION.md."
      )
    end
    if not has_telescope and not has_fzf and not has_snacks then
      vim.health.warn("history enabled but no engine found to apply it to")
    end
  end

  if has_fzf and cfg.keys and cfg.keys.enable ~= false then
    local ok_keys, keys_mod = pcall(require, "pickers.keys")
    if ok_keys then
      local skipped = keys_mod.fzf_skipped(cfg)
      if #skipped > 0 then
        vim.health.info(
          "fzf-lua cannot remap: "
            .. table.concat(skipped, ", ")
            .. " (horizontal preview scroll / history are fzf-native, fixed). "
            .. "See docs/KEYMAPS.md."
        )
      end
    end
  end

  -- ── Image previews (images.nvim) ─────────────────────────────────────────
  -- Three separate answers, because the three causes need three different
  -- fixes: a switched-off integration, a missing plugin, and a terminal that
  -- cannot draw are not the same problem. See pickers.integrations.images.
  vim.health.start("pickers.nvim — image previews (images.nvim)")

  local ok_images, images = pcall(require, "pickers.integrations.images")
  if not ok_images then
    vim.health.error("pickers.integrations.images failed to load")
  elseif not images.enabled() then
    vim.health.info("switched off in setup(): images = { enabled = false }")
  elseif not pcall(require, "images.integrations.picker") then
    vim.health.info(
      "images.nvim not installed — image entries preview as text, as before. "
        .. "https://github.com/StefanBartl/images.nvim previews them as pictures."
    )
  elseif images.available() then
    vim.health.ok(
      "active on snacks and telescope (fzf-lua previews images through its own "
        .. "previewers.builtin.extensions — chafa/viu/ueberzug)"
    )
  else
    vim.health.warn(
      "images.nvim is installed but reports that this terminal cannot draw — "
        .. "run :checkhealth images; images.nvim's `display.assume_supported = true` "
        .. "overrides the detection when it is wrong"
    )
  end

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

  -- ── Declared tools (lib.nvim.deps) ──────────────────────────────────────
  -- pickers.nvim's own docs/install.json — the same rg/fd checks above, but
  -- with their declared `why` and a pointer to `:Lib deps show`. Does
  -- nothing if lib.nvim.deps is unavailable (older lib.nvim).
  local ok_deps, deps_health = pcall(require, "lib.nvim.deps.health")
  if ok_deps then
    vim.health.start("pickers.nvim — declared tools (lib.nvim.deps)")
    deps_health.report_for("pickers.nvim")
  end

  require("lib.nvim.bindings.usercmd.composer").checkhealth("Pickers")
end

return M
