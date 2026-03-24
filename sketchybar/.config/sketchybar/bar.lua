local colors = require("colors")

-- Equivalent to the --bar domain
sbar.bar({
  height = 39,
  sticky = "on",
  padding_right=10,
  padding_left=10,
  corner_radius=9,
  y_offset=6,
  margin=10,
  blur_radius=20,
  notch_width=0,
  color = colors.bar.bg,
})
