{
  mkDashDefault,
  additionalHomeConfig,
  additionalHomeMods,
  additionalInputs,
  config,
  homeMods,
  inputs,
  lib,
  mod,
  pkgs,
  root,
  alternativePkgs,
  system,
  stable,
  unstable,
  ...
}: {
  xdg = {
    portal.config.common.default = mkDashDefault "*";
    portal = {
      enable = mkDashDefault true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
  };
  home-manager = {
    useGlobalPkgs = mkDashDefault true;
    useUserPackages = mkDashDefault true;
    extraSpecialArgs = {
      inherit inputs root additionalInputs alternativePkgs system stable unstable;
      mkDashDefault = import ../lib/override.nix {inherit lib;};
    };

    users.${config.conf.username} = {
      disabledModules = lib.mkDefault ["programs/anyrun.nix"];
      imports =
        [
          ./common.nix
          ./themes
          ./sync.nix
          ../lib/foxwrappers.nix
        ]
        ++ homeMods
        ++ additionalHomeMods
        ++ lib.optional (builtins.pathExists mod) mod
        ++ lib.optional (builtins.pathExists additionalHomeConfig) additionalHomeConfig;
    };
  };
}
