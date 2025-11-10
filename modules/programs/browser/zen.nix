# credits to Voronind for darkreader config https://github.com/voronind-com/nix/blob/main/home/program/firefox/default.nix
{
  lib,
  dashNixAdditionalProps,
  config,
  options,
  inputs,
  system,
  pkgs,
  ...
}: let
  # at time of using this here, stylix might not be evaluated yet
  # hence ensure it is by using base16 mkSchemeAttrs
  base16 = pkgs.callPackage inputs.base16.lib {};
  scheme = base16.mkSchemeAttrs config.stylix.base16Scheme;
  name = "zen";
in {
  imports = [
    (import ../../../lib/foxextensions.nix
      {inherit lib dashNixAdditionalProps pkgs name;})
  ];
  options.mods.browser.${name} = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables the zen browser";
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
        CaptivePortal = false;
        DisableFirefoxStudies = true;
        DisableTelemetry = true;
        NoDefaultBookmarks = true;
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
        "3rdparty".Extensions = {
          "addon@darkreader.org" = {
            theme = {
              darkSchemeBackgroundColor = "#${scheme.base00}";
              darkSchemeTextColor = "#${scheme.base05}";
            };
            previewNewDesign = true;
          };
        };
      };
      example = {};
      type = with lib.types; attrsOf anything;
      description = "Zen policy configuration. See https://mozilla.github.io/policy-templates for more information.";
    };
    profiles = lib.mkOption {
      default = [
        {
          name = "${config.conf.username}";
          value = {
            settings = {
              "zen.view.compact.hide-tabbar" = false;
              "zen.view.compact.hide-toolbar" = true;
              "zen.view.sidebar-expanded" = false;
              "zen.view.use-single-toolbar" = false;
              "zen.view.welcome-screen.seen" = true;
              "zen.theme.accent-color" = "#b4bbff";
              "extensions.autoDisableScopes" = 0;
              "cookiebanners.service.mode" = 2;
              "widget.use-xdg-desktop-portal.file-picker" = 1;
            };
            isDefault = true;
            id = 0;
          };
        }
        {
          name = "special";
          value = {
            settings = {
              "zen.view.compact.hide-tabbar" = false;
              "zen.view.compact.hide-toolbar" = true;
              "zen.view.sidebar-expanded" = false;
              "zen.view.use-single-toolbar" = false;
              "zen.view.welcome-screen.seen" = true;
              "zen.theme.accent-color" = "#b4bbff";
              "extensions.autoDisableScopes" = 0;
              "widget.use-xdg-desktop-portal.file-picker" = 1;
            };
            isDefault = false;
            id = 1;
          };
        }
      ];
      example = [
        {
          name = "custom";
          value = {
            settings = {
              extensions.autoDisableScopes = 0;
            };
            extensions.packages = [pkgs.nur.repos.rycee.firefox-addons.darkreader];
            isDefault = true;
            id = 0;
          };
        }
      ];
      type = with lib.types; listOf (attrsOf anything);
      description = "Zen profiles";
    };
  };
  config = lib.mkIf (config.mods.browser.zen.enable || config.mods.homePackages.browser == "zen") (
    (lib.optionalAttrs (options ? home.packages) {
      programs.zen-browser = {
        enable = true;
        package =
          pkgs.wrapFirefox
          inputs.zen-browser.packages.${system}.zen-browser-unwrapped
          {
            pname = "zen-browser";
            extraPolicies =
              config.mods.browser.zen.configuration
              // {
                ExtensionSettings = builtins.foldl' (acc: ext: acc // ext) {} (config.mods.browser.zen.extensions
                  ++ (
                    if config.mods.browser.firefox.darkreader
                    then [
                      {
                        "addon@darkreader.org" = {
                          install_url = "file://${pkgs.callPackage ../../../patches/darkreader.nix {inherit lib dashNixAdditionalProps;}}/latest.xpi";
                          installation_mode = "normal_installed";
                        };
                      }
                    ]
                    else []
                  ));
              };
          };
        profiles = builtins.listToAttrs config.mods.browser.zen.profiles;
      };
    })
    // (lib.optionalAttrs (options ? stylix.targets.zen-browser) {
      stylix.targets.zen-browser.profileNames = lib.map (profile: profile.name) config.mods.browser.zen.profiles;
    })
  );
}
