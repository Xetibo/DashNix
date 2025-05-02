{
  lib,
  config,
  pkgs,
  options,
  inputs,
  ...
}: {
  options.mods = {
    hyprland = {
      anyrun = {
        enable = lib.mkOption {
          default = false;
          example = true;
          type = lib.types.bool;
          description = "Enables anyrun";
        };
        useDefaultConfig = lib.mkOption {
          default = true;
          example = false;
          type = lib.types.bool;
          description = ''
            Use preconfigured anyrun config.
          '';
        };
        customConfig = lib.mkOption {
          default = {};
          example = {};
          type = with lib.types; attrsOf anything;
          description = ''
            Custom anyrun configuration.
            Will be merged with default configuration if enabled.
          '';
        };
        useDefaultCss = lib.mkOption {
          default = true;
          example = false;
          type = lib.types.bool;
          description = ''
            Use preconfigured anyrun css.
          '';
        };
        customCss = lib.mkOption {
          default = '''';
          example = ''
            #window {
              border-radius: none;
            }
          '';
          type = lib.types.lines;
          description = ''
            Custom anyrun css.
            Will be merged with default css if enabled.
          '';
        };
      };
    };
  };

  config = lib.mkIf config.mods.hyprland.anyrun.enable (
    lib.optionalAttrs (options ? home.packages) {
      programs.anyrun = lib.mkForce {
        enable = true;
        config =
          if config.mods.hyprland.anyrun.useDefaultConfig
          then
            {
              plugins = [
                inputs.anyrun.packages.${pkgs.system}.applications
                inputs.anyrun.packages.${pkgs.system}.rink
                inputs.anyrun.packages.${pkgs.system}.translate
                inputs.anyrun.packages.${pkgs.system}.websearch
              ];
              hideIcons = false;
              width = {
                fraction = 0.3;
              };
              y = {
                fraction = 0.5;
              };
              layer = "overlay";
              hidePluginInfo = true;
              closeOnClick = true;
            }
            // config.mods.hyprland.anyrun.customConfig
          else config.mods.hyprland.anyrun.customConfig;

        extraCss =
          if config.mods.hyprland.anyrun.useDefaultCss
          then
            ''
              #window {
                border-radius: 10px;
                background-color: transparent;
              }

              box#main {
                border-radius: 10px;
              }

              list#main {
                border-radius: 10px;
                margin: 0px 10px 10px 10px;
              }

              list#plugin {
                border-radius: 10px;
              }

              list#match {
                border-radius: 10px;
              }

              entry#entry {
                border: 0;
                border-radius: 10px;
                margin: 10px 10px 0px 10px;
              }

              label#match-desc {
                font-size: 12px;
                border-radius: 10px;
              }

              label#match-title {
                font-size: 12px;
                border-radius: 10px;
              }

              label#plugin {
                font-size: 16px;
                border-radius: 10px;
              }

              * {
                border-radius: 10px;
              }
            ''
            + config.mods.hyprland.anyrun.customCss
          else config.mods.hyprland.anyrun.customCss;
      };
    }
  );
}
