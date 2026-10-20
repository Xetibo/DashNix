config: {
  input = {
    kb_layout = config.mods.xkb.layout;
    kb_variant = config.mods.xkb.variant;
    repeat_delay = 200;
    force_no_accel = true;
    touchpad = {
      natural_scroll = true;
      tap_to_click = true;
      tap_and_drag = true;
    };
  };
  cursor = {
    enable_hyprcursor = true;
    no_hardware_cursors =
      if config.mods.gpu.nvidia.enable
      then 2
      else 0;
    sync_gsettings_theme = false;
  };
}
