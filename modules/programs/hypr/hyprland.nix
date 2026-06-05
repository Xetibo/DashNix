{
  mkDashDefault,
  config,
  lib,
  options,
  pkgs,
  inputs,
  system,
  ...
}: let
  defaultWmConf = import ../../../lib/wm.nix;
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
      default = false;
      example = true;
      type = lib.types.bool;
      description = ''
        Whether to use ironbar in hyprland.
      '';
    };
    useOxiBar = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Whether to use oxibar in hyprland.
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
    lib.optionalAttrs (options ? stylix.targets.hyprland) {
      stylix.targets.hyprland = {
        enable = false;
      };
      services.hyprpaper.enable = true;
    }
    // lib.optionalAttrs (options ? wayland.windowManager.hyprland) {
      # install Hyprland related packages
      home.packages = with pkgs; [
        xprop
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
        modKey = lib.strings.toUpper config.mods.wm.modKey;

        # --------------- Monitors ---------------
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

        mkMonitors = monitors:
          builtins.map (monitor: {
            output = monitor.name;
            mode = "${builtins.toString monitor.resolutionX}x${builtins.toString monitor.resolutionY}@${builtins.toString monitor.refreshrate}";
            position = "${builtins.toString monitor.positionX}x${builtins.toString monitor.positionY}";
            scale = monitor.scale;
            transform = mkTransform monitor.transform;
            vrr =
              if monitor.vrr
              then 1
              else 0;
          })
          monitors;

        # --------------- Workspaces ---------------
        mkWorkspace = workspaces:
          builtins.map (workspace:
            {
              workspace = workspace.name;
              monitor = workspace.monitor;
            }
            // lib.optionalAttrs workspace.default {default = true;})
          workspaces;

        # --------------- Window Rules ---------------
        # Parse legacy "match:class Foo, float on" strings into attrsets
        parseWindowRule = ruleStr: let
          # e.g. "match:class OxiCalc, float on"
          parts = lib.strings.splitString ", " ruleStr;
          matchPart = builtins.head parts;
          # matchPart: "match:class OxiCalc"
          matchKV = lib.strings.removePrefix "match:" matchPart;
          matchParts = lib.strings.splitString " " matchKV;
          matchKey = builtins.head matchParts;
          matchVal = lib.strings.concatStringsSep " " (builtins.tail matchParts);
          ruleParts = builtins.tail parts;
          ruleStr' = lib.strings.concatStringsSep ", " ruleParts;
          # ruleStr': "float on" or "center on" or "workspace 10 silent"
          ruleWords = lib.strings.splitString " " ruleStr';
          ruleKey = builtins.head ruleWords;
          ruleVal = lib.strings.concatStringsSep " " (builtins.tail ruleWords);
        in
          {
            match = {${matchKey} = matchVal;};
          }
          // (
            if ruleKey == "float"
            then {float = true;}
            else if ruleKey == "center"
            then {center = true;}
            else if ruleKey == "workspace"
            then {workspace = ruleVal;}
            else {${ruleKey} = ruleVal;}
          );

        mkWindowRule = cfg: let
          defaultWindowRules =
            if cfg.mods.wm.useDefaultWindowRules
            then defaultWmConf.defaultWindowRules.hyprland
            else [];
          userWindowRules = cfg.mods.wm.windowRules.hyprland or [];
          allRules = defaultWindowRules ++ userWindowRules;
        in
          builtins.map (
            rule:
              if builtins.isString rule
              then parseWindowRule rule
              else rule
          )
          allRules;

        # --------------- Env ---------------
        mkEnv = cfg: let
          defaultEnv =
            if cfg.mods.wm.useDefaultEnv
            then defaultWmConf.defaultEnv cfg
            else {
              all = {};
              hyprland = {};
            };
          userEnv =
            if cfg.mods.wm.env ? all
            then cfg.mods.wm.env.all // cfg.mods.wm.env.hyprland
            else cfg.mods.wm.env;
          env = userEnv // defaultEnv.all // defaultEnv.hyprland;
        in
          lib.attrsets.mapAttrsToList (name: value: {_args = [name value];}) env;

        # --------------- AutoStart ---------------
        mkAutoStart = cfg: let
          defaultStartup =
            if cfg.mods.wm.useDefaultStartup
            then defaultWmConf.defaultStartup cfg
            else {
              all = [];
              hyprland = [];
            };
          userStartup =
            if cfg.mods.wm.startup ? all
            then cfg.mods.wm.startup.all ++ cfg.mods.wm.startup.hyprland
            else cfg.mods.wm.startup;
        in
          builtins.filter (s: s != "") (userStartup ++ defaultStartup.all ++ defaultStartup.hyprland);

        # --------------- Binds (Lua extraConfig) ---------------
        defaultBinds = cfg:
          if cfg.mods.wm.useDefaultBinds
          then defaultWmConf.defaultBinds cfg
          else [];

        shouldRepeat = bind:
          bind ? meta && bind.meta ? hyprland && bind.meta.hyprland ? repeat && bind.meta.hyprland.repeat == true;

        hasInvalidCustomCommand = bind:
          !(builtins.isString bind.command) && bind.command.hyprland or null == null;

        # Build key string: "SUPER + Q", "SUPER + SHIFT + 1", etc.
        mkKeyStr = bind: let
          mods = bind.modKeys or [];
          modStrs =
            builtins.map (
              mod:
                if mod == "Mod"
                then modKey
                else lib.strings.toUpper mod
            )
            mods;
          allParts = modStrs ++ [bind.key];
        in
          lib.strings.concatStringsSep " + " allParts;

        # Build dispatcher string for hl.dsp.*
        mkDispatcher = bind: let
          args = bind.args or [];
          # Serialize a value as a Lua literal.
          # Uses builtins.toJSON for strings so special chars (quotes, backslashes, etc.)
          # are properly escaped — JSON string syntax is valid Lua string syntax.
          mkLuaVal = x:
            if builtins.isInt x || builtins.isFloat x || builtins.isBool x
            then builtins.toString x
            else if builtins.isString x && builtins.match "^-?[0-9]+$" x != null
            then x # numeric string → unquoted
            else builtins.toJSON x; # produces "..." with proper escaping
          mkArgsStr = a: lib.strings.concatStringsSep ", " (builtins.map mkLuaVal a);
        in
          if bind.command == "quit"
          then "hl.dsp.exit()"
          else if bind.command == "killActive"
          then "hl.dsp.window.close()"
          else if bind.command == "moveWindowRight"
          then ''hl.dsp.window.move({ direction = "right" })''
          else if bind.command == "moveWindowDown"
          then ''hl.dsp.window.move({ direction = "down" })''
          else if bind.command == "moveWindowLeft"
          then ''hl.dsp.window.move({ direction = "left" })''
          else if bind.command == "moveWindowUp"
          then ''hl.dsp.window.move({ direction = "up" })''
          else if bind.command == "moveFocusUp"
          then ''hl.dsp.focus({ direction = "up" })''
          else if bind.command == "moveFocusRight"
          then ''hl.dsp.focus({ direction = "right" })''
          else if bind.command == "moveFocusDown"
          then ''hl.dsp.focus({ direction = "down" })''
          else if bind.command == "moveFocusLeft"
          then ''hl.dsp.focus({ direction = "left" })''
          else if bind.command == "toggleFloating"
          then ''hl.dsp.window.float({ action = "toggle" })''
          else if bind.command == "toggleFullscreen"
          then "hl.dsp.window.fullscreen()"
          else if bind.command == "focusWorkspace"
          then ''hl.dsp.focus({ workspace = ${builtins.head args} })''
          else if bind.command == "moveToWorkspace"
          then ''hl.dsp.window.move({ workspace = ${builtins.head args} })''
          else if bind.command == "spawn"
          then ''hl.dsp.exec_cmd(${mkArgsStr args})''
          else if bind.command == "spawn-sh"
          then ''hl.dsp.exec_cmd(${mkArgsStr args})''
          else let
            hyprCmd = bind.command.hyprland;
            argsStr = mkArgsStr args;
          in
            if hyprCmd == "movetoworkspacesilent"
            then ''hl.dsp.window.move({ workspace = ${builtins.head args}, follow = false })''
            else if hyprCmd == "resizeactive"
            then let
              x = builtins.elemAt args 0;
              y = builtins.elemAt args 1;
            in ''hl.dsp.window.resize({ x = ${x}, y = ${y}, relative = true })''
            else if hyprCmd == "layoutmsg"
            then ''hl.dsp.layout(${mkArgsStr args})''
            else
              # generic fallback - use legacy hyprctl dispatch
              ''hl.dsp.layout("${hyprCmd}"${
                  if args != []
                  then ", " + argsStr
                  else ""
                })'';

        # Build opts string for hl.bind
        mkBindOpts = bind: let
          repeat = shouldRepeat bind;
          isMouse = lib.strings.hasPrefix "mouse:" (bind.key or "");
        in
          if repeat && isMouse
          then ", { repeating = true, mouse = true }"
          else if repeat
          then ", { repeating = true }"
          else if isMouse
          then ", { mouse = true }"
          else "";

        mkBindLines = cfg: let
          binds = cfg.mods.wm.binds ++ defaultBinds cfg;
          validBinds =
            builtins.filter (
              bind:
                bind ? command && bind ? key && !(hasInvalidCustomCommand bind)
            )
            binds;
        in
          builtins.map (
            bind: ''hl.bind("${mkKeyStr bind}", ${mkDispatcher bind}${mkBindOpts bind})''
          )
          validBinds;

        # Generate the full extraConfig for binds
        mkBindsExtraConfig = cfg:
        # Mouse drag/resize binds
          ''hl.bind("${modKey} + mouse:272", hl.dsp.window.drag(), { mouse = true })''
          + "\n"
          + ''hl.bind("${modKey} + mouse:273", hl.dsp.window.resize(), { mouse = true })''
          + "\n"
          + lib.strings.concatStringsSep "\n" (mkBindLines cfg)
          + "\n";
      in {
        enable = true;
        # package = pkgs.hyprland;
        package = inputs.hyprland.packages.${system}.default;
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
                curve = {
                  _args = [
                    "overshot"
                    {
                      type = "bezier";
                      points = [[0.05 0.9] [0.1 1.2]];
                    }
                  ];
                };

                animation = [
                  {
                    leaf = "windowsMove";
                    enabled = true;
                    speed = 4;
                    bezier = "default";
                  }
                  {
                    leaf = "windows";
                    enabled = true;
                    speed = 3;
                    style = "slide bottom";
                    bezier = "overshot";
                  }
                  {
                    leaf = "windowsOut";
                    enabled = true;
                    speed = 7;
                    style = "popin 80%";
                    bezier = "overshot";
                  }
                  {
                    leaf = "border";
                    enabled = true;
                    speed = 4;
                    bezier = "default";
                  }
                  {
                    leaf = "fade";
                    enabled = true;
                    speed = 7;
                    bezier = "default";
                  }
                  {
                    leaf = "workspaces";
                    enabled = true;
                    speed = 4;
                    bezier = "default";
                  }
                  {
                    leaf = "layers";
                    enabled = true;
                    speed = 2;
                    style = "slide";
                    bezier = "default";
                  }
                ];

                # All Hyprland config options go under hl.config(...)
                config = {
                  general = {
                    gaps_out = mkDashDefault {
                      top = 3;
                      right = 5;
                      bottom = 5;
                      left = 5;
                    };
                    border_size = mkDashDefault 3;
                    col = {
                      active_border = lib.mkOverride 51 {
                        colors = ["0xFFFF0000" "0xFF00FF00" "0xFF0000FF"];
                        angle = 45;
                      };
                      inactive_border = mkDashDefault "rgb(45475a)";
                    };
                    allow_tearing = lib.mkIf config.mods.hypr.hyprland.noAtomic true;
                  };

                  decoration = {
                    rounding = mkDashDefault 4;
                    shadow = {
                      color = mkDashDefault "rgba(1e1e2e99)";
                    };
                  };

                  render = {
                    direct_scanout = mkDashDefault config.mods.gaming.enable;
                  };

                  dwindle = {
                    preserve_split = mkDashDefault true;
                    permanent_direction_override = mkDashDefault false;
                  };

                  input = {
                    kb_layout = mkDashDefault "${config.mods.xkb.layout}";
                    kb_variant = mkDashDefault "${config.mods.xkb.variant}";
                    repeat_delay = mkDashDefault 200;
                    force_no_accel = mkDashDefault true;
                    touchpad = {
                      natural_scroll = mkDashDefault true;
                      tap_to_click = mkDashDefault true;
                      tap_and_drag = mkDashDefault true;
                    };
                  };

                  misc = {
                    animate_manual_resizes = mkDashDefault 1;
                    enable_swallow = mkDashDefault true;
                    disable_splash_rendering = mkDashDefault true;
                    disable_hyprland_logo = mkDashDefault true;
                    disable_xdg_env_checks = mkDashDefault true;
                    disable_scale_notification = mkDashDefault true;
                    swallow_regex = mkDashDefault "^(.*)(kitty)(.*)$";
                    initial_workspace_tracking = mkDashDefault 1;
                    #just doesn't work
                    enable_anr_dialog = false;
                  };

                  cursor = {
                    enable_hyprcursor = mkDashDefault true;
                    no_hardware_cursors = mkDashDefault (
                      if config.mods.gpu.nvidia.enable
                      then 2
                      else 0
                    );
                    #done with nix, this would break the current setup otherwise
                    sync_gsettings_theme = mkDashDefault false;
                  };

                  group = {
                    col = {
                      border_active = mkDashDefault "rgb(cba6f7)";
                      border_inactive = mkDashDefault "rgb(45475a)";
                      border_locked_active = mkDashDefault "rgb(94e2d5)";
                    };
                    groupbar = {
                      col = {
                        active = mkDashDefault "rgb(cba6f7)";
                        inactive = mkDashDefault "rgb(45475a)";
                      };
                      text_color = mkDashDefault "rgb(cdd6f4)";
                    };
                  };
                };

                gesture = {
                  fingers = 3;
                  direction = "horizontal";
                  action = "workspace";
                };

                layer_rule = [
                  # layer rules - mainly to disable animations within slurp and grim
                  {
                    match = {namespace = "selection";};
                    no_anim = true;
                  }
                ];

                workspace_rule = mkWorkspace config.mods.wm.workspaces;
                monitor = mkMonitors config.mods.wm.monitors;
                env = mkEnv config;
                window_rule = mkWindowRule config;
                exec_cmd = mkAutoStart config;
                plugin = lib.mkIf (config.mods.hypr.hyprland.pluginConfig != {}) config.mods.hypr.hyprland.pluginConfig;
              }
              config.mods.hypr.hyprland.customConfig
            ]
          else lib.mkForce config.mods.hypr.hyprland.customConfig;

        extraConfig =
          lib.mkIf config.mods.hypr.hyprland.useDefaultConfig
          (mkBindsExtraConfig config);
      };
    }
  );
}
