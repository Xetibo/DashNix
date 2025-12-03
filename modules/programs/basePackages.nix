{
  mkDashDefault,
  config,
  lib,
  options,
  pkgs,
  inputs,
  system,
  ...
}: {
  options.mods = {
    basePackages = {
      enable = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = ''
          Enables default system packages.
        '';
      };
      additionalPackages = lib.mkOption {
        default = [];
        example = [pkgs.openssl];
        type = with lib.types; listOf package;
        description = ''
          Additional packages to install.
          Note that these are installed even if base packages is disabled, e.g. you can also use this as the only packages to install.
        '';
      };
      specialPrograms = lib.mkOption {
        default = {};
        example = {};
        type = with lib.types; attrsOf anything;
        description = ''
          special program configuration to be added which require programs.something notation.
        '';
      };
      specialServices = lib.mkOption {
        default = {};
        example = {};
        type = with lib.types; attrsOf anything;
        description = ''
          special services configuration to be added which require an services.something notation.
        '';
      };
    };
  };

  config = lib.optionalAttrs (options ? environment.systemPackages) {
    environment.systemPackages =
      if config.mods.basePackages.enable
      then
        with pkgs;
          [
            inputs.statix.packages.${system}.default
            adwaita-icon-theme
            dbus
            dconf
            direnv
            glib
            gnome.nixos-gsettings-overrides
            gsettings-desktop-schemas
            gtk-layer-shell
            gtk3
            gtk4
            gtk4-layer-shell
            hicolor-icon-theme
            icon-library
            kdePackages.breeze-icons
            kdePackages.breeze
            kdePackages.qtstyleplugin-kvantum
            libsForQt5.qtstyleplugin-kvantum
            libadwaita
            libxkbcommon
            alejandra
            openssl
            seahorse
            upower
            xorg.xkbutils
            sbctl
          ]
          ++ config.mods.basePackages.additionalPackages
      else config.mods.basePackages.additionalPackages;

    gtk.iconCache.enable = mkDashDefault false;
    services =
      if config.mods.basePackages.enable
      then
        {
          upower.enable = mkDashDefault true;
          dbus = {
            enable = mkDashDefault true;
          };
          avahi = {
            enable = mkDashDefault true;
            nssmdns4 = mkDashDefault true;
            openFirewall = mkDashDefault true;
          };
        }
        // config.mods.basePackages.specialServices
      else config.mods.basePackages.specialServices;

    programs =
      if config.mods.basePackages.enable
      then
        lib.mkMerge
        [
          {
            nix-ld = {
              enable = mkDashDefault true;
              libraries = with pkgs; [
                jdk
                zlib
              ];
            };
            direnv = {
              package = mkDashDefault pkgs.direnv;
              silent = mkDashDefault false;
              loadInNixShell = mkDashDefault true;
              direnvrcExtra = mkDashDefault "";
              nix-direnv = {
                enable = mkDashDefault true;
                package = mkDashDefault pkgs.nix-direnv;
              };
            };
            gnupg.agent.enable = mkDashDefault true;
          }
          config.mods.basePackages.specialPrograms
        ]
      else config.mods.basePackages.specialPrograms;
  };
}
