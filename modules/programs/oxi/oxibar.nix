{
  lib,
  config,
  options,
  ...
}: {
  options.mods.oxi.oxibar = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables OxiBar";
    };
  };
  config = lib.mkIf (config.mods.oxi.oxibar.enable && config.mods.oxi.enable) (
    lib.optionalAttrs (options ? xdg.configFile) {
      programs.oxibar = {
        enable = true;
        config = {
          plugin_config = {
            plugins = ["libworkspaces.so" "libclock.so" "libtray.so" "libaudio.so" "libnetwork.so" "libbluetooth.so" "libnotifications.so"];

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
        };
      };
    }
  );
}
