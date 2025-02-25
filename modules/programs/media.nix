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
  };
  config = lib.optionalAttrs (options ? home.packages) {
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
            imv
            # videos
            mpv
            # pdf
            zathura
            evince
            libreoffice-fresh
            onlyoffice-bin
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
    services =
      if config.mods.media.useBasePackages
      then config.mods.media.specialServices
      else config.mods.media.specialServices;
  };
}
