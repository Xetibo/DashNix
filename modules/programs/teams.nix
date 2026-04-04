{
  lib,
  config,
  options,
  pkgs,
  ...
}: {
  options.mods.teams = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables teams via a chromium pwa (for the poor souls that have to use this for work)";
    };
    loopback = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables loopback for screensharing -> teams sucks :)";
    };
  };
  config = lib.mkIf config.mods.teams.enable (
    lib.optionalAttrs (options ? home.packages) {
      home.packages = [pkgs.teams-for-linux];
    }
    // (lib.optionalAttrs (options ? boot.kernelModules) {
      boot = {
        extraModulePackages = with config.boot.kernelPackages; [v4l2loopback];
        kernelModules = ["v4l2loopback"];
        extraModprobeConfig = ''
          options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
        '';
      };
    })
  );
}
