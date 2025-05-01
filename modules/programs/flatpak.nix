{
  lib,
  config,
  options,
  pkgs,
  ...
}: {
  options.mods.flatpak = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables the flatpak package manager";
    };
  };
  config = lib.mkIf config.mods.flatpak.enable (
    lib.optionalAttrs (options ? environment.systemPackages) {
      environment.systemPackages = [pkgs.flatpak];
    }
  );
}
