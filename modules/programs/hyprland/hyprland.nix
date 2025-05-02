{
  config,
  lib,
  options,
  pkgs,
  inputs,
  ...
}: let
  browserName =
    if (builtins.isString config.mods.homePackages.browser)
    then config.mods.homePackages.browser
    else if config.mods.homePackages.browser ? meta && config.mods.homePackages.browser.meta ? mainProgram
    then config.mods.homePackages.browser.meta.mainProgram
    else config.mods.homePackages.browser.pname;
in {
  options.mods.hyprland = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Enable Hyprland
      '';
    };
    monitor = lib.mkOption {
      default = [
        # main monitor
        "${config.conf.defaultMonitor},${config.conf.defaultMonitorMode},0x0,${config.conf.defaultMonitorScale}"
        # all others
        ",highrr,auto,1"
      ];
      example = ["DP-1,3440x1440@180,2560x0,1,vrr,0"];
      type = with lib.types; listOf str;
      description = ''
        The monitor configuration for hyprland.
      '';
    };
    workspace = lib.mkOption {
      default = [];
      example = ["2,monitor:DP-1, default:true"];
      type = with lib.types; listOf str;
      description = ''
        The workspace configuration for hyprland.
      '';
    };
    noAtomic = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = ''
        Use tearing
      '';
    };
    extraAutostart = lib.mkOption {
      default = [];
      example = ["your application"];
      type = lib.types.listOf lib.types.str;
      description = ''
        Extra exec_once.
      '';
    };
    useDefaultConfig = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Use preconfigured Hyprland config.
      '';
    };
    customConfig = lib.mkOption {
      default = {};
      example = {};
      type = with lib.types; attrsOf anything;
      description = ''
        Custom Hyprland configuration.
        Will be merged with default configuration if enabled.
      '';
    };
    plugins = lib.mkOption {
      default = [];
      example = [];
      type = with lib.types; listOf package;
      description = ''
        Plugins to be added to Hyprland.
      '';
    };
    pluginConfig = lib.mkOption {
      default = {};
      example = {};
      type = with lib.types; attrsOf anything;
      description = ''
        Plugin configuration to be added to Hyprland.
      '';
    };
    hyprspaceEnable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      example = true;
      description = ''
        Enables Hyprspace plugin for hyprland.
        Please note, plugins tend to break VERY often.
      '';
    };
  };

  config = lib.mkIf config.mods.hyprland.enable (
    lib.optionalAttrs (options ? wayland.windowManager.hyprland) {
      # install Hyprland related packages
      home.packages = with pkgs; [
        xorg.xprop
        grim
        slurp
        satty
        xdg-desktop-portal-gtk
        # xdg-desktop-portal-hyprland
        copyq
        wl-clipboard
        hyprcursor
        hyprpicker
      ];

      wayland.windowManager.hyprland = {
        enable = true;
        settings =
          if config.mods.hyprland.useDefaultConfig
          then
            lib.mkMerge
            [
              {
                "$mod" = "SUPER";

                bindm = [
                  "$mod, mouse:272, movewindow"
                  "$mod, mouse:273, resizeactive"
                ];

                bind = [
                  # screenshots
                  ''$mod SUPER,S,exec,grim -g "$(slurp)" - | wl-copy''
                  ''$mod SUPERSHIFT,S,exec,grim -g "$(slurp)" - | satty -f -''
                  ''$mod SUPERSHIFTALT,S,exec,grim -c -g "2560,0 3440x1440" - | wl-copy''

                  # regular programs
                  "$mod SUPER,F,exec,${browserName}"
                  (lib.mkIf (
                    browserName == "firefox" || browserName == "zen"
                  ) "$mod SUPERSHIFT,F,exec,${browserName} -p special")
                  "$mod SUPER,T,exec,kitty -1"
                  "$mod SUPER,E,exec,nautilus -w"
                  "$mod SUPER,N,exec,neovide"
                  (lib.mkIf (config.mods.hyprland.anyrun.enable) "$mod SUPER,R,exec,anyrun")
                  (lib.mkIf (config.mods.oxi.oxirun.enable) "$mod SUPER,R,exec,oxirun")
                  (lib.mkIf (config.mods.oxi.oxidash.enable) "$mod SUPER,M,exec,oxidash")
                  (lib.mkIf (config.mods.oxi.oxicalc.enable) "$mod SUPER,G,exec,oxicalc")
                  (lib.mkIf (config.mods.oxi.oxishut.enable) "$mod SUPER,D,exec,oxishut")
                  (lib.mkIf (config.mods.oxi.oxipaste.enable) "$mod SUPER,A,exec,oxipaste-iced")
                  (lib.mkIf (config.mods.oxi.hyprdock.enable) "$mod SUPERSHIFT,P,exec,hyprdock --gui")
                  "$mod SUPERSHIFT,L,exec, playerctl -a pause & hyprlock & systemctl suspend"
                  "$mod SUPERSHIFT,K,exec, playerctl -a pause & hyprlock & systemctl hibernate"

                  # media keys
                  (lib.mkIf config.mods.scripts.audioControl ",XF86AudioMute,exec, audioControl mute")
                  (lib.mkIf config.mods.scripts.audioControl ",XF86AudioLowerVolume,exec, audioControl sink -5%")
                  (lib.mkIf config.mods.scripts.audioControl ",XF86AudioRaiseVolume,exec, audioControl sink +5%")
                  ",XF86AudioPlay,exec, playerctl play-pause"
                  ",XF86AudioNext,exec, playerctl next"
                  ",XF86AudioPrev,exec, playerctl previous"
                  (lib.mkIf config.mods.scripts.changeBrightness ",XF86MonBrightnessDown,exec, changeBrightness brightness 10%-")
                  (lib.mkIf config.mods.scripts.changeBrightness ",XF86MonBrightnessUp,exec, changeBrightness brightness +10%")

                  # hyprland keybinds
                  # misc
                  "$mod SUPER,V,togglefloating,"
                  "$mod SUPER,B,fullscreen,"
                  "$mod SUPER,C,togglesplit"
                  "$mod SUPER,Q,killactive,"
                  "$mod SUPERSHIFTALT,M,exit,"
                  "$mod SUPERSHIFT,W,togglespecialworkspace"

                  # move
                  "$mod SUPER,left,movewindow,l"
                  "$mod SUPER,right,movewindow,r"
                  "$mod SUPER,up,movewindow,u"
                  "$mod SUPER,down,movewindow,d"

                  # workspaces
                  "$mod SUPER,1,workspace,1"
                  "$mod SUPER,2,workspace,2"
                  "$mod SUPER,3,workspace,3"
                  "$mod SUPER,4,workspace,4"
                  "$mod SUPER,5,workspace,5"
                  "$mod SUPER,6,workspace,6"
                  "$mod SUPER,7,workspace,7"
                  "$mod SUPER,8,workspace,8"
                  "$mod SUPER,9,workspace,9"
                  "$mod SUPER,0,workspace,10"

                  # move to workspace
                  "$mod SUPERSHIFT,1,movetoworkspace,1"
                  "$mod SUPERSHIFT,2,movetoworkspace,2"
                  "$mod SUPERSHIFT,3,movetoworkspace,3"
                  "$mod SUPERSHIFT,4,movetoworkspace,4"
                  "$mod SUPERSHIFT,5,movetoworkspace,5"
                  "$mod SUPERSHIFT,6,movetoworkspace,6"
                  "$mod SUPERSHIFT,7,movetoworkspace,7"
                  "$mod SUPERSHIFT,8,movetoworkspace,8"
                  "$mod SUPERSHIFT,9,movetoworkspace,9"
                  "$mod SUPERSHIFT,0,movetoworkspace,10"

                  # move to workspace silent
                  "$mod SUPERSHIFTALT,1,movetoworkspacesilent,1"
                  "$mod SUPERSHIFTALT,2,movetoworkspacesilent,2"
                  "$mod SUPERSHIFTALT,3,movetoworkspacesilent,3"
                  "$mod SUPERSHIFTALT,4,movetoworkspacesilent,4"
                  "$mod SUPERSHIFTALT,5,movetoworkspacesilent,5"
                  "$mod SUPERSHIFTALT,6,movetoworkspacesilent,6"
                  "$mod SUPERSHIFTALT,7,movetoworkspacesilent,7"
                  "$mod SUPERSHIFTALT,8,movetoworkspacesilent,8"
                  "$mod SUPERSHIFTALT,9,movetoworkspacesilent,9"
                  "$mod SUPERSHIFTALT,0,movetoworkspacesilent,10"

                  # preselection
                  "$mod SUPERALT,j,layoutmsg,preselect l"
                  "$mod SUPERALT,k,layoutmsg,preselect d"
                  "$mod SUPERALT,l,layoutmsg,preselect u"
                  "$mod SUPERALT,semicolon,layoutmsg,preselect r"
                  "$mod SUPERALT,h,layoutmsg,preselect n"
                ];

                binde = [
                  # hyprland keybinds
                  # focus
                  "$mod SUPER,J,movefocus,l"
                  "$mod SUPER,semicolon,movefocus,r"
                  "$mod SUPER,L,movefocus,u"
                  "$mod SUPER,K,movefocus,d"

                  # resize
                  "$mod SUPER,U,resizeactive,-20 0"
                  "$mod SUPER,P,resizeactive,20 0"
                  "$mod SUPER,O,resizeactive,0 -20"
                  "$mod SUPER,I,resizeactive,0 20"
                ];

                general = {
                  gaps_out = "3,5,5,5";
                  border_size = 3;
                  "col.active_border" = lib.mkOverride 51 "0xFFFF0000 0xFF00FF00 0xFF0000FF 45deg";
                  # "col.inactive_border" = "0x66333333";
                  allow_tearing = lib.mkIf config.mods.hyprland.noAtomic true;
                };

                decoration = {
                  rounding = 4;
                };

                animations = {
                  bezier = "penguin,0.05,0.9,0.1,1.0";
                  animation = [
                    "windowsMove,1,4,default"
                    "windows,1,7,default,popin 70%"
                    "windowsOut,1,7,default,popin 70%"
                    "border,1,10,default"
                    "fade,1,7,default"
                    "workspaces,1,6,default"
                    "layers,1,3,default,popin"
                  ];
                };

                dwindle = {
                  preserve_split = true;
                  pseudotile = 0;
                  permanent_direction_override = false;
                };

                input = {
                  kb_layout = "${config.mods.xkb.layout}";
                  kb_variant = "${config.mods.xkb.variant}";
                  repeat_delay = 200;
                  force_no_accel = true;
                  touchpad = {
                    natural_scroll = true;
                    tap-to-click = true;
                    tap-and-drag = true;
                  };
                };

                misc = {
                  animate_manual_resizes = 1;
                  enable_swallow = true;
                  disable_splash_rendering = true;
                  disable_hyprland_logo = true;
                  swallow_regex = "^(.*)(kitty)(.*)$";
                  initial_workspace_tracking = 1;
                  # just doesn't work
                  enable_anr_dialog = false;
                };

                cursor = {
                  enable_hyprcursor = true;
                  no_hardware_cursors = lib.mkIf config.mods.gpu.nvidia.enable true;
                  # done with nix, this would break the current setup otherwise
                  sync_gsettings_theme = false;
                };

                gestures = {
                  workspace_swipe = true;
                };

                monitor = config.mods.hyprland.monitor;
                workspace = config.mods.hyprland.workspace;

                env = [
                  "GTK_CSD,0"
                  ''TERM,"kitty /bin/fish"''
                  "XDG_CURRENT_DESKTOP=Hyprland"
                  "XDG_SESSION_TYPE=wayland"
                  "XDG_SESSION_DESKTOP=Hyprland"
                  "HYPRCURSOR_THEME,${config.mods.stylix.cursor.name}"
                  "HYPRCURSOR_SIZE,${toString config.mods.stylix.cursor.size}"
                  "XCURSOR_THEME,${config.mods.stylix.cursor.name}"
                  "XCURSOR_SIZE,${toString config.mods.stylix.cursor.size}"
                  "QT_QPA_PLATFORM,wayland"
                  "QT_QPA_PLATFORMTHEME,qt5ct"
                  "QT_WAYLAND_FORCE_DPI,96"
                  "QT_AUTO_SCREEN_SCALE_FACTOR,0"
                  "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
                  "QT_SCALE_FACTOR,1"
                  ''EDITOR,"neovide --novsync --nofork"''
                  (lib.mkIf config.mods.hyprland.noAtomic "WLR_DRM_NO_ATOMIC,1")
                  "GTK_USE_PORTAL, 1"

                  (lib.mkIf config.mods.gpu.nvidia.enable "LIBVA_DRIVER_NAME,nvidia")
                  (lib.mkIf config.mods.gpu.nvidia.enable "XDG_SESSION_TYPE,wayland")
                  (lib.mkIf config.mods.gpu.nvidia.enable "GBM_BACKEND,nvidia-drm")
                  (lib.mkIf config.mods.gpu.nvidia.enable "__GLX_VENDOR_LIBRARY_NAME,nvidia")
                ];

                layerrule = [
                  # layer rules
                  # mainly to disable animations within slurp and grim
                  "noanim, selection"
                ];

                windowrule = [
                  # window rules
                  "float,class:^(.*)(OxiCalc)(.*)$"
                  "float,class:^(.*)(winecfg.exe)(.*)$"
                  "float,class:^(.*)(copyq)(.*)$"
                  "center,class:^(.*)(swappy)(.*)$"
                  "float,title:^(.*)(reset)(.*)$"
                  "workspace 10 silent,class:^(.*)(steam)(.*)$"
                  "workspace 9 silent,class:^(.*)(dota)(.*)$"
                  "workspace 9 silent,class:^(.*)(battlebits)(.*)$"
                  "workspace 9 silent,class:^(.*)(aoe)(.*)$"
                  "suppressevent fullscreen maximize,class:^(.*)(neovide)(.*)$"
                  "immediate,class:^(.*)(Pal)$"
                  "immediate,class:^(.*)(dota2)$"
                  "immediate,class:^(.*)(needforspeedheat.exe)$"
                ];

                exec-once =
                  [
                    # environment
                    "systemctl --user import-environment"
                    "dbus-update-activation-environment --systemd --all"
                    "hyprctl setcursor Bibata-Modern-Classic 24"

                    # other programs
                    "hyprpaper"
                    "ironbar"
                    "${browserName}"
                    "oxipaste_daemon"
                    "oxinoti"
                  ]
                  ++ config.mods.hyprland.extraAutostart;

                plugin =
                  lib.mkMerge
                  [
                    {
                      hyprspace = lib.mkIf config.mods.hyprland.hyprspaceEnable {
                        bind = [
                          "SUPER, W, overview:toggle, toggle"
                        ];
                      };
                    }
                    config.mods.hyprland.pluginConfig
                  ];
              }
              config.mods.hyprland.customConfig
            ]
          else lib.mkForce config.mods.hyprland.customConfig;
        plugins =
          [
            (lib.mkIf config.mods.hyprland.hyprspaceEnable inputs.Hyprspace.packages.${pkgs.system}.Hyprspace)
          ]
          ++ config.mods.hyprland.plugins;
      };
    }
  );
}
