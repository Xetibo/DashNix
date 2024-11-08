{
  lib,
  options,
  config,
  pkgs,
  inputs,
  ...
}:
{
  options.mods.homePackages = {
    useDefaultPackages = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use default packages (will use additional_packages only if disabled)";
    };
    additionalPackages = lib.mkOption {
      default = [ ];
      example = [ pkgs.flatpak ];
      type = with lib.types; listOf package;
      description = ''
        Additional Home manager packages.
        Will be installed regardless of default home manager packages are installed.
      '';
    };
    specialPrograms = lib.mkOption {
      default = { };
      example = { };
      type = with lib.types; attrsOf anything;
      description = ''
        special program configuration to be added which require programs.something notation.
      '';
    };
    specialServices = lib.mkOption {
      default = { };
      example = { };
      type = with lib.types; attrsOf anything;
      description = ''
        special services configuration to be added which require an services.something notation.
      '';
    };
    matrixClient = lib.mkOption {
      default = pkgs.nheko;
      example = null;
      type = with lib.types; nullOr package;
      description = "The matrix client";
    };
    vesktop = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Adds the vesktop discord client";
    };
    ncspot = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Adds the ncspot spotify client";
    };
    nextcloudClient = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Adds the full desktop nextcloud client (the nextcloud module in dashnix only provides the cli tool)";
    };
    mailClient = lib.mkOption {
      default = pkgs.thunderbird;
      example = null;
      type = with lib.types; nullOr package;
      description = "The email client";
    };
    browser = lib.mkOption {
      default = inputs.zen-browser.packages.${pkgs.system}.specific;
      example = "firefox";
      type =
        with lib.types;
        nullOr (
          either (enum [
            "firefox"
          ]) package
        );
      description = "The browser (the enum variants have preconfigured modules)";
    };
  };
  config = lib.optionalAttrs (options ? home.packages) {
    home.packages =
      if config.mods.homePackages.useDefaultPackages then
        with pkgs;
        [
          (lib.mkIf config.mods.homePackages.ncspot ncspot)
          (lib.mkIf config.mods.homePackages.vesktop vesktop)
          (lib.mkIf config.mods.homePackages.nextcloudClient nextcloud-client)
          (lib.mkIf (!isNull config.mods.homePackages.matrixClient) config.mods.homePackages.matrixClient)
          (lib.mkIf (!isNull config.mods.homePackages.mailClient) config.mods.homePackages.mailClient)
          (lib.mkIf (
            # NOTE: This should be package, but nix doesn't have that....
            builtins.isAttrs config.mods.homePackages.browser && !isNull config.mods.homePackages.browser
          ) config.mods.homePackages.browser)
          adw-gtk3
          bat
          brightnessctl
          dbus
          fastfetch
          fd
          ffmpeg
          flake-checker
          gnome-keyring
          gnutar
          killall
          kitty
          libnotify
          lsd
          networkmanager
          nh
          nix-index
          playerctl
          poppler_utils
          pulseaudio
          libsForQt5.qt5ct
          qt6ct
          fcp
          ripgrep
          rm-improved
          system-config-printer
          xournalpp
          zenith
          zoxide
        ]
        ++ config.mods.homePackages.additionalPackages
      else
        config.mods.homePackages.additionalPackages;

    xdg.configFile."direnv/direnv.toml".source = (pkgs.formats.toml { }).generate "direnv" {
      global = {
        warn_timeout = "-1s";
      };
    };
    programs =
      config.mods.homePackages.specialPrograms
      // (
        if config.mods.homePackages.browser == "firefox" then
          {
            firefox = {
              enable = true;
              policies = config.mods.browser.firefox.configuration;
              profiles = builtins.listToAttrs config.mods.browser.firefox.profiles;
            };
          }
        else
          { }
      );
    services =
      if config.mods.homePackages.useDefaultPackages then
        config.mods.homePackages.specialServices
      else
        config.mods.homePackages.specialServices;
  };
}
