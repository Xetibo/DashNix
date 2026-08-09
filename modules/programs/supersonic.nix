{
  lib,
  config,
  options,
  pkgs,
  inputs,
  ...
}: let
  base16 = pkgs.callPackage inputs.base16.lib {};
  scheme = base16.mkSchemeAttrs config.stylix.base16Scheme;
in {
  options.mods.supersonic = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables and configures supersonic";
    };
    variant = lib.mkOption {
      default = "wayland";
      example = "x11";
      type = lib.types.enum [
        "wayland"
        "x11"
      ];
      description = "The variant of supersonic";
    };
  };
  config = lib.mkIf config.mods.supersonic.enable (
    lib.optionalAttrs (options ? home.packages) {
      home.packages = with pkgs; [
        supersonic
      ];
      xdg.configFile."supersonic/themes/custom.toml".source =
        (pkgs.formats.toml {}).generate "customTheme"
        {
          SupersonicTheme = {
            Name = "Custom";
            Version = "0.2";
            SupportsDark = true;
            SupportsLight = true;
          };

          DarkColors = {
            PageBackground = "#${scheme.base00}";
            ListHeader = "#${scheme.base02}";
            PageHeader = "#${scheme.base02}";
            Background = "#${scheme.base01}";
            ScrollBar = "#${scheme.base02}";
            Button = "#${scheme.base02}";
            Foreground = "#${scheme.base04}";
            InputBackground = "#${scheme.base02}";
          };

          # just define the same as base 16 doesn't define if it is light or not
          LightColors = {
            PageBackground = "#${scheme.base00}";
            ListHeader = "#${scheme.base02}";
            PageHeader = "#${scheme.base02}";
            Background = "#${scheme.base01}";
            ScrollBar = "#${scheme.base02}";
            Button = "#${scheme.base02}";
            Foreground = "#${scheme.base04}";
            InputBackground = "#${scheme.base02}";
          };
        };
    }
  );
}
