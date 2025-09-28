{
  mkDashDefault,
  lib,
  config,
  options,
  pkgs,
  ...
}: {
  options.mods.gaming = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enabled gaming related features.";
    };
    tools = lib.mkOption {
      default = with pkgs; [
        protonplus
        gamescope
        gamemode
        steam
        lutris
        wineWowPackages.stable
        adwsteamgtk
        heroic
        mangohud
        nexusmods-app
        steamtinkerlaunch
        winetricks
      ];
      example = [];
      type = with lib.types; listOf package;
      description = "Install gaming related packages";
    };
    kernel = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Whether to use the CachyOS kernel";
    };
    steam = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Whether to use steam";
    };
    gamemode = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Whether to use gamemode";
    };
    pinCores = lib.mkOption {
      default = "false";
      example = "true";
      type = lib.types.str;
      description = "Pin Cores gamemode config";
    };
    parkCores = lib.mkOption {
      default = "false";
      example = "true";
      type = lib.types.str;
      description = "Park Cores gamemode config";
    };
    gpuOptimization = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Whether to use GPU performance setting. NOTE: this is at your own risk!";
    };
    gpuDevice = lib.mkOption {
      default = 0;
      example = 1;
      type = lib.types.int;
      description = "Your gpu device.(Physical id of lshw)";
    };
  };
  config = lib.mkIf config.mods.gaming.enable (
    lib.optionalAttrs (options ? environment.systemPackages) {
      environment.systemPackages = config.mods.gaming.tools;
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;
      services.scx.enable = true;

      programs = {
        steam.enable = mkDashDefault config.mods.gaming.steam;
        gamemode.enable = true;
        gamemode = {
          enableRenice = mkDashDefault true;
          settings = {
            general = {
              desiredgov = mkDashDefault "performance";
            };
            cpu = {
              pin_cores = mkDashDefault config.mods.gaming.pinCores;
              park_cores = mkDashDefault config.mods.gaming.parkCores;
            };
            gpu = lib.mkIf config.mods.gaming.gpuOptimization {
              apply_gpu_optimisations = mkDashDefault "accept-responsibility";
              gpu_device = mkDashDefault config.mods.gaming.gpuDevice;
              amd_performance_level = mkDashDefault "high";
              nv_powermizer_mode = mkDashDefault 1;
            };
            custom = {
              start = mkDashDefault "notify-send -a 'Gamemode' 'Optimizations activated'";
              end = mkDashDefault "notify-send -a 'Gamemode' 'Optimizations deactivated'";
            };
          };
        };
      };
    }
  );
}
