{
  lib,
  config,
  options,
  inputs,
  ...
}: {
  imports = [
    ./oxidash.nix
    ./oxibar.nix
    ./oxilock.nix
    ./oxipaste.nix
    ./oxirun.nix
    ./oxishut.nix
  ];
  options.mods.oxi = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables the Oxibar shell, OxiLock, and optional Oxi applications.";
    };
    ReSet = {
      enable = lib.mkOption {
        default = false;
        example = true;
        type = lib.types.bool;
        description = "Enables standalone ReSet alongside Oxibar's built-in controls and display settings.";
      };
    };
    hyprdock = {
      enable = lib.mkOption {
        default = false;
        example = true;
        type = lib.types.bool;
        description = "Enables standalone hyprdock instead of Oxibar's built-in dock.";
      };
      settings = lib.mkOption {
        default = {};
        example = {};
        type = with lib.types; attrsOf anything;
        description = "settings for hyprdock";
      };
    };
    oxicalc = {
      enable = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = "Enables oxicalc (compositor-independent, not part of the wm suite selection)";
      };
    };
  };
  # Oxicalc is compositor-independent, so it stays available regardless of
  # the selected wm suite. Everything else here belongs to the oxi suite.
  config = lib.mkMerge [
    (lib.mkIf (config.mods.oxi.enable && config.mods.oxi.oxicalc.enable) (
      lib.optionalAttrs (options ? home.packages) {
        programs.oxicalc.enable = true;
      }
    ))
    (lib.mkIf (config.mods.oxi.enable && config.mods.wm.suite == "oxi") (
      lib.optionalAttrs (options ? home.packages) {
        programs = {
          hyprdock = {
            inherit (config.mods.oxi.hyprdock) enable;
            inherit (config.mods.oxi.hyprdock) settings;
          };
          ReSet = lib.mkIf config.mods.oxi.ReSet.enable {
            enable = true;
            config = {
              plugins = [
                inputs.reset-plugins.packages."x86_64-linux".monitor
                inputs.reset-plugins.packages."x86_64-linux".keyboard
              ];
              plugin_config = {
                Keyboard = {
                  path = "/home/${config.conf.username}/.config/reset/keyboard.conf";
                };
              };
            };
          };
        };
      }
      // lib.optionalAttrs (options ? services.logind && options ? services.logind.settings) {
        services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
      }
    ))
  ];
}
