{
  mkDashDefault,
  lib,
  config,
  options,
  ...
}: let
  cfg = config.mods.noctalia;
in {
  options.mods.noctalia = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables Noctalia. Only active when mods.wm.suite is \"noctalia\".";
    };
    settings = lib.mkOption {
      default = {};
      example = {
        settings_show_advanced = true;
      };
      type = with lib.types; attrsOf anything;
      description = "Additional Noctalia settings. The theme (palette, font, wallpaper, opacity) is provided by stylix from the dashnix colorscheme, and the bar clock defaults to the palette accent (overridable via settings.widget.clock.color).";
    };
    customPalettes = lib.mkOption {
      default = {};
      example = {};
      type = with lib.types; attrsOf anything;
      description = "Additional custom Noctalia palettes, available alongside the stylix-generated one.";
    };
    systemd = {
      enable = lib.mkOption {
        default = false;
        example = true;
        type = lib.types.bool;
        description = "Start Noctalia via systemd user service instead of compositor autostart.";
      };
    };
  };

  # This module is evaluated in both NixOS and Home Manager scopes, which
  # provide different `programs.noctalia` options: the upstream home module
  # offers `settings`/`customPalettes`, while the nixpkgs NixOS module only
  # offers system integration. Gate each side on the options it supports,
  # mirroring the `options ? ...` pattern used by the oxi modules.
  #
  # Theming intentionally goes through the stylix noctalia target, which
  # derives its palette from the same stylix.base16Scheme (including the
  # dashnix accent override), so the shell follows the dashnix theme.
  config = let
    hmNoctalia = lib.optionalAttrs (options ? programs.noctalia.settings) {
      programs.noctalia = {
        enable = true;
        systemd.enable = cfg.systemd.enable;
        # Dashnix bar defaults: full-width bar with slightly enlarged
        # clock/workspaces, and the clock following the palette accent
        # (stylix derives `primary` from the dashnix colorscheme including
        # the accentColor override). Everything is mkDashDefault, so plain
        # user values in `mods.noctalia.settings` win per key.
        settings =
          if builtins.isAttrs cfg.settings
          then
            lib.mkMerge [
              {
                config_version = mkDashDefault 15;
                bar.main = {
                  margin_ends = mkDashDefault 0;
                  margin_edge = mkDashDefault 0;
                  radius = mkDashDefault 0;
                  thickness = mkDashDefault 38;
                  font_scale = mkDashDefault 1.15;
                };
                widget.clock = {
                  color = mkDashDefault "primary";
                  font_scale = mkDashDefault 1.35;
                };
                widget.workspaces.font_scale = mkDashDefault 1.25;
              }
              cfg.settings
            ]
          else cfg.settings;
        inherit (cfg) customPalettes;
      };
    };
    nixosNoctalia = lib.optionalAttrs (options ? programs.noctalia.recommendedServices) {
      # Noctalia widgets expect NetworkManager, bluetooth, UPower and a
      # power profile daemon; defaults stay overridable.
      programs.noctalia.recommendedServices.enable = mkDashDefault true;
    };
  in
    lib.mkIf (cfg.enable && config.mods.wm.suite == "noctalia") (
      hmNoctalia // nixosNoctalia
    );
}
