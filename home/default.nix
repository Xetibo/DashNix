{
  mkDashDefault,
  dashNixAdditionalProps,
  config,
  homeMods,
  inputs,
  lib,
  additionalHomeConfig,
  mod,
  pkgs,
  root,
  alternativePkgs,
  system,
  stable,
  unstable,
  stableInputs,
  unstableInputs,
  ...
}: {
  xdg = {
    portal.config.common = {
      default = mkDashDefault "hyprland;gtk";
      "org.freedesktop.impl.portal.FileChooser" = lib.mkIf (config.mods.media.filePickerPortal != "Default") "shana";
    };
    portal = {
      enable = mkDashDefault true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk # prob needed either way
        (lib.mkIf (config.mods.media.filePickerPortal != "Default") xdg-desktop-portal-shana)
        (lib.mkIf (config.mods.media.filePickerPortal == "Kde") kdePackages.xdg-desktop-portal-kde)
        # Gnome uses their file manager, kinda cool tbh
        (lib.mkIf (config.mods.media.filePickerPortal == "Gnome" && !config.mods.nautilus.enable) nautilus)
        (lib.mkIf (config.mods.media.filePickerPortal == "Lxqt") xdg-desktop-portal-lxqt)
        (lib.mkIf (config.mods.media.filePickerPortal == "Term") xdg-desktop-portal-termfilechooser)
      ];
    };
  };
  home-manager = {
    useGlobalPkgs = mkDashDefault true;
    useUserPackages = mkDashDefault true;
    extraSpecialArgs = {
      inherit
        inputs
        root
        alternativePkgs
        system
        stable
        unstable
        unstableInputs
        stableInputs
        dashNixAdditionalProps
        ;
      mkDashDefault = import ../lib/override.nix {inherit lib;};
    };

    users.${config.conf.username} = {
      disabledModules = ["programs/anyrun.nix"];
      imports =
        [
          ./common.nix
          ./themes
          ./sync.nix
          ../lib/foxwrappers.nix
          ../modules
        ]
        ++ homeMods
        ++ lib.optional (builtins.pathExists additionalHomeConfig) additionalHomeConfig
        ++ lib.optional (builtins.pathExists mod) mod;
    };
  };
}
