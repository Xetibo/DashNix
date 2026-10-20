{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  cfg = config.mods.oxi.oxilock;
  settings =
    lib.recursiveUpdate {
      theme = import ../../../lib/oxi-theme.nix {inherit config lib;};
      appearance.wallpaper = "${config.stylix.image}";
    }
    cfg.settings;
in {
  options.mods.oxi.oxilock = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables OxiLock and its system PAM policy for the Oxi suite.";
    };
    settings = lib.mkOption {
      default = {};
      example = {appearance.clock_format = "%H:%M";};
      inherit (pkgs.formats.toml {}) type;
      description = "Authentication appearance settings, merged over the DashNix theme and wallpaper.";
    };
    sleepIntegration = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enable the Home Manager readiness-gated sleep-lock watcher. Standalone Home Manager requires administrator-installed OxiLock PAM policy.";
    };
  };

  config = lib.mkIf (cfg.enable && config.mods.oxi.enable && config.mods.wm.suite == "oxi") (
    lib.optionalAttrs (options ? security.pam) {
      programs.oxilock.enable = true;
      security.polkit.enable = true;
    }
    // lib.optionalAttrs (options ? programs.oxilock.settings) {
      programs.oxilock = {
        enable = true;
        inherit settings;
        inherit (cfg) sleepIntegration;
      };
    }
  );
}
