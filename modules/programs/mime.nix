# Copyright (c) 2020-2021 Mihai Fufezan
# credits to fufexan https://github.com/fufexan/dotfiles/blob/main/home/terminal/programs/xdg.nix
{
  mkDashDefault,
  config,
  lib,
  options,
  ...
}: let
  browserName =
    if (builtins.isString config.mods.homePackages.browser)
    then config.mods.homePackages.browser
    else if config.mods.homePackages.browser ? meta && config.mods.homePackages.browser.meta ? mainProgram
    then config.mods.homePackages.browser.meta.mainProgram
    else config.mods.homePackages.browser.pname;
in {
  options.mods.mime = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables mime handling with nix";
    };
    imageTypes = lib.mkOption {
      default = [
        "png"
        "svg"
        "jpeg"
        "gif"
      ];
      example = [];
      type = with lib.types; listOf str;
      description = "Image mime handlers";
    };
    videoTypes = lib.mkOption {
      default = [
        "mp4"
        "avi"
        "mkv"
      ];
      example = [];
      type = with lib.types; listOf str;
      description = "Video mime handlers";
    };
    audioTypes = lib.mkOption {
      default = [
        "mp3"
        "flac"
        "wav"
        "aac"
      ];
      example = [];
      type = with lib.types; listOf str;
      description = "Audio mime handlers";
    };
    browserTypes = lib.mkOption {
      default = [
        "json"
        "x-extension-htm"
        "x-extension-html"
        "x-extension-shtml"
        "x-extension-xht"
        "x-extension-xhtml"
      ];
      example = [];
      type = with lib.types; listOf str;
      description = "Browser mime handlers";
    };
    browserXTypes = lib.mkOption {
      default = [
        "about"
        "ftp"
        "http"
        "https"
        "unknown"
      ];
      example = [];
      type = with lib.types; listOf str;
      description = "Browser X mime handlers";
    };
    browserApplications = lib.mkOption {
      default = ["${browserName}"];
      example = [];
      type = with lib.types; listOf str;
      description = "Applications used for handling browser mime types";
    };
    imageApplications = lib.mkOption {
      default = ["eog"];
      example = [];
      type = with lib.types; listOf str;
      description = "Applications used for handling image mime types";
    };
    videoApplications = lib.mkOption {
      default = ["mpv"];
      example = [];
      type = with lib.types; listOf str;
      description = "Applications used for handling video mime types";
    };
    audioApplications = lib.mkOption {
      default = ["io.bassi.Amberol"];
      example = [];
      type = with lib.types; listOf str;
      description = "Applications used for handling audio mime types";
    };
    # TODO additional config
  };
  config = lib.optionalAttrs (options ? home) {
    xdg = let
      xdgAssociations = type: program: list:
        builtins.listToAttrs (
          map (e: {
            name = "${type}/${e}";
            value = program;
          })
          list
        );

      imageAc = xdgAssociations "image" config.mods.mime.imageApplications config.mods.mime.imageTypes;
      videoAc = xdgAssociations "video" config.mods.mime.videoApplications config.mods.mime.videoTypes;
      audioAc = xdgAssociations "audio" config.mods.mime.audioApplications config.mods.mime.audioTypes;
      browserAc =
        (xdgAssociations "application" config.mods.mime.browserApplications config.mods.mime.browserTypes)
        // (
          xdgAssociations "x-scheme-handler" config.mods.mime.browserApplications
          config.mods.mime.browserXTypes
        );
      associations = builtins.mapAttrs (_: v: (map (e: "${e}.desktop") v)) (
        # TODO make configurable
        {
          "application/pdf" = ["org.pwmt.zathura-pdf-mupdf"];
          "text/html" = config.mods.mime.browserApplications;
          "text/plain" = ["neovide"];
          "x-scheme-handler/chrome" = ["com.brave.browser"];
          "inode/directory" = ["yazi"];
        }
        // imageAc
        // audioAc
        // videoAc
        // browserAc
      );
    in
      lib.mkIf config.mods.mime.enable {
        enable = true;
        cacheHome = config.home.homeDirectory + "/.local/cache";

        mimeApps = {
          enable = true;
          defaultApplications = associations;
        };

        userDirs = {
          enable = mkDashDefault true;
          createDirectories = mkDashDefault true;
          extraConfig = {
            XDG_SCREENSHOTS_DIR = mkDashDefault "${config.xdg.userDirs.pictures}/Screenshots";
            pws = mkDashDefault "${config.home.homeDirectory}/pws";
          };
        };
      };
  };
}
