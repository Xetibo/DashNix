{
  lib,
  config,
  options,
  ...
}: {
  options.mods.fancontrol = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables fancontrol-gui with needed drivers";
    };
    forceId = lib.mkOption {
      default = null;
      example = "force_id=0x8628";
      type = with lib.types; nullOr str;
      description = "Modprobe options for the it87 driver. Information at: https://wiki.archlinux.org/title/Lm_sensors#Gigabyte_B250/Z370/B450M/B560M/B660M/Z690/B550_motherboards";
    };
  };
  config = lib.mkIf config.mods.fancontrol.enable (
    lib.optionalAttrs (options ? home.packages) {
      programs.fancontrol-gui.enable = true;
    }
    // (lib.optionalAttrs (options ? boot.kernelModules) {
      boot = {
        kernelParams = ["acpi_enforce_resources=lax"];
        extraModulePackages = with config.boot.kernelPackages; [liquidtux it87];
        kernelModules = ["v4l2loopback" "it87"];
        extraModprobeConfig = lib.mkIf (config.mods.fancontrol.forceId != null) ''
          options it87 ${config.mods.fancontrol.forceId}
        '';
      };
    })
  );
}
