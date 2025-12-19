{
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
          How often clamdscan is invoked.
          By default this runs using 10 cores at most, be sure to run it at a time of low traffic.
        '';
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
        daemon.enable = true;
        updater.enable = true;
        scanner = {
          inherit (config.mods.clam.scanner) enable;
          inherit (config.mods.clam.scanner) interval;
          inherit (config.mods.clam.scanner) scanDirectories;
        };
      };
      environment.systemPackages = [
        pkgs.clamav
      ];
    }
    // lib.optionalAttrs (options ? home.packages) {home.packages = with pkgs; [clamtk];}
  );
}
