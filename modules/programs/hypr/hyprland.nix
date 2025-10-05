{
  mkDashDefault,
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  defaultWmConf = import ../../../lib/wm.nix {inherit lib;};
in {
  options.mods.hypr.hyprland = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Enable Hyprland
      '';
    };
    noAtomic = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = ''
        Use tearing (Warning, can be buggy)
      '';
    };
    useIronbar = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Whether to use ironbar in hyprland.
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

  config = lib.mkIf config.mods.hypr.hyprland.enable (
    lib.optionalAttrs (options ? wayland.windowManager.hyprland) {
      # install Hyprland related packages
      home.packages = with pkgs; [
        xorg.xprop
        grim
        slurp
        satty
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
        kdePackages.xdg-desktop-portal-kde
        xdg-desktop-portal-shana
        copyq
        wl-clipboard
        hyprcursor
        hyprpicker
      ];

      wayland.windowManager.hyprland = let
        mkWorkspace = workspaces:
          builtins.map (workspace: let
            default =
              if workspace.default
              then ",default:true"
              else "";
          in "${workspace.name},monitor:${workspace.monitor}${default}")
          workspaces;
        mkTransform = transform:
          if transform == "0"
          then 0
          else if transform == "90"
          then 1
          else if transform == "180"
          then 2
          else if transform == "270"
          then 3
          else 4;
        mkVrr = vrr:
          if vrr
          then "1"
          else "0";
        mkMonitors = monitors:
          builtins.map (
            monitor: "${monitor.name},${builtins.toString monitor.resolutionX}x${builtins.toString monitor.resolutionY}@${builtins.toString monitor.refreshrate},${builtins.toString monitor.positionX}x${builtins.toString monitor.positionY},${builtins.toString monitor.scale}, transform,${builtins.toString (mkTransform monitor.transform)}, vrr,${mkVrr monitor.vrr}"
          )
          monitors;

        mkMods = bind: let
          mods = bind.modKeys or [];
        in
          builtins.map (mod:
            if mod == "Mod"
            then (lib.strings.toUpper config.mods.wm.modKey) + " "
            else lib.strings.toUpper mod)
          mods
          |> lib.strings.concatStringsSep "";
        mkArgs = args:
          if args != []
          then (lib.strings.concatStringsSep " " args)
          else "";
        shouldRepeat = bind: bind ? meta && bind.meta ? hyprland && bind.meta.hyprland ? repeat && bind.meta.hyprland.repeat;

        defaultBinds = cfg:
          if cfg.mods.wm.useDefaultBinds
          then defaultWmConf.defaultBinds cfg
          else [];

        mkEBinds = cfg: let
          binds = cfg.mods.wm.binds ++ defaultBinds cfg;
        in
          binds
          |> builtins.filter (bind: bind ? command && shouldRepeat bind && !hasInvalidCustomCommand bind)
          |> builtins.map (
            bind: "${mkMods bind},${bind.key},${mkCommand bind}"
          );
        mkBinds = cfg: let
          binds = cfg.mods.wm.binds ++ defaultBinds cfg;
        in
          binds
          |> builtins.filter (bind: bind ? command && !(shouldRepeat bind) && !hasInvalidCustomCommand bind)
          |> builtins.map (
            bind: "${mkMods bind},${bind.key},${mkCommand bind}"
          );
        mkCommand = bind: let
          inherit (bind) args;
        in
          if bind.command == "quit"
          then "exit"
          else if bind.command == "killActive"
          then "killactive"
          else if bind.command == "moveWindowRight"
          then "movewindow,r"
          else if bind.command == "moveWindowDown"
          then "movewindow,d"
          else if bind.command == "moveWindowLeft"
          then "movewindow,l"
          else if bind.command == "moveWindowUp"
          then "movewindow,u"
          else if bind.command == "moveFocusUp"
          then "movefocus,u"
          else if bind.command == "moveFocusRight"
          then "movefocus,r"
          else if bind.command == "moveFocusDown"
          then "movefocus,d"
          else if bind.command == "moveFocusLeft"
          then "movefocus,l"
          else if bind.command == "toggleFloating"
          then "togglefloating"
          else if bind.command == "toggleFullscreen"
          then "fullscreen"
          else if bind.command == "focusWorkspace"
          then "workspace" + "," + mkArgs args
          else if bind.command == "moveToWorkspace"
          then "movetoworkspace" + "," + mkArgs args
          else if bind.command == "spawn"
          then "exec" + "," + mkArgs args
          else if bind.command == "spawn-sh"
          then "exec" + "," + mkArgs args
          else bind.command.hyprland + "," + mkArgs args;
        hasInvalidCustomCommand = bind: !(builtins.isString bind.command) && bind.command.hyprland or null == null;

        mkEnv = config: let
          defaultEnv =
            if config.mods.wm.useDefaultEnv
            then defaultWmConf.defaultEnv config
            else {
              all = {};
              hyprland = {};
            };
          userEnv =
            if config.mods.wm.env ? all
            then config.mods.wm.env.all // config.mods.wm.env.hyprland
            else config.mods.wm.env;
          env = userEnv // defaultEnv.all // defaultEnv.hyprland;
        in
          lib.attrsets.mapAttrsToList (
            name: value: "${name},${value}"
          )
          env;
        mkAutoStart = config: let
          defaultStartup =
            if config.mods.wm.useDefaultStartup
            then defaultWmConf.defaultStartup config
            else {
              all = [];
              hyprland = [];
            };
          userStartup =
            if config.mods.wm.startup ? all
            then config.mods.wm.startup.all ++ config.mods.wm.startup.hyprland
            else config.mods.wm.startup;
          autoStart = userStartup ++ defaultStartup.all ++ defaultStartup.hyprland;
        in
          autoStart;
        mkWindowRule = config: let
          defaultWindowRules =
            if config.mods.wm.useDefaultWindowRules
            then defaultWmConf.defaultWindowRules.hyprland
            else [];
        in
          # defaultWindowRules ++ config.mods.wm.windowRules.hyprland;
          defaultWindowRules;
      in {
        enable = true;
        package = mkDashDefault pkgs.hyprland;
        plugins =
          [
            (lib.mkIf config.mods.hypr.hyprland.hyprspaceEnable pkgs.hyprlandPlugins.hyprspace)
          ]
          ++ config.mods.hypr.hyprland.plugins;
        settings =
          if config.mods.hypr.hyprland.useDefaultConfig
          then
            lib.mkMerge
            [
              {
                "$mod" = mkDashDefault config.mods.wm.modKey;

                bindm = [
                  "$mod, mouse:272, movewindow"
                  "$mod, mouse:273, resizeactive"
                ];

                general = {
                  gaps_out = mkDashDefault "3,5,5,5";
                  border_size = mkDashDefault 3;
                  "col.active_border" = lib.mkOverride 51 "0xFFFF0000 0xFF00FF00 0xFF0000FF 45deg";
                  allow_tearing = lib.mkIf config.mods.hypr.hyprland.noAtomic true;
                };

                decoration = {
                  rounding = mkDashDefault 4;
                };

                render = {
                  direct_scanout = mkDashDefault config.mods.gaming.enable;
                };

                animations = {
                  bezier = mkDashDefault "overshot, 0.05, 0.9, 0.1, 1.2";
                  animation = [
                    "windowsMove,1,4,default"
                    "windows,1,3,overshot,slide bottom"
                    "windowsOut,1,7,default,popin 70%"
                    "border,1,4,default"
                    "fade,1,7,default"
                    "workspaces,1,4,default"
                    "layers,1,2,default,slide"
                  ];
                };

                dwindle = {
                  preserve_split = mkDashDefault true;
                  pseudotile = mkDashDefault 0;
                  permanent_direction_override = mkDashDefault false;
                };

                input = {
                  kb_layout = mkDashDefault "${config.mods.xkb.layout}";
                  kb_variant = mkDashDefault "${config.mods.xkb.variant}";
                  repeat_delay = mkDashDefault 200;
                  force_no_accel = mkDashDefault true;
                  touchpad = {
                    natural_scroll = mkDashDefault true;
                    tap-to-click = mkDashDefault true;
                    tap-and-drag = mkDashDefault true;
                  };
                };

                misc = {
                  animate_manual_resizes = mkDashDefault 1;
                  enable_swallow = mkDashDefault true;
                  disable_splash_rendering = mkDashDefault true;
                  disable_hyprland_logo = mkDashDefault true;
                  swallow_regex = mkDashDefault "^(.*)(kitty)(.*)$";
                  initial_workspace_tracking = mkDashDefault 1;
                  # just doesn't work
                  enable_anr_dialog = false;
                };

                cursor = {
                  enable_hyprcursor = mkDashDefault true;
                  no_hardware_cursors = mkDashDefault (
                    if config.mods.gpu.nvidia.enable
                    then 2
                    else 0
                  );
                  # done with nix, this would break the current setup otherwise
                  sync_gsettings_theme = mkDashDefault false;
                };

                gesture = [
                  "3, horizontal, workspace"
                ];

                layerrule = [
                  # layer rules
                  # mainly to disable animations within slurp and grim
                  "noanim, selection"
                ];

                workspace = mkDashDefault (mkWorkspace config.mods.wm.workspaces);
                monitor = mkDashDefault (mkMonitors config.mods.wm.monitors);
                env = mkDashDefault (mkEnv config);
                bind = mkDashDefault (mkBinds config);
                binde = mkDashDefault (mkEBinds config);
                windowrule = mkDashDefault (mkWindowRule config);
                exec-once = mkDashDefault (mkAutoStart config);
                plugin = config.mods.hypr.hyprland.pluginConfig;
              }
              config.mods.hypr.hyprland.customConfig
            ]
          else lib.mkForce config.mods.hypr.hyprland.customConfig;
      };
    }
  );
}
