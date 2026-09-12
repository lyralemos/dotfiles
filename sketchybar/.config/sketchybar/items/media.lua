local icons = require("icons")
local colors = require("colors")

local whitelist = {
  ["Spotify"] = true,
  ["Music"] = true,
  ["com.apple.Music"] = true,
  ["com.spotify.client"] = true,
}

local media_cover = sbar.add("item", "media.cover", {
  position = "right",
  background = {
    image = {
      string = "/tmp/sketchybar_cover.jpg",
      scale = 0.5,
    },
    color = colors.transparent,
  },
  label = { drawing = false },
  icon = { drawing = false },
  drawing = false,
  updates = true,
  update_freq = 2,
  popup = {
    align = "center",
    horizontal = true,
  }
})

local media_artist = sbar.add("item", "media.artist", {
  position = "right",
  drawing = false,
  padding_left = 3,
  padding_right = 0,
  width = 0,
  icon = { drawing = false },
  label = {
    width = 0,
    font = { size = 9 },
    color = colors.with_alpha(colors.white, 0.6),
    max_chars = 18,
    y_offset = 6,
  },
})

local media_title = sbar.add("item", "media.title", {
  position = "right",
  drawing = false,
  padding_left = 3,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    font = { size = 11 },
    width = 0,
    max_chars = 16,
    y_offset = -5,
  },
})

sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.back, padding_left = 6, padding_right = 6 },
  label = { drawing = false },
  click_script = "nowplaying-cli previous; sleep 0.2; sketchybar --trigger media_update",
})
sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.play_pause, padding_left = 6, padding_right = 6 },
  label = { drawing = false },
  click_script = "nowplaying-cli togglePlayPause; sleep 0.2; sketchybar --trigger media_update",
})
sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.forward, padding_left = 6, padding_right = 6 },
  label = { drawing = false },
  click_script = "nowplaying-cli next; sleep 0.2; sketchybar --trigger media_update",
})

local interrupt = 0
local function animate_detail(detail)
  if (not detail) then interrupt = interrupt - 1 end
  if interrupt > 0 and (not detail) then return end

  sbar.animate("tanh", 30, function()
    media_artist:set({ label = { width = detail and "dynamic" or 0 } })
    media_title:set({ label = { width = detail and "dynamic" or 0 } })
  end)
end

local last_title = nil
local last_artist = nil
local last_state = false

local function update_media()
  sbar.exec("nowplaying-cli get --json title artist playbackRate clientBundleIdentifier", function(res)
    local title, artist, rate, client
    if type(res) == "table" then
      title = res.title
      artist = res.artist
      rate = tonumber(res.playbackRate) or 0
      client = res.clientBundleIdentifier
    elseif type(res) == "string" and res ~= "" and res ~= "{}" then
      title = res:match('"title"%s*:%s*"(.-)"[,\r\n]')
      artist = res:match('"artist"%s*:%s*"(.-)"[,\r\n]')
      rate = tonumber(res:match('"playbackRate"%s*:%s*([%d%.]+)')) or 0
      client = res:match('"clientBundleIdentifier"%s*:%s*"(.-)"[,\r\n]')
    end

    if title then title = title:gsub('\\"', '"') end
    if artist then artist = artist:gsub('\\"', '"') end

    -- Check if valid track exists
    local has_track = (title ~= nil and title ~= "" and title ~= "null")
    if not has_track then
      if last_state then
        media_cover:set({ drawing = false, popup = { drawing = false } })
        media_artist:set({ drawing = false })
        media_title:set({ drawing = false })
        last_state = false
        last_title = nil
        last_artist = nil
      end
      return
    end

    -- Check client against whitelist if present
    if client and client ~= "" and client ~= "null" then
      local allowed = whitelist[client] or client:find("Music") or client:find("Spotify")
      if not allowed then
        if last_state then
          media_cover:set({ drawing = false, popup = { drawing = false } })
          media_artist:set({ drawing = false })
          media_title:set({ drawing = false })
          last_state = false
        end
        return
      end
    end

    local is_playing = (rate > 0)

    -- Update track info if song or artist changed
    if title ~= last_title or artist ~= last_artist then
      last_title = title
      last_artist = artist

      media_artist:set({ label = { string = artist or "" } })
      media_title:set({ label = { string = title or "" } })

      -- Fetch and downsample artwork to 48x48 (Retina 24pt)
      sbar.exec("nowplaying-cli get artworkData | base64 -d > /tmp/sketchybar_cover_raw.jpg 2>/dev/null && sips -Z 48 /tmp/sketchybar_cover_raw.jpg --out /tmp/sketchybar_cover.jpg >/dev/null 2>&1", function()
        local f = io.open("/tmp/sketchybar_cover.jpg", "r")
        if f then
          local bytes = f:seek("end")
          f:close()
          if bytes and bytes > 50 then
            media_cover:set({
              drawing = true,
              icon = { drawing = false },
              background = {
                image = {
                  string = "/tmp/sketchybar_cover.jpg",
                  scale = 0.5,
                  drawing = true,
                },
                color = colors.transparent,
              }
            })
            return
          end
        end
        media_cover:set({
          drawing = true,
          icon = { string = icons.media.play_pause, drawing = true },
          background = { image = { drawing = false } }
        })
      end)

      media_cover:set({ drawing = true })
      media_artist:set({ drawing = true })
      media_title:set({ drawing = true })

      animate_detail(true)
      interrupt = interrupt + 1
      sbar.delay(5, animate_detail)
    else
      if not last_state then
        media_cover:set({ drawing = true })
        media_artist:set({ drawing = true })
        media_title:set({ drawing = true })
      end
    end

    -- Update styling according to playing/paused state
    if is_playing then
      media_artist:set({ label = { color = colors.with_alpha(colors.white, 0.6) } })
      media_title:set({ label = { color = colors.white } })
      media_cover:set({ background = { color = colors.transparent } })
    else
      media_artist:set({ label = { color = colors.with_alpha(colors.white, 0.35) } })
      media_title:set({ label = { color = colors.with_alpha(colors.white, 0.5) } })
      media_cover:set({ background = { color = colors.with_alpha(colors.black, 0.3) } })
    end

    last_state = true
  end)
end

media_cover:subscribe({"routine", "forced", "system_woke", "media_change", "media_update"}, function(env)
  update_media()
end)

media_cover:subscribe("mouse.entered", function(env)
  interrupt = interrupt + 1
  animate_detail(true)
  update_media()
end)

media_cover:subscribe("mouse.exited", function(env)
  animate_detail(false)
end)

media_cover:subscribe("mouse.clicked", function(env)
  media_cover:set({ popup = { drawing = "toggle" }})
end)

media_title:subscribe("mouse.exited.global", function(env)
  media_cover:set({ popup = { drawing = false }})
end)

-- Initial check on load
update_media()
