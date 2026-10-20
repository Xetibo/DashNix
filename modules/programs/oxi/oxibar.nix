{
  lib,
  config,
  options,
  pkgs,
  ...
}: let
  cfg = config.mods.oxi.oxibar;

  defaultSettings = {
    plugins =
      [
        "libapplications.so"
        "libtools.so"
        "libsystem.so"
        "libworkspaces.so"
        "libclock.so"
        "libtray.so"
        "libaudio.so"
        "libnetwork.so"
        "libbluetooth.so"
        "libnotifications.so"
        "libstats.so"
      ]
      ++ lib.optionals cfg.clipboard.enable ["liboxipaste.so"];

    bar = {
      start = ["launcher" "workspaces"];
      center = ["clock"];
      end = ["tray" "audio" "network" "bluetooth" "notifications" "control-center" "settings" "session"];
      font = config.mods.stylix.fonts.sansSerif.name;
      outputs = ["*"];
    };

    clock = {
      format = "%I:%M";
      tick_seconds = 60;
      font_size = 20;
      bold = true;
      calendar_app = "thunderbird";
    };

    theme = import ../../../lib/oxi-theme.nix {inherit config lib;};
    tools.clipboard_enabled = cfg.clipboard.enable;
    dock.enabled = !config.mods.oxi.hyprdock.enable;
    system =
      if config.mods.oxi.oxilock.enable
      then {lock_command = "${config.programs.oxilock.package}/bin/oxilock";}
      else {lock_enabled = false;};
  };

  base = lib.recursiveUpdate defaultSettings cfg.settings;

  plugin_config = let
    plugins = lib.unique (
      (base.plugins or [])
      ++ lib.optionals cfg.battery.enable ["libbattery.so"]
    );

    bar =
      (base.bar or {})
      // lib.optionalAttrs cfg.battery.enable {
        end = lib.unique ((base.bar.end or []) ++ ["battery"]);
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
      description = "Enables the resident Oxibar desktop shell.";
    };

    settings = lib.mkOption {
      default = {};
      example = {
        bar = {
          start = ["workspaces"];
          end = [];
          font = "Adwaita Sans";
        };
      };
      inherit (pkgs.formats.toml {}) type;
      description = "Oxibar shell and plugin settings, recursively merged over the themed DashNix defaults. GUI edits live in Oxibar's separate overrides.toml.";
    };

    clipboard.enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables the Oxibar OxiPaste picker and in-memory Tools clipboard history (the : prefix). The picker requires a separately running, updated OxiPaste daemon.";
    };

    systemd.enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Run Oxibar through its user service instead of direct compositor autostart.";
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

  config = lib.mkIf (cfg.enable && config.mods.oxi.enable && config.mods.wm.suite == "oxi") (
    lib.optionalAttrs (options ? xdg.configFile) {
      programs.oxibar = {
        enable = true;
        systemd.enable = cfg.systemd.enable;
        config.plugin_config = plugin_config;
      };
    }
  );
}
