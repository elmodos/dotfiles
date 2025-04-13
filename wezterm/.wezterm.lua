local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.automatically_reload_config = true
config.hide_tab_bar_if_only_one_tab = true

config.font_size = 10

config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

config.initial_cols = 140
config.initial_rows = 35
config.enable_wayland = false

-- Window title
wezterm.on('format-window-title', function(tab, ane, tabs, panes, aconfig)
  return "WezTerm - " .. tab.active_pane.title
end)

-- Light/Dark modes
local function get_appearance()
  if wezterm.gui then
    return wezterm.gui.get_appearance()
  end
  return 'Dark'
end

local function scheme_for_appearance(appearance)
  if appearance:find 'Dark' then
    return 'Ayu Dark (Gogh)'
  else
    return 'Ayu Light (Gogh)'
  end
end

config.color_scheme = scheme_for_appearance(get_appearance())

return config
