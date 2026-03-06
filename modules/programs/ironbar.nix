{
  lib,
  config,
  pkgs,
  inputs,
  options,
  mkDashDefault,
  ...
}: let
  inherit (config.conf) username;
  base16 = pkgs.callPackage inputs.base16.lib {};
  scheme = base16.mkSchemeAttrs config.stylix.base16Scheme;
  ironbarDefaultConfig = useBatteryModule: {
    end = [
      (lib.mkIf useBatteryModule
        {
          type = "battery";
          class = "battery";
          icon_size = 0;
          format = "{percentage}%";
          thresholds = {
            warning = 20;
            critical = 5;
          };
        })
      {
        class = "music";
        type = "music";
        format = "";
        truncate = {
          mode = "end";
          max_length = 0;
        };
        icons = {
          play = "";
          pause = "";
        };
        truncate_popup_title = {
          mode = "end";
          max_length = 15;
        };
        truncate_popup_album = {
          mode = "end";
          max_length = 15;
        };
        truncate_popup_artist = {
          mode = "end";
          max_length = 15;
        };
      }
      {
        bar = [
          {
            class = "popup-button";
            label = "";
            on_click = "popup:toggle";
            type = "button";
          }
        ];
        class = "popup-button-box";
        popup = [
          {
            class = "audio-box";
            orientation = "vertical";
            type = "box";
            widgets = [
              {
                class = "audio-button-box";
                orientation = "horizontal";
                type = "box";
                widgets = [
                  {
                    class = "audio-button";
                    label = "";
                    on_click = "!audioControl bluetooth";
                    type = "button";
                  }
                  {
                    class = "audio-button";
                    label = "󰋋";
                    on_click = "!audioControl internal";
                    type = "button";
                  }
                ];
              }
              {
                class = "audio-label";
                label = "Output";
                type = "label";
              }
              {
                class = "audio-slider";
                length = 200;
                on_change = "!pactl set-sink-volume @DEFAULT_SINK@ $0%";
                step = 1.0;
                type = "slider";
                value = "pactl get-sink-volume @DEFAULT_SINK@ | awk -F'/' '{ print $2 }' | tr -d ' %'";
                label = "{{pactl get-sink-volume @DEFAULT_SINK@ | awk -F'/' '{ print $2 }'}}";
              }
              {
                class = "audio-label";
                label = "Input";
                type = "label";
              }
              {
                class = "audio-slider";
                length = 200;
                on_change = "!pactl set-source-volume @DEFAULT_SOURCE@ $0%";
                step = 1.0;
                type = "slider";
                value = "pactl get-source-volume @DEFAULT_SOURCE@ | awk -F'/' '{ print $2 }' | tr -d ' %'";
              }
            ];
          }
        ];
        type = "custom";
      }
      {
        bar = [
          {
            class = "popup-button";
            label = "";
            on_click = "!oxidash";
            type = "button";
          }
        ];
        class = "popup-button-box";
        type = "custom";
      }
      {
        bar = [
          {
            class = "popup-button";
            label = "";
            on_click = "popup:toggle";
            type = "button";
          }
        ];
        type = "custom";
        class = "popup-button-box";
        popup = [
          {
            class = "system-box";
            type = "box";
            widgets = [
              {
                class = "memory-usage";
                format = [
                  "  {cpu_percent}%"
                  "  {memory_used} / {memory_total} GB ({memory_percent}%)"
                  "  {swap_used} / {swap_total} GB ({swap_free} | {swap_percent}%)"
                  "󰥔  {uptime}"
                ];
                direction = "vertical";
                interval = {
                  memory = 30;
                  cpu = 5;
                  temps = 5;
                  disks = 5;
                  network = 5;
                };
                type = "sys_info";
              }
            ];
          }
        ];
      }
      {
        type = "tray";
      }
    ];
    position = "top";
    height = 10;
    anchor_to_edges = true;
    start = [
      {
        type = "workspaces";
        all_monitors = true;
      }
    ];
    center = [
      {
        format = "%I:%M";
        format_popup = "%a %d:%m/%I:%M %p";
        locale = "en_US";
        type = "clock";
      }
    ];
  };
  monitorConfig = useBatteryModule:
    if config.mods.ironbar.ironbarSingleMonitor
    then {
      monitors.${
        if config.mods.wm.monitors != []
        then (builtins.elemAt config.mods.wm.monitors 0).name
        else ""
      } =
        ironbarDefaultConfig useBatteryModule;
    }
    else ironbarDefaultConfig useBatteryModule;
