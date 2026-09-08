{
  lib,
  config,
  options,
  pkgs,
  ...
}: {
  options.mods = {
    gnomeServices.enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Enables gnome services: keyring and settings daemon.
        Note: Do not use these for environments which ship these functionalities by default: GNOME, KDE
      '';
    };
    nautilus.enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Enables and configures Nautilus
      '';
    };
  };

  config = lib.mkIf config.mods.gnomeServices.enable (
    lib.optionalAttrs (options ? services.gnome.gnome-keyring) {
      programs.dconf = {
        enable = true;
        profiles.user.databases = [
          {
            settings = {
              "org/gnome/desktop/interface" = {
                cursor-theme = config.mods.stylix.cursor.name;
                cursor-size = lib.gvariant.mkInt32 config.mods.stylix.cursor.size;
                color-scheme = "prefer-dark";
              };
            };
          }
        ];
      };
      environment.extraInit = ''
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/keyring/ssh"
      '';
      services = {
        # needed for GNOME services outside of GNOME Desktop
        dbus.packages = with pkgs; [
          gnome-settings-daemon
        ];

        gnome.gnome-keyring.enable = true;
        gvfs.enable = true;
      };
    }
    // lib.optionalAttrs (options ? home.packages) {
      services.gnome-keyring.enable = true;
      dconf.settings = {
        "org/gnome/desktop/interface" = {
          cursor-theme = config.mods.stylix.cursor.name;
          cursor-size = config.mods.stylix.cursor.size;
          color-scheme = "prefer-dark";
        };
      };
      home = {
        packages = let
          packages = with pkgs; [
            nautilus
            sushi
            nautilus-python
            nautilus-open-any-terminal
          ];
        in
          lib.mkIf config.mods.nautilus.enable packages;
      };
    }
  );
}
