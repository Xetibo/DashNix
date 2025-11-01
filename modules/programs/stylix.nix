{
  mkDashDefault,
  lib,
  config,
  options,
  unstable,
  inputs,
  pkgs,
  ...
}: let
  svg = ../../assets/rainbow.svg;
  sd = lib.getExe pkgs.sd;
  base16 = pkgs.callPackage inputs.base16.lib {};
  mkWallpaper = schemeStr: let
    scheme = base16.mkSchemeAttrs schemeStr;
  in
    pkgs.runCommand "rainbow.png" {} ''
      cat ${svg} \
        | ${sd} '#f9e2af' '#${scheme.base0A}' \
        | ${sd} '#fab387' '#${scheme.base09}' \
        | ${sd} '#f38ba8' '#${scheme.base08}' \
        | ${sd} '#89b4fa' '#${scheme.base0D}' \
        | ${sd} '#cba6f7' '#${scheme.base0E}' \
        | ${sd} '#a6e3a1' '#${scheme.base0B}' \
        | ${sd} '#1e1e2e' '#${scheme.base00}' \
        | ${lib.getExe pkgs.imagemagick} svg:- png:$out
    '';
in {
  options.mods.stylix = {
    colorscheme = lib.mkOption {
      default = "catppuccin-mocha";
      example = {
        # custom tokyo night
        base00 = "1A1B26";
        base01 = "191a25";
        base02 = "2F3549";
        base03 = "444B6A";
        base04 = "787C99";
        base05 = "A9B1D6";
        base06 = "CBCCD1";
        base07 = "D5D6DB";
        base08 = "C0CAF5";
        base09 = "A9B1D7";
        base0A = "0DB9D7";
        base0B = "9ECE6A";
        base0C = "B4F9F8";
        base0D = "366fea";
        base0E = "BB9AF7";
        base0F = "F7768E";
      };
      type = with lib.types;
        oneOf [
          str
          attrs
          path
        ];
      description = ''
        Base16 colorscheme.
        Can be an attribute set with base00 to base0F,
        a string that leads to a yaml file in base16-schemes path,
        or a path to a custom yaml file.

        Also supports the oxiced theme in an oxiced attrset.
      '';
    };
    cursor = lib.mkOption {
      default = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 24;
      };
      example = {};
      type = with lib.types; attrsOf anything;
      description = "Xcursor config";
    };
    fonts = lib.mkOption {
      default = {
        serif = {
          package = unstable.adwaita-fonts;
          name = "Adwaita Sans";
        };

        sansSerif = {
          package = unstable.adwaita-fonts;
          name = "Adwaita Sans";
        };

        monospace = {
          package = unstable.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font Mono";
        };

        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
      };
      example = {};
      type = with lib.types; attrsOf anything;
      description = "font config";
    };
  };
  config = let
    scheme =
      if builtins.isAttrs config.mods.stylix.colorscheme
      then config.mods.stylix.colorscheme
      else "${pkgs.base16-schemes}/share/themes/${config.mods.stylix.colorscheme}.yaml";
  in
    (lib.optionalAttrs (options ? stylix) {
      stylix = {
        enable = true;
        image = mkDashDefault (mkWallpaper scheme);
        polarity = mkDashDefault "dark";
        targets = {
          nixvim.enable = mkDashDefault false;
          fish.enable = mkDashDefault false;
        };
        fonts = config.mods.stylix.fonts;
        cursor = config.mods.stylix.cursor;
        base16Scheme = scheme;
      };
    })
    // lib.optionalAttrs (options ? environment.systemPackages) {
      environment.systemPackages = [
        config.mods.stylix.fonts.serif.package
        config.mods.stylix.fonts.sansSerif.package
        config.mods.stylix.fonts.monospace.package
        config.mods.stylix.fonts.emoji.package
      ];
    };
}
