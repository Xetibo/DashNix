{
  mkDashDefault,
  lib,
  config,
  options,
  pkgs,
  ...
}: let
  cfg = config.mods.yubikey;
in {
  options.mods.yubikey = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables YubiKey management, smart-card support, and optional U2F PAM authentication on NixOS.";
    };

    pam = {
      enable = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = "Enables U2F PAM authentication when the YubiKey module is enabled. Disable while enrolling keys or to use only YubiKey management tools.";
      };

      control = lib.mkOption {
        default = "sufficient";
        example = "required";
        type = lib.types.enum ["sufficient" "required"];
        description = "PAM control flag. Sufficient allows key authentication with password fallback; required makes the key mandatory when its PAM rule is reached.";
      };

      authFile = lib.mkOption {
        default = null;
        example = "/etc/u2f-mappings";
        type = lib.types.nullOr lib.types.str;
        description = "Runtime path to the pamu2fcfg credential mapping. Null uses $XDG_CONFIG_HOME/Yubico/u2f_keys or ~/.config/Yubico/u2f_keys. Enrollment data is managed outside the Nix store.";
      };

      cue = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = "Displays a reminder to touch the YubiKey during PAM authentication.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.optionalAttrs (options ? security.pam.u2f) {
      programs.yubikey-manager.enable = mkDashDefault true;
      environment.systemPackages = [pkgs.pam_u2f];

      security.pam.u2f = lib.mkIf cfg.pam.enable {
        enable = mkDashDefault true;
        control = mkDashDefault cfg.pam.control;
        settings = {
          authfile = mkDashDefault cfg.pam.authFile;
          cue = mkDashDefault cfg.pam.cue;
        };
      };
    }
  );
}
