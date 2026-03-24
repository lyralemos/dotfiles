local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local spaces = {}

local function update_windows(workspace_name)
  sbar.exec("aerospace list-windows --workspace " .. workspace_name .. " --format '%{app-name}'", function(app_names)
    local icon_line = ""
    local no_app = true
    local app_found = {}
    for app in string.gmatch(app_names, "[^\r\n]+") do
      local lookup = app_icons[app]
      local icon = ((lookup == nil) and app_icons["Default"] or lookup)
      if not app_found[icon] then
        icon_line = icon_line .. icon
        app_found[icon] = true
        no_app = false
      end
    end

    if (no_app) then
      icon_line = " —"
    end
    sbar.animate("tanh", 10, function()
      if spaces[workspace_name] then
        spaces[workspace_name]:set({ label = icon_line })
      end
    end)
  end)
end

local function update_all_windows()
  for workspace_name, _ in pairs(spaces) do
    update_windows(workspace_name)
  end
end

-- Get all workspaces from aerospace
local handle = io.popen("aerospace list-workspaces --all")
local workspaces_str = handle:read("*a")
handle:close()

for workspace_name in workspaces_str:gmatch("[^\r\n]+") do
  local space = sbar.add("item", "workspace." .. workspace_name, {
    icon = {
      font = { family = settings.font.numbers },
      string = workspace_name,
      padding_left = 15,
      padding_right = 8,
      color = colors.white,
      highlight_color = colors.green,
    },
    label = {
      padding_right = 5,
      color = colors.grey,
      highlight_color = colors.green,
      font = "sketchybar-app-font:Regular:16.0",
      y_offset = 1
    },
    padding_right = 1,
    padding_left = 1,
  })

  spaces[workspace_name] = space

  -- Padding
  sbar.add("item", "workspace.padding." .. workspace_name, {
    width = settings.group_paddings,
  })

  space:subscribe("aerospace_workspace_change", function(env)
    local selected = env.FOCUSED_WORKSPACE == workspace_name
    space:set({
      icon = { highlight = selected },
      label = { highlight = selected },
      background = { border_color = selected and colors.black or colors.bg2 }
    })
    -- space_bracket:set({
    --   background = { border_color = selected and colors.grey or colors.bg2 }
    -- })
  end)

  space:subscribe("mouse.clicked", function(env)
    sbar.exec("aerospace workspace " .. workspace_name)
  end)

  -- Initial update for this workspace
  update_windows(workspace_name)
end

-- Update all windows on workspace change
sbar.add("item", {
  drawing = false,
  updates = true,
}):subscribe("aerospace_workspace_change", function(env)
  update_all_windows()
end)

-- Also update on front_app_switched to keep icons current
sbar.add("item", {
  drawing = false,
  updates = true,
}):subscribe("front_app_switched", function(env)
  update_all_windows()
end)

-- Initial highlight
sbar.exec("aerospace list-workspaces --focused", function(focused_workspace)
  local workspace = focused_workspace:gsub("%s+", "")
  sbar.trigger("aerospace_workspace_change", { FOCUSED_WORKSPACE = workspace })
end)
