return {
  black = 0xff16161e,
  white = 0xffc0caf5,
  red = 0xfff7768e,
  green = 0xff9ece6a,
  yellow = 0xffe0af68,
  orange = 0xffff9e64,
  blue = 0xff7aa2f7,
  magenta = 0xffbb9af7,
  cyan = 0xff7dcfff,
  teal = 0xff73daca,
  grey = 0xff565f89,
  transparent = 0x00000000,

  bar = {
    bg = 0xb024283b,
    border = 0xff292e42,
  },
  popup = {
    bg = 0xe01f2335,
    border = 0xff3b4261,
  },
  bg1 = 0xff24283b,
  bg2 = 0xff292e42,

  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then return color end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}
