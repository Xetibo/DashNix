{
  lib,
  config,
  options,
  ...
}: let
  cfg = config.mods.oxi.oxibar;

  defaultSettings = {
    plugins = [
      "libbattery.so"
      "libworkspaces.so"
      "libclock.so"
      "libtray.so"
      "libaudio.so"
      "libnetwork.so"
      "libbluetooth.so"
      "libnotifications.so"
    ];

    bar = {
      start = ["workspaces"];
      center = ["clock"];
      end = ["tray" "audio" "network" "bluetooth" "notifications"];
      font = "Adwaita Sans";
    };

    clock = {
      format = "%I:%M";
      tick_seconds = 60;
      font_size = 20;
      bold = true;
      calendar_app = "thunderbird";
    };
  };

  base = lib.recursiveUpdate defaultSettings cfg.settings;

  plugin_config = let
    plugins =
      base.plugins or []
      ++ lib.optionals cfg.battery.enable ["libbattery.so"];

    bar =
      (base.bar or {})
      // lib.optionalAttrs cfg.battery.enable {
        end = (base.bar.end or []) ++ ["battery"];
      };
  in
    base
    // {inherit plugins bar;};
in {
  options.mods.oxi.oxibar = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables OxiBar";
    };

    settings = lib.mkOption {
      default = defaultSettings;
      example = {
        bar = {
          start = ["workspaces"];
          end = [];
          font = "Adwaita Sans";
        };
      };
      type = with lib.types; attrsOf anything;
      description = "Settings passed to OxiBar as plugin_config. Defaults to the current dashnix config.";
    };

    battery = {
      enable = lib.mkOption {
        default = false;
        example = true;
        type = lib.types.bool;
        description = "Enables the battery plugin. When enabled, battery is added to the plugins and the end of the bar, and battery settings are placed into the settings.";
      };
    };
  };

  config = lib.mkIf (cfg.enable && config.mods.oxi.enable) (
    lib.optionalAttrs (options ? xdg.configFile) {
      programs.oxibar = {
        enable = true;
        config.plugin_config = plugin_config;
      };
    }
  );
}
