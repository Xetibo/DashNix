let
  browserName = config:
    if (builtins.isString config.mods.homePackages.browser)
    then config.mods.homePackages.browser
    else if config.mods.homePackages.browser ? meta && config.mods.homePackages.browser.meta ? mainProgram
    then config.mods.homePackages.browser.meta.mainProgram
    else config.mods.homePackages.browser.pname;
  mkSimpleBind = modKeys: key: command: args: {
    inherit modKeys key command args;
  };
  mkRepeatSimpleBind = modKeys: key: command: args: {
    inherit modKeys key command args;
    meta.hyprland.repeat = true;
  };
  mkSimpleCustomBind = modKeys: key: niri: hyprland: args: {
    inherit modKeys key args;
    command = {
      inherit niri hyprland;
    };
  };
  mkRepeatCustomBind = modKeys: key: niri: hyprland: args: {
    inherit modKeys key args;
    command = {
      inherit niri hyprland;
    };
    meta.hyprland.repeat = true;
  };
  mkBindWithDesc = modKeys: key: command: args: desc:
    {
      meta.niri.desc = desc;
    }
    // mkSimpleBind modKeys key command args;
in {
  defaultWindowRules = {
    niri = [
      ''
        match app-id=r#"^org\.keepassxc\.KeePassXC$"#
        match app-id=r#"^org\.gnome\.World\.Secrets$"#

        block-out-from "screen-capture"
      ''
      ''
        match app-id=r#"^steam$"#
        open-on-workspace "0"
      ''
      ''
        geometry-corner-radius 12
        clip-to-geometry true
      ''
    ];
    hyprland = [
      # window rules
      "float,class:^(.*)(OxiCalc)(.*)$"
      "float,class:^(.*)(winecfg.exe)(.*)$"
      "float,class:^(.*)(copyq)(.*)$"
      "center,class:^(.*)(swappy)(.*)$"
      "workspace 10 silent,class:^(.*)(steam)(.*)$"

      # Otherwise neovide will ignore tiling
      "suppressevent fullscreen maximize,class:^(.*)(neovide)(.*)$"
    ];
  };

  defaultStartup = config: {
    all = [
      "systemctl --user import-environment"
      "dbus-update-activation-environment --systemd --all"
      "hyprctl setcursor ${config.mods.stylix.cursor.name} ${toString config.mods.stylix.cursor.size}"
      # ensures the systemd service knows what "hyprctl" is :)
      (
        if config.mods.gaming.gamemode
        then "systemctl try-restart gamemoded.service --user"
        else ""
      )

      # other programs
      "${browserName config}"
      (
        if config.mods.oxi.hyprdock.enable
        then "hyprdock --server"
        else ""
      )
      (
        if config.mods.hypr.hyprpaper.enable
        then "hyprpaper"
        else ""
      )
      (
        if config.mods.hypr.hyprland.useIronbar
        then "ironbar"
        else ""
      )
      (
        if config.mods.oxi.oxipaste.enable
        then "oxipaste_daemon"
        else ""
      )
      (
        if config.mods.oxi.oxinoti.enable
        then "oxinoti"
        else ""
      )
    ];
    niri = [
      "XDG_CURRENT_DESKTOP=Niri"
      "XDG_SESSION_DESKTOP=Niri"
      "XDG_SESSION_TYPE=wayland"
    ];
    hyprland = [
      "XDG_CURRENT_DESKTOP=Hyprland"
      "XDG_SESSION_DESKTOP=Hyprland"
      "XDG_SESSION_TYPE=wayland"
    ];
  };

  defaultEnv = config: {
    all = {
      GTK_CSD = "0";
      TERM = "kitty /bin/fish";
      HYPRCURSOR_THEME = config.mods.stylix.cursor.name;
      HYPRCURSOR_SIZE = toString config.mods.stylix.cursor.size;
      XCURSOR_THEME = config.mods.stylix.cursor.name;
      XCURSOR_SIZE = toString config.mods.stylix.cursor.size;
      QT_QPA_PLATFORM = "wayland";
      QT_QPA_PLATFORMTHEME = "qt5ct";
      QT_WAYLAND_FORCE_DPI = "96";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      QT_SCALE_FACTOR = "1";
      EDITOR = "neovide --novsync --nofork";

      LIBVA_DRIVER_NAME =
        if config.mods.gpu.nvidia.enable
        then "nvidia"
        else "";
      GBM_BACKEND =
        if config.mods.gpu.nvidia.enable
        then "nvidia-drm"
        else "";
      __GLX_VENDOR_LIBRARY_NAME =
        if config.mods.gpu.nvidia.enable
        then "nvidia"
        else "";
    };
    niri = {};
    hyprland = {};
  };

  defaultBinds = config: [
    (mkSimpleBind ["Mod"] "1" "focusWorkspace" ["1"])
    (mkSimpleBind ["Mod"] "2" "focusWorkspace" ["2"])
    (mkSimpleBind ["Mod"] "3" "focusWorkspace" ["3"])
    (mkSimpleBind ["Mod"] "4" "focusWorkspace" ["4"])
    (mkSimpleBind ["Mod"] "5" "focusWorkspace" ["5"])
    (mkSimpleBind ["Mod"] "6" "focusWorkspace" ["6"])
    (mkSimpleBind ["Mod"] "7" "focusWorkspace" ["7"])
    (mkSimpleBind ["Mod"] "8" "focusWorkspace" ["8"])
    (mkSimpleBind ["Mod"] "9" "focusWorkspace" ["9"])
    (mkSimpleBind ["Mod"] "0" "focusWorkspace" ["0"])
    (mkSimpleBind ["Mod" "Shift"] "1" "moveToWorkspace" ["1"])
    (mkSimpleBind ["Mod" "Shift"] "2" "moveToWorkspace" ["2"])
    (mkSimpleBind ["Mod" "Shift"] "3" "moveToWorkspace" ["3"])
    (mkSimpleBind ["Mod" "Shift"] "4" "moveToWorkspace" ["4"])
    (mkSimpleBind ["Mod" "Shift"] "5" "moveToWorkspace" ["5"])
    (mkSimpleBind ["Mod" "Shift"] "6" "moveToWorkspace" ["6"])
    (mkSimpleBind ["Mod" "Shift"] "7" "moveToWorkspace" ["7"])
    (mkSimpleBind ["Mod" "Shift"] "8" "moveToWorkspace" ["8"])
    (mkSimpleBind ["Mod" "Shift"] "9" "moveToWorkspace" ["9"])
    (mkSimpleBind ["Mod" "Shift"] "0" "moveToWorkspace" ["0"])
    (mkSimpleBind ["Mod"] "B" "toggleFullscreen" [])
    (mkSimpleBind ["Mod"] "V" "toggleFloating" [])
    (mkSimpleBind ["Mod" "Shift"] "M" "quit" [])
    (mkSimpleBind ["Mod"] "Left" "moveWindowLeft" [])
    (mkSimpleBind ["Mod"] "Down" "moveWindowDown" [])
    (mkSimpleBind ["Mod"] "Up" "moveWindowUp" [])
    (mkSimpleBind ["Mod"] "Right" "moveWindowRight" [])

    (mkRepeatSimpleBind ["Mod"] "J" "moveFocusLeft" [])
    (mkRepeatSimpleBind ["Mod"] "K" "moveFocusDown" [])
    (mkRepeatSimpleBind ["Mod"] "L" "moveFocusUp" [])
    (mkRepeatSimpleBind ["Mod"] "semicolon" "moveFocusRight" [])

    (mkBindWithDesc ["Mod"] "Q" "killActive" [] "Kill active window")

    (mkBindWithDesc ["Mod"] "N" "spawn" ["neovide"] "Open Neovide")
    (mkBindWithDesc ["Mod"] "T" "spawn-sh" ["kitty" "-1"] "Open Kitty")
    (mkBindWithDesc ["Mod" "Shift"] "L" "spawn" ["hyprlock"] "Lock screen")

    (
      if config.mods.yazi.enable
      then mkBindWithDesc ["Mod"] "E" "spawn-sh" ["EDITOR='neovide --no-fork' kitty yazi"] "Open Yazi"
      else {}
    )
    (
      if config.mods.anyrun.enable
      then mkBindWithDesc ["Mod"] "R" "spawn" ["anyrun"] "Open Anyrun"
      else {}
    )
    (
      if config.mods.oxi.oxirun.enable
      then mkBindWithDesc ["Mod"] "R" "spawn" ["oxirun"] "Open OxiRun"
      else {}
    )
    (
      if config.mods.oxi.oxidash.enable
      then mkBindWithDesc ["Mod"] "M" "spawn" ["oxidash"] "Open OxiDash"
      else {}
    )
    (
      if config.mods.oxi.oxicalc.enable
      then mkBindWithDesc ["Mod"] "G" "spawn" ["oxicalc"] "Open Oxicalc"
      else {}
    )
    (
      if config.mods.oxi.oxishut.enable
      then mkBindWithDesc ["Mod"] "D" "spawn" ["oxishut"] "Open OxiShut"
      else {}
    )
    (
      if config.mods.oxi.oxipaste.enable
      then mkBindWithDesc ["Mod"] "A" "spawn" ["oxipaste"] "Open Oxipaste"
      else {}
    )
    (
      if config.mods.oxi.hyprdock.enable
      then mkBindWithDesc ["Mod" "Shift"] "P" "spawn" ["hyprdock --gui"] "Open Hyprdock"
      else {}
    )
    (
      if config.mods.hypr.hyprlock.enable
      then mkBindWithDesc ["Mod" "Shift" "Alt"] "L" "spawn-sh" ["playerctl -a pause & hyprlock & systemctl suspend"] "Lock and suspend"
      else {}
    )
    (
      if config.mods.hypr.hyprlock.enable
      then mkBindWithDesc ["Mod" "Shift" "Alt"] "K" "spawn-sh" ["playerctl -a pause & hyprlock & systemctl hibernate"] "Lock and hibernate"
      else {}
    )

    (mkBindWithDesc ["Mod"] "F" "spawn" ["${browserName config}"] "Open Browser")
    (
      if
        (
          browserName config == "firefox" || browserName config == "zen"
        )
      then mkBindWithDesc ["Mod" "Shift"] "F" "spawn" ["${browserName config} -p special"] "Open Browser Special Profile"
      else {}
    )

    (mkBindWithDesc ["Mod"] "S" "spawn-sh" [''grim -g "$(slurp)" - | wl-copy''] "Take Screenshot")
    (mkBindWithDesc ["Mod" "Shift"] "S" "spawn-sh" [''grim -g "$(slurp)" - | satty -f -''] "Take Screenshot and edit")

    (
      if config.mods.scripts.audioControl
      then {
        key = "XF86AudioMute";
        command = "spawn-sh";
        args = ["audioControl mute"];
        meta.niri = {
          allowWhileLocked = true;
          desc = "Mute Audio";
        };
      }
      else {}
    )
    (
      if config.mods.scripts.audioControl
      then {
        key = "XF86AudioRaiseVolume";
        command = "spawn-sh";
        args = ["audioControl +5%"];
        meta.niri = {
          allowWhileLocked = true;
          desc = "Raise Audio Volume";
        };
      }
      else {}
    )
    (
      if config.mods.scripts.audioControl
      then {
        key = "XF86AudioLowerVolume";
        command = "spawn-sh";
        args = ["audioControl -5%"];
        meta.niri = {
          allowWhileLocked = true;
          desc = "Lower Audio Volume";
        };
      }
      else {}
    )
    {
      key = "XF86AudioPlay";
      command = "spawn-sh";
      args = ["playerctl play-pause"];
      meta.niri = {
        allowWhileLocked = true;
        desc = "Play/Pause";
      };
    }
    {
      key = "XF86AudioNext";
      command = "spawn-sh";
      args = ["playerctl next"];
      meta.niri = {
        allowWhileLocked = true;
        desc = "Next Song";
      };
    }
    {
      key = "XF86AudioPrev";
      command = "spawn-sh";
      args = ["playerctl previous"];
      meta.niri = {
        allowWhileLocked = true;
        desc = "Previous Song";
      };
    }
    (
      if config.mods.scripts.changeBrightness
      then {
        key = "XF86MonBrightnessDown";
        command = "spawn-sh";
        args = ["changeBrightness -10%"];
        meta.niri = {
          allowWhileLocked = true;
          desc = "Lower Brigthness";
        };
      }
      else {}
    )
    (
      if config.mods.scripts.changeBrightness
      then {
        key = "XF86MonBrightnessUp";
        command = "spawn-sh";
        args = ["changeBrightness +10%"];
        meta.niri = {
          allowWhileLocked = true;
          desc = "Raise Brigthness";
        };
      }
      else {}
    )

    # Niri only keybinds
    (mkSimpleCustomBind ["Mod"] "BracketLeft" "consume-or-expel-window-left" null [])
    (mkSimpleCustomBind ["Mod"] "BracketRight" "consume-or-expel-window-right" null [])
    (mkSimpleCustomBind ["Mod"] "Comma" "consume-window-into-column" null [])
    (mkSimpleCustomBind ["Mod"] "Period" "expel-window-from-column" null [])
    (mkSimpleCustomBind ["Mod"] "Y" "switch-preset-column-width" null [])
    (mkSimpleCustomBind ["Mod"] "Tab" "focus-workspace-previous" null [])
    (mkSimpleCustomBind ["Mod" "Shift"] "V" "switch-focus-between-floating-and-tiling" null [])
    (mkSimpleCustomBind ["Mod" "Shift"] "B" "expand-column-to-available-width" null [])
    (mkSimpleCustomBind ["Mod"] "U" "set-column-width" null ["-10%"])
    (mkSimpleCustomBind ["Mod"] "P" "set-column-width" null ["+10%"])
    (mkSimpleCustomBind ["Mod"] "O" "set-column-width" null ["50%"])
    (mkSimpleCustomBind ["Mod" "Shift"] "Minus" "set-window-height" null ["-10%"])
    (mkSimpleCustomBind ["Mod" "Shift"] "Equal" "set-window-height" null ["+10%"])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "1" "move-column-to-workspace" null ["1"])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "2" "move-column-to-workspace" null ["2"])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "3" "move-column-to-workspace" null ["3"])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "4" "move-column-to-workspace" null ["4"])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "5" "move-column-to-workspace" null ["5"])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "6" "move-column-to-workspace" null ["6"])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "7" "move-column-to-workspace" null ["7"])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "8" "move-column-to-workspace" null ["8"])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "9" "move-column-to-workspace" null ["9"])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "0" "move-column-to-workspace" null ["0"])
    (mkSimpleCustomBind ["Mod" "Shift"] "J" "focus-monitor-left" null [])
    (mkSimpleCustomBind ["Mod" "Shift"] "semicolon" "focus-monitor-right" null [])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "J" "move-column-to-monitor-left" null [])
    (mkSimpleCustomBind ["Mod" "Ctrl"] "semicolon" "move-column-to-monitor-right" null [])
    (mkSimpleCustomBind ["Mod" "Shift"] "Slash" "show-hotkey-overlay" null [])
    {
      modKeys = ["Mod"];
      key = "W";
      command.niri = "toggle-overview";
      meta.niri = {
        desc = "Overview";
        repeat = false;
      };
    }
    {
      modKeys = ["Mod"];
      key = "Escape";
      command.niri = "toggle-keyboard-shortcuts-inhibit";
      meta.niri = {
        allowInhibit = false;
      };
    }
    {
      modKeys = ["Mod"];
      key = "WheelScrollUp";
      command.niri = "focus-workspace-up";
      meta.niri.cooldown = 150;
    }
    {
      modKeys = ["Mod"];
      key = "WheelScrollDown";
      command.niri = "focus-workspace-down";
      meta.niri.cooldown = 150;
    }
    {
      modKeys = ["Mod"];
      key = "WheelScrollRight";
      command.niri = "focus-column-right";
      meta.niri.cooldown = 150;
    }
    {
      modKeys = ["Mod"];
      key = "WheelScrollLeft";
      command.niri = "focus-column-left";
      meta.niri.cooldown = 150;
    }

    # Hyprland only keybinds
    (mkSimpleCustomBind ["Mod"] "C" null "togglesplit" [])
    (mkSimpleCustomBind ["Mod" "SHIFT" "ALT"] "1" null "movetoworkspacesilent" ["1"])
    (mkSimpleCustomBind ["Mod" "SHIFT" "ALT"] "2" null "movetoworkspacesilent" ["2"])
    (mkSimpleCustomBind ["Mod" "SHIFT" "ALT"] "3" null "movetoworkspacesilent" ["3"])
    (mkSimpleCustomBind ["Mod" "SHIFT" "ALT"] "4" null "movetoworkspacesilent" ["4"])
    (mkSimpleCustomBind ["Mod" "SHIFT" "ALT"] "5" null "movetoworkspacesilent" ["5"])
    (mkSimpleCustomBind ["Mod" "SHIFT" "ALT"] "6" null "movetoworkspacesilent" ["6"])
    (mkSimpleCustomBind ["Mod" "SHIFT" "ALT"] "7" null "movetoworkspacesilent" ["7"])
    (mkSimpleCustomBind ["Mod" "SHIFT" "ALT"] "8" null "movetoworkspacesilent" ["8"])
    (mkSimpleCustomBind ["Mod" "SHIFT" "ALT"] "9" null "movetoworkspacesilent" ["9"])
    (mkSimpleCustomBind ["Mod" "SHIFT" "ALT"] "0" null "movetoworkspacesilent" ["0"])
    (mkRepeatCustomBind ["Mod"] "U" null "resizeactive" ["-20" "0"])
    (mkRepeatCustomBind ["Mod"] "P" null "resizeactive" ["20" "0"])
    (mkRepeatCustomBind ["Mod"] "O" null "resizeactive" ["0" "-20"])
    (mkRepeatCustomBind ["Mod"] "I" null "resizeactive" ["0" "20"])
    (mkSimpleCustomBind ["Mod" "ALT"] "J" null "layoutmsg" ["preselect" "l"])
    (mkSimpleCustomBind ["Mod" "ALT"] "K" null "layoutmsg" ["preselect" "d"])
    (mkSimpleCustomBind ["Mod" "ALT"] "L" null "layoutmsg" ["preselect" "u"])
    (mkSimpleCustomBind ["Mod" "ALT"] "semicolon" null "layoutmsg" ["preselect" "r"])
    (mkSimpleCustomBind ["Mod" "ALT"] "H" null "layoutmsg" ["preselect" "n"])
    (
      if config.mods.hypr.hyprland.hyprspaceEnable
      then {
        modKeys = ["Mod"];
        key = "W";
        command.hyprland = "overview:toggle";
        args = [];
      }
      else {}
    )
  ];
}
