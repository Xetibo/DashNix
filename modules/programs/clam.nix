{
  mkDashDefault,
  lib,
  config,
  options,
  pkgs,
  ...
}: {
  options.mods.clam = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables the clamav program and its daemon";
    };
    gui.enable = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = "Install ClamTK in Home Manager when ClamAV is enabled";
    };
    scanner = {
      enable = lib.mkOption {
        default = false;
        example = true;
        type = lib.types.bool;
        description = "Enables the clamav scanner";
      };
      interval = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 04:00:00";
        description = ''
          How often clamdscan is invoked, using a systemd calendar expression.
          The ClamAV daemon settings control scan concurrency and archive limits.
        '';
      };
      persistent = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Run a missed scheduled scan when the timer next starts";
      };
      scanDirectories = lib.mkOption {
        type = with lib.types; listOf str;
        default = [
          "/home"
          "/var/lib"
          "/tmp"
          "/etc"
          "/var/tmp"
        ];
        description = ''List of directories to scan'';
      };
    };
  };
  config = lib.mkIf config.mods.clam.enable (
    lib.optionalAttrs (options ? services.clamav) {
      services.clamav = {
        daemon.enable = mkDashDefault true;
        updater.enable = mkDashDefault true;
        scanner = {
          enable = mkDashDefault config.mods.clam.scanner.enable;
          interval = mkDashDefault config.mods.clam.scanner.interval;
          scanDirectories = mkDashDefault config.mods.clam.scanner.scanDirectories;
        };
      };
      systemd.timers.clamdscan = lib.mkIf config.services.clamav.scanner.enable {
        timerConfig.Persistent = mkDashDefault config.mods.clam.scanner.persistent;
      };
      environment.systemPackages = [
        pkgs.clamav
      ];
    }
    // lib.optionalAttrs (options ? home.packages) {
      home.packages = lib.mkIf config.mods.clam.gui.enable [pkgs.clamtk];
    }
  );
}
