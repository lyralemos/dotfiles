local colors = require("colors")
local settings = require("settings")

sbar.add("item", "chevron", {
  icon = {
    string = "",
    font = "Hack Nerd Font:Bold:14.0",
    drawing = true,
  }
})

local front_app = sbar.add("item", "front_app", {
  display = "active",
  icon = { drawing = false },
  label = {
    font = {
      style = settings.font.style_map["Black"],
      size = 12.0,
    },
  },
  updates = true,
})

front_app:subscribe("front_app_switched", function(env)
  front_app:set({ label = { string = env.INFO } })
end)
