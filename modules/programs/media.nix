{
  lib,
  options,
  config,
  pkgs,
  ...
}: {
  options.mods.media = {
    useBasePackages = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Default media packages (If disabled, only the additional packages will be installed)";
    };
    additionalPackages = lib.mkOption {
      default = [];
      example = [pkgs.flatpak];
      type = with lib.types; listOf package;
      description = ''
        Additional media packages.
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
    filePickerPortal = lib.mkOption {
      default = "Term";
      example = "Gnome";
      type = with lib.types; oneOf [(enum ["Gnome" "Kde" "Lxqt" "Gtk" "Term" "Default"]) str];
      description = ''
        The file picker portal to use (set with shana).
        Default removes the config, allowing you to set it yourself.
      '';
    };
    termFileChooserConfig = lib.mkOption {
      default = {
        cmd = "${pkgs.xdg-desktop-portal-termfilechooser}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh";
        default_dir = "$HOME";
      };
      example = {};
      type = with lib.types; attrsOf anything;
      description = ''
        Termfilechooser config
      '';
    };
  };
  config = lib.optionalAttrs (options ? home.packages) {
    xdg.configFile."xdg-desktop-portal-termfilechooser/config" = lib.mkIf (config.mods.media.filePickerPortal != "Term") {
      source = (pkgs.formats.ini {}).generate "termchooser" {
        filechooser = config.mods.media.termFileChooserConfig;
      };
    };
    xdg.configFile."xdg-desktop-portal-shana/config.toml" = lib.mkIf (config.mods.media.filePickerPortal != "Default") {
      source = let
        name =
          if (config.mods.media.filePickerPortal == "Term")
          then "org.freedesktop.impl.portal.desktop.termfilechooser"
          else config.mods.media.filePickerPortal;
      in
        (pkgs.formats.toml {}).generate "shana" {
          open_file = name;
          save_file = name;
          save_files = name;
        };
    };
    home.packages =
      if config.mods.media.useBasePackages
      then
        with pkgs;
          [
            # base audio
            pipewire
            wireplumber
            # audio control
            playerctl
            # images
            eog
            # videos
            mpv
            # pdf
            zathura
            evince
            libreoffice-fresh
            onlyoffice-desktopeditors
            pdftk
            pdfpc
            polylux2pdfpc
            # spotify
            # video editing
            kdePackages.kdenlive
            # image creation
            inkscape
            gimp
            krita
            yt-dlp
          ]
          ++ config.mods.media.additionalPackages
      else config.mods.media.additionalPackages;
    programs =
      if config.mods.media.useBasePackages
      then
        {
          obs-studio.enable = true;
          obs-studio.plugins = with pkgs; [obs-studio-plugins.obs-vaapi];
        }
        // config.mods.media.specialPrograms
      else config.mods.media.specialPrograms;
    services = config.mods.media.specialServices;
  };
}
