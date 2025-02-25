{
  lib,
  config,
  options,
  pkgs,
  ...
}: {
  options.mods.browser.firefox = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables firefox";
    };
    configuration = lib.mkOption {
      default = {
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
        DisablePocket = true;
        DisplayBookmarksToolbar = "never";
        DisplayMenuBar = "default-off";
        CaptivePortal = false;
        DisableFirefoxStudies = true;
        DisableTelemetry = true;
        DisableFirefoxAccounts = false;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        OfferToSaveLoginsDefault = false;
        PasswordManagerEnabled = false;
        FirefoxHome = {
          Search = true;
          Pocket = false;
          Snippets = false;
          TopSites = true;
          Highlights = false;
        };
        UserMessaging = {
          ExtensionRecommendations = false;
          SkipOnboarding = true;
        };
      };
      example = {};
      type = with lib.types; attrsOf anything;
      description = "Firefox policy configuration. See https://mozilla.github.io/policy-templates/ for more information.";
    };
    profiles = lib.mkOption {
      default = [
        {
          name = "${config.conf.username}";
          value = {
            isDefault = true;
            id = 0;
          };
        }
        {
          name = "special";
          value = {
            isDefault = false;
            id = 1;
          };
        }
      ];
      example = [
        {
          name = "custom";
          value = {
            isDefault = true;
            id = 0;
            extensions.packages = [ pkgs.nur.repos.rycee.firefox-addons.darkreader ];
          };
        }
      ];
      type = with lib.types; listOf (attrsOf anything);
      description = "Firefox profiles";
    };
  };
  config = lib.mkIf config.mods.browser.firefox.enable (
    lib.optionalAttrs (options ? programs.firefox.profiles) {
      programs.firefox = {
        enable = true;
        policies = config.mods.browser.firefox.configuration;
        profiles = builtins.listToAttrs config.mods.browser.firefox.profiles;
      };
    }
  );
}
