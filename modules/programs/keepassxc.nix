{
  lib,
  config,
  options,
  ...
}: {
  options.mods.keepassxc = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables the piper program and its daemon";
    };
    useConfig = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Whether to overwrite the config of keepassxc. Note, this means that changes can't be applied via the program anymore!";
    };
    config = lib.mkOption {
      default = {
        General = {
          ConfigVersion = 2;
        };

        Browser = {
          Enabled = true;
        };

        GUI = {
          ApplicationTheme = "classic";
          HidePasswords = true;
          MinimizeOnClose = true;
          MinimizeToTray = true;
          ShowTrayIcon = true;
          TrayIconAppearance = "monochrome-light";
        };

        PasswordGenerator = {
          Length = 30;
        };

        Security = {
          EnableCopyOnDoubleClick = true;
        };
      };
      example = {};
      type = with lib.types; attrsOf anything;
      description = "Cache config to be used.";
    };
  };
  config = lib.mkIf config.mods.keepassxc.enable (
    lib.optionalAttrs (options ? home.file) {
      programs.keepassxc = {
        enable = true;
        settings = config.mods.keepassxc.config;
      };
    }
  );
}
