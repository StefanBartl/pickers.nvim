---@module 'pickers.sources.types'
---@brief Source-related type definitions (scopes, resolved source, collections).

-- ###########################################################################
-- Scope identifier

---@alias Pickers.Scope
---| '"cwd"'        # Current working directory
---| '"config"'     # Neovim config directory (stdpath "config")
---| '"folder"'     # Interactively picked folder via engine dir-picker
---| '"repos"'      # One repo selected from REPOS_DIR
---| '"wkdbooks"'   # One wkdbook selected from wkdbooks_dir
---| '"system"'     # Systemwide fd search (interactive query)
---| '"drives"'     # All mount points / drive letters
---| '"dir"'        # Depth / alias / explicit-path navigation

-- ###########################################################################
-- Source (result of a source module's get())

---@class Pickers.Source
---@field roots          string[]      Absolute search-root directories
---@field prompt         string        Prompt prefix shown in the picker
---@field find_command   string[]|nil  Custom fd/find command (system scope)
---@field additional_args string[]|nil Extra rg/fzf-lua args (drives scope)

-- ###########################################################################
-- Collection (user-defined named scope)

---@class Pickers.Collection
---@field name     string                               Unique scope name (e.g. "notes")
---@field dir      string                               Root directory
---@field prefix   string|nil                           nil=direct root, ""=all subdirs, "xyz-"=filtered
---@field keys     { files?: string, grep?: string }|nil  Optional keymaps
---@field only_git boolean|nil                          Only show subdirs that contain .git

return {}
