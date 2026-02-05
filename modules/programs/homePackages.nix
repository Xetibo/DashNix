{
  lib,
  options,
  config,
  pkgs,
  ...
}
: let
  packageMapping = import ../../lib/packageMapping.nix {inherit lib;};
  packages = with pkgs; [
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
    regreet
    killall
    kitty
    libnotify
    lsd
    networkmanager
    nh
    nix-index
    playerctl
    poppler-utils
    pulseaudio
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    fuc
    ripgrep
    rm-improved
    system-config-printer
    xournalpp
    zenith
    zoxide
  ];
  defaultMapping = packageMapping.listToMapping packages;
in {
  options.mods.homePackages = {
    useDefaultPackages = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use default packages (will use additional_packages only if disabled)";
    };
    additionalPackages = lib.mkOption {
      default = [];
      example = [pkgs.flatpak];
      type = with lib.types; listOf package;
      description = ''
        Additional Home manager packages.
        Will be installed regardless of default home manager packages are installed.
      '';
    };
    specialPrograms = lib.mkOption {
      default = {};
      example = {};
      type = with lib.types; attrsOf anything;
      description = ''
        special program configuration to be added which require programs.something notation.
      '';
    };
    specialServices = lib.mkOption {
      default = {};
      example = {};
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
    orcaSlicer = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables orca slicer";
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
    packageMapping = lib.mkOption {
      default = defaultMapping;
      example = {};
      type = with lib.types; attrsOf anything;
      description = "Mapping of programs to install. Disable a program by setting the value of the mapping to null: 'zoxide' = null";
    };
    browser = lib.mkOption {
      default = "zen";
      example = "firefox";
      type = with lib.types;
        nullOr (
          either (enum [
            "firefox"
            "zen"
            "librewolf"
            "chromium"
            "brave"
          ])
          package
        );
      description = "The browser (the enum variants have preconfigured modules)";
    };
  };

  config = lib.optionalAttrs (options ? home.packages) {
    home.packages = let
      packageList = packageMapping.mappingToList (defaultMapping // config.mods.homePackages.packageMapping);
    in
      if config.mods.homePackages.useDefaultPackages
      then
        with pkgs;
          [
            (lib.mkIf config.mods.homePackages.ncspot ncspot)
            (lib.mkIf config.mods.homePackages.orcaSlicer orca-slicer)
            (lib.mkIf config.mods.homePackages.nextcloudClient nextcloud-client)
            (lib.mkIf (config.mods.homePackages.matrixClient != null) config.mods.homePackages.matrixClient)
            (lib.mkIf (config.mods.homePackages.mailClient != null) config.mods.homePackages.mailClient)
            (lib.mkIf (
                # NOTE: This should be package, but nix doesn't have that....
                builtins.isAttrs config.mods.homePackages.browser && config.mods.homePackages.browser != null
              )
              config.mods.homePackages.browser)
          ]
          ++ packageList
          ++ config.mods.homePackages.additionalPackages
      else config.mods.homePackages.additionalPackages;

    xdg.configFile."direnv/direnv.toml".source = (pkgs.formats.toml {}).generate "direnv" {
      global = {
        warn_timeout = "-1s";
      };
    };
    programs =
      config.mods.homePackages.specialPrograms
      // {
        vesktop.enable = true;
      };
    services = config.mods.homePackages.specialServices;
  };
}
