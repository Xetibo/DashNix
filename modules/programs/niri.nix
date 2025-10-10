{
  mkDashDefault,
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  defaultWmConf = import ../../lib/wm.nix;
in {
  options.mods.niri = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Enable Niri
      '';
    };
    useDefaultConfig = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Use preconfigured Niri config.
      '';
    };
    customConfig = lib.mkOption {
      default = '''';
      example = '''';
      type = lib.types.lines;
      description = ''
        Custom Niri configuration.
        Will be merged with default configuration if enabled.
      '';
    };
  };

  config = lib.mkIf config.mods.niri.enable (
    lib.optionalAttrs (options ? wayland.windowManager.hyprland) {
      # TODO deduplicate and abstract away base window management config
      # install Niri related packages
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

        niri
        xwayland-satellite
      ];

      xdg.configFile."niri/config.kdl" = let
        mkNiriMod = mods:
          builtins.map (mod:
            if mod == "Mod"
            then config.mods.wm.modKey + "+"
            else "${mod}" + "+")
          mods
          |> lib.strings.concatStringsSep "";
        mkNiriArg = args:
          if args != []
          then let
            concatCommand = lib.strings.concatStringsSep " " args;
            validCommand = builtins.replaceStrings [''"''] [''\"''] concatCommand;
          in "\"${validCommand}\""
          else "";
        mkNiriCommand = bind: let
          args = bind.args or [];
        in
          if bind.command == "quit"
          then "quit;"
          else if bind.command == "killActive"
          then "close-window;"
          else if bind.command == "moveFocusTop"
          then "focus-window-up;"
          else if bind.command == "focusWorkspace"
          then "focus-workspace" + " " + mkNiriArg args + ";"
          else if bind.command == "moveWindowRight"
          then "move-column-right-or-to-monitor-right;"
          else if bind.command == "moveWindowDown"
          then "move-window-down;"
          else if bind.command == "moveWindowLeft"
          then "move-column-left-or-to-monitor-left;"
          else if bind.command == "moveWindowUp"
          then "move-window-up;"
          else if bind.command == "moveFocusUp"
          then "focus-window-up;"
          else if bind.command == "moveFocusRight"
          then "focus-column-or-monitor-right;"
          else if bind.command == "moveFocusDown"
          then "focus-window-down;"
          else if bind.command == "moveFocusLeft"
          then "focus-column-or-monitor-left;"
          else if bind.command == "toggleFloating"
          then "toggle-window-floating;"
          else if bind.command == "toggleFullscreen"
          then "fullscreen-window;"
          else if bind.command == "moveToWorkspace"
          then "move-window-to-workspace" + " " + mkNiriArg args + ";"
          else if bind.command == "spawn"
          then "spawn" + " " + mkNiriArg args + ";"
          else if bind.command == "spawn-sh"
          then "spawn-sh" + " " + mkNiriArg args + ";"
          else if bind.command.niri != null
          then bind.command.niri + " " + mkNiriArg args + ";"
          else "";

        mkNiriBinds = cfg:
          ''            binds {
          ''
          + (
            (
              builtins.map (
                bind:
                /*
                kdl
                */
                  if bind ? key && bind ? command
                  then ''
                    ${mkNiriMod (bind.modKeys or [])}${bind.key} ${
                      if
                        bind ? meta
                        && bind.meta ? niri
                      then
                        (
                          if
                            bind.meta.niri ? desc
                            && bind.meta.niri.desc != ""
                          then "hotkey-overlay-title=\"" + bind.meta.niri.desc + "\""
                          else ""
                        )
                        + " "
                        + (
                          if
                            bind.meta.niri ? repeat
                            && bind.meta.niri.repeat
                          then "repeat=true"
                          else "repeat=false"
                        )
                        + " "
                        + (
                          if
                            bind.meta.niri ? allowWhileLocked
                            && bind.meta.niri.allowWhileLocked
                          then "allow-when-locked=true"
                          else ""
                        )
                        + " "
                        + (
                          if
                            bind.meta.niri ? allowInhibit
                            && bind.meta.niri.allowInhibit
                          then "allow-inhibiting=true"
                          else "allow-inhibiting=false"
                        )
                      else ""
                    } { ${
                      mkNiriCommand bind
                    } }
                  ''
                  else ''''
              )
              ((
                  cfg.mods.wm.binds
                  ++ (
                    if cfg.mods.wm.useDefaultBinds
                    then defaultWmConf.defaultBinds cfg
                    else []
                  )
                )
                |> builtins.filter (bind: !(hasInvalidCustomCommand bind)))
            )
            |> lib.strings.concatLines
          )
          + ''
            }
          '';
        mkVrr = vrr:
          if vrr
          then "true"
          else "false";
        mkNiriMonitors = cfg:
          (builtins.map (
              monitor:
              # TODO vrr
              /*
              kdl
              */
              ''
                output "${monitor.name}" {
                    variable-refresh-rate on-demand=${mkVrr monitor.vrr}
                    mode "${builtins.toString monitor.resolutionX}x${builtins.toString monitor.resolutionY}@${builtins.toString monitor.refreshrate}"
                    scale ${builtins.toString monitor.scale}
                    transform "${
                  if (monitor.transform == "0")
                  then "normal"
                  else monitor.transform
                }"
                    position x=${builtins.toString monitor.positionX} y=${builtins.toString monitor.positionY}
                }
              ''
            )
            cfg.mods.wm.monitors)
          |> lib.strings.concatLines;
        mkNiriWorkspaces = cfg:
          (builtins.map (
              workspace:
              /*
              kdl
              */
              ''
                workspace "${workspace.name}" {
                    open-on-output "${workspace.monitor}"
                }
              ''
            )
            cfg.mods.wm.workspaces)
          |> lib.strings.concatLines;
        mkNiriWindowRules = cfg: (
          (
            builtins.map (
              rule:
              /*
              kdl
              */
              ''
                window-rule {
                    ${rule}
                }
              ''
            )
            (
              cfg.mods.wm.windowRules.niri
              ++ (
                if cfg.mods.wm.useDefaultWindowRules
                then defaultWmConf.defaultWindowRules.niri
                else []
              )
            )
          )
          |> lib.strings.concatLines
        );
        hasInvalidCustomCommand = bind: !(bind ? command) || (!(builtins.isString bind.command) && bind.command.niri or null == null);
        mkNiriEnv = config: let
          defaultEnv =
            if config.mods.wm.useDefaultEnv
            then defaultWmConf.defaultEnv config
            else {
              all = {};
              niri = {};
            };
          userEnv =
            if config.mods.wm.env ? all
            then config.mods.wm.env.all // config.mods.wm.env.niri
            else config.mods.wm.env;
          env =
            userEnv
            // defaultEnv.all
            // defaultEnv.niri;
        in
          ''
            environment {
          ''
          + (
            lib.attrsets.mapAttrsToList (
              name: value: "${name} \"${value}\""
            )
            env
            |> lib.strings.concatLines
          )
          + ''
            }
          '';
        mkNiriAutoStart = config: let
          defaultStartup =
            if config.mods.wm.useDefaultStartup
            then defaultWmConf.defaultStartup config
            else {
              all = {};
              niri = {};
            };
          userStartup =
            if config.mods.wm.startup ? all
            then config.mods.wm.startup.all ++ config.mods.wm.startup.niri
            else config.mods.wm.startup;
          autoStart = userStartup ++ defaultStartup.all ++ defaultStartup.niri;
        in
          (builtins.map (value: "spawn-at-startup \"${value}\"")
            autoStart)
          |> lib.strings.concatLines;
        defaultConfig =
          /*
          kdl
          */
          ''
            input {
                keyboard {
                    xkb {
                        layout "enIntUmlaut"
                    }
                    repeat-delay 200
                    repeat-rate 25
                    numlock
                }

                touchpad {
                    tap
                    natural-scroll
                }

                mouse {
                    accel-speed 0.2
                    accel-profile "flat"
                }

                focus-follows-mouse max-scroll-amount="25%"
            }

            layout {
                // Set gaps around windows in logical pixels.
                gaps 10
                center-focused-column "never"
                always-center-single-column

                preset-column-widths {
                    proportion 0.33333
                    proportion 0.5
                    proportion 1.0
                }

                default-column-width { proportion 0.5; }
                focus-ring {
                    width 3
                    inactive-color "#505050"
                    active-gradient from="#ff0000" to="#00ff00" angle=45
                }

                border {
                    off
                }

                // You can enable drop shadows for windows.
                shadow {
                    on
                    softness 30
                    spread 5
                    offset x=0 y=5
                    color "#0007"
                }
            }

            ${
              if config.mods.gpu.nvidia.enable
              then ''
                debug {
                  wait-for-frame-completion-before-queueing
                }
              ''
              else ''''
            }

            // Autostart

            hotkey-overlay {
                skip-at-startup
            }

            prefer-no-csd
          ''
          + mkNiriMonitors config
          + mkNiriBinds config
          + mkNiriWorkspaces config
          + mkNiriWindowRules config
          + mkNiriEnv config
          + mkNiriAutoStart config;
      in
        mkDashDefault {
          text =
            if config.mods.niri.useDefaultConfig
            then defaultConfig + config.mods.niri.customConfig
            else config.mods.niri.customConfig;
        };
    }
  );
}
