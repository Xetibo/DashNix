{
  mkDashDefault,
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  browserName =
    if (builtins.isString config.mods.homePackages.browser)
    then config.mods.homePackages.browser
    else if config.mods.homePackages.browser ? meta && config.mods.homePackages.browser.meta ? mainProgram
    then config.mods.homePackages.browser.meta.mainProgram
    else config.mods.homePackages.browser.pname;
in {
  options.mods.niri = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Enable Niri
      '';
    };
  };

  config = lib.mkIf config.mods.niri.enable (
    lib.optionalAttrs (options ? wayland.windowManager.hyprland) {
      # TODO deduplicate and abstract away base window management config
      # install Niri related packages
      home.packages = with pkgs; [
        xorg.xprop
        grim
        slurp
        satty
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
        kdePackages.xdg-desktop-portal-kde
        xdg-desktop-portal-shana
        copyq
        wl-clipboard

        niri
        xwayland-satellite
      ];
    }
  );
}