in {
  options.mods = {
    ironbar = {
      enable = lib.mkOption {
        default = false;
        example = true;
        type = lib.types.bool;
        description = "Enables ironbar";
      };
      ironbarSingleMonitor = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = ''
          Whether to use ironbar on a single monitor.
        '';
      };
      useDefaultConfig = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = ''
          Use preconfigured ironbar config.
        '';
      };
      useBatteryModule = lib.mkOption {
        default = false;
        example = true;
        type = lib.types.bool;
        description = "Whether to use the preconfigured battery module.";
      };
      customConfig = lib.mkOption {
        default = {};
        example = {};
        type = with lib.types; attrsOf anything;
        description = ''
          Custom ironbar configuration.
          Will be merged with default configuration if enabled.
        '';
      };
      useDefaultCss = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = ''
          Use preconfigured ironbar css.
        '';
      };
      customCss = lib.mkOption {
        default = '''';
        example = ''
          #window {
            border-radius: none;
          }
        '';
        type = lib.types.lines;
        description = ''
          Custom ironbar css.
          Will be merged with default css if enabled.
        '';
      };
    };
  };
  config = lib.mkIf (config.mods.ironbar.enable || config.mods.hypr.hyprland.useIronbar) (
    lib.optionalAttrs (options ? programs.ironbar) {
      programs.ironbar = {
        package = mkDashDefault pkgs.ironbar;
        enable = true;
        style =
          if config.mods.ironbar.useDefaultCss
          then
            /*
            css
            */
            ''
              @import url("/home/${username}/.config/gtk-3.0/gtk.css");

              @define-color primary #${scheme.base0D};
              @define-color warning #${scheme.base0F};
              @define-color muted-text #${scheme.base05};
              @define-color background #${scheme.base00};
              @define-color secondary-background #${scheme.base02};

              * slider {
                background-color: @muted-text;
              }

              * { padding: 0px; margin: 0px; }

              * {
                transition:
                  background-color 0.15s ease-in-out,
                  color 0.15s ease-in-out,
                  border-color 0.15s ease-in-out;
              }

              .background {
                background-color: rgba(0, 0, 0, 0);
                padding: 0px;
                margin: 0px;
              }

              .focused {
                padding: 0px 5px;
                background-color: @background;
                font-size: 17px;
                border-radius: 10px;
              }

              #bar #end {
                margin: 0px 5px;
                padding: 0px 5px;
                background-color: @background;
                border-radius: 10px;
              }

              .popup-button {
                padding: 0px 5px 0px 2px;
                border-radius: 100%;
                font-size: 13px;
                background-color: @background;
              }

              .popup-button-box {
                padding: 2px 0px;
                margin-right: 4px;
              }

              .custom button {
                background-color: @background;
                color: @primary;
              }

              .custom button:hover {
                background-color: @secondary-background;
              }

              /* audio */
              .audio-box * {
                color: @primary;
              }

              .audio-box {
                padding: 2em;
                background-color: @background;
                border-radius: 20px;
                border: 1px solid @primary;
              }

              .audio-slider {
                padding: 5px;
                margin: 5px 5px 15px;
              }

              .audio-label {
                font-size: 19px;
              }

              .audio-button {
                padding: 10px 10px 10px 8px;
                min-height: 35px;
                min-width: 35px;
                margin: 0px 1em;
                border-radius: 50%;
                font-size: 25px;
              }

              .audio-button-box {
                padding: 0px 2.5em 0px 2.5em;
                margin: 0em 0em 1.5em;
              }

              /* clock  */
              .clock {
                padding: 2px 5px 0px;
                font-size: 20px;
                border-radius: 5px;
                background-color: @background;
                color: @primary;
              }

              .clock:hover {
                background-color: @secondary-background;
              }

              .popup-clock {
                font-size: 2.5em;
                background-color: @background;
                border: 1px solid @primary;
                padding: 0.5em;
                border-radius: 20px;
                color: @primary;
              }

              .popup-clock .calendar-clock {
                margin: 0.25em 0em 0.75em;
                color: @primary;
              }

              .popup-clock .calendar {
                font-size: 24px;
                color: @primary;
              }

              .popup-clock .calendar:selected {
                background-color: @secondary-background;
              }

              /* workspaces */
              .workspaces {
                margin: 0px 0px 0px 5px;
                border-radius: 10px;
                background-color: @background;
                padding: 2px 5px;
              }

              .workspaces .item {
                margin: 0px 3px;
                font-size: 13px;
                border-radius: 100%;
                padding: 0px 3px 0px 3px;
                background-color: rgba(0, 0, 0, 0);
                color: @primary;
              }

              .workspaces .item:hover {
                background-color: @secondary-background;
                color: @primary;
              }

              .workspaces .item:not(.visible) {
                color: @warning;
              }

              .workspaces .item.focused {
                background-color: @primary;
                color: @background;
              }

              /* battery */
              .battery {
                font-size: 13px;
                padding: 0px 4px 0px 0px;
                margin: 2px 0px 2px 0px;
                background-color: @background;
                color: @primary;
              }

              .battery .icon {
                opacity: 0.0;
              }

              .battery .label {
                margin: 2px 0px 0px -8px;
                color: @primary;
              }

              .battery:hover {
                background-color: @secondary-background;
                border-radius: 5px;
              }

              .popup-battery {
                background-color: @background;
                color: @primary;
                border-radius: 20px;
                border: 1px solid @primary;
                padding: 16px;
                font-size: 20px;
              }

              /* music */
              .music {
                font-size: 13px;
                padding: 0px 4px 0px 3px;
                margin: 2px 3px 2px 0px;
                background-color: @background;
                color: @primary;
              }

              .music:hover {
                background-color: @secondary-background;
                border-radius: 100%;
              }

              .music .contents .icon {
                margin: 0px 0px 0px 3px;
              }

              .popup-music {
                background-color: @background;
                color: @primary;
                border-radius: 20px;
                border: 1px solid @primary;
                padding: 16px;
                font-size: 20px;
              }

              .popup-music .controls .btn-prev {
                color: @primary;
                margin-right: 16px;
                padding: 0px 4px;
              }

              .popup-music .controls .btn-next {
                color: @primary;
                margin-right: 16px;
                padding: 0px 4px;
              }

              .popup-music .controls .btn-play {
                color: @primary;
                margin-right: 16px;
                padding: 0px 4px;
              }

              .popup-music .controls .btn-pause {
                color: @primary;
                margin-right: 16px;
                padding: 0px 4px;
              }

              /* system */
              .system-box {
                padding: 16px;
                color: @primary;
                border: 1px solid @primary;
                background-color: @background;
                border-radius: 20px;
              }

              .memory-usage {
                font-size: 15px;
                color: @primary;
              }

              .memory-usage:hover {
                background-color: @secondary-background;
              }

              .tray .item {
                margin: 0px 4px;
                background-color: @background;
              }

              .tray popover modelbutton {
                padding: 2px 8px;
                margin: 2px 0px;
              }

              .tray popover > * {
                padding: 10px;
              }
            ''
            + config.mods.ironbar.customCss
          else config.mods.ironbar.customCss;
        features = [
          #"another_feature"
        ];
        config =
          if config.mods.ironbar.useDefaultConfig
          then
            lib.mkMerge
            [
              (monitorConfig config.mods.ironbar.useBatteryModule)
              config.mods.ironbar.customConfig
            ]
          else config.mods.ironbar.customConfig;
      };
    }
  );
}
