local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local spaces = {}
local focused_workspace = nil

local function update_windows(workspace_name)
  if not workspace_name or workspace_name ~= focused_workspace then
    if workspace_name and spaces[workspace_name] then
      spaces[workspace_name]:set({
        icon = { padding_left = 8, padding_right = 8 },
        label = { drawing = false, string = "" }
      })
    end
    return
  end

  sbar.exec("aerospace list-windows --workspace " .. workspace_name .. " --format '%{app-name}'", function(app_names)
    if workspace_name ~= focused_workspace then return end

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

    if spaces[workspace_name] then
      sbar.animate("tanh", 10, function()
        if no_app or workspace_name ~= focused_workspace then
          spaces[workspace_name]:set({
            icon = { padding_left = 8, padding_right = 8 },
            label = { drawing = false, string = "" }
          })
        else
          spaces[workspace_name]:set({
            icon = { padding_left = 8, padding_right = 4 },
            label = {
              drawing = true,
              string = icon_line,
              padding_left = 0,
              padding_right = 8
            }
          })
        end
      end)
    end
  end)
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
      padding_left = 8,
      padding_right = 8,
      color = colors.white,
      highlight_color = colors.blue,
    },
    label = {
      drawing = false,
      padding_left = 0,
      padding_right = 8,
      color = colors.grey,
      highlight_color = colors.blue,
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
    local selected = (env.FOCUSED_WORKSPACE == workspace_name)
    if selected then
      focused_workspace = workspace_name
      space:set({
        icon = { highlight = true },
        label = { highlight = true },
        background = { border_color = colors.blue }
      })
      update_windows(workspace_name)
    else
      space:set({
        icon = { highlight = false, padding_left = 8, padding_right = 8 },
        label = { highlight = false, drawing = false, string = "" },
        background = { border_color = colors.bg2 }
      })
    end
  end)

  space:subscribe("mouse.clicked", function(env)
    sbar.exec("aerospace workspace " .. workspace_name)
  end)
end

-- Update focused workspace on front_app_switched or focus change to keep icons current
local listener = sbar.add("item", {
  drawing = false,
  updates = true,
})

listener:subscribe({"front_app_switched", "aerospace_focus_change"}, function(env)
  if env.FOCUSED_WORKSPACE and env.FOCUSED_WORKSPACE ~= "" and env.FOCUSED_WORKSPACE ~= focused_workspace then
    sbar.trigger("aerospace_workspace_change", { FOCUSED_WORKSPACE = env.FOCUSED_WORKSPACE })
    return
  end
  if focused_workspace then
    update_windows(focused_workspace)
  end
end)

-- Initial highlight and window detection
sbar.exec("aerospace list-workspaces --focused", function(focused_workspace_res)
  local workspace = focused_workspace_res:gsub("%s+", "")
  focused_workspace = workspace
  sbar.trigger("aerospace_workspace_change", { FOCUSED_WORKSPACE = workspace })
end)
