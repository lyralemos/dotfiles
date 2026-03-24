local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

-- Padding item required because of bracket
sbar.add("item", { width = 5 })

local apple = sbar.add("item", {
  icon = {
    font = { size = 17.0 },
    string = icons.apple,
    padding_right = 8,
    padding_left = 8,
    y_offset = 2,
  },
  label = { drawing = false },
  padding_left = 1,
  padding_right = 1,
})

-- Padding item required because of bracket
sbar.add("item", { width = 7 })
