{
  config,
  lib,
  ...
}: let
  username = config.conf.username;
in {
  manual = {
    html.enable = false;
    json.enable = false;
    manpages.enable = false;
  };

  fonts.fontconfig.enable = true;

  home = {
    username = username;
    homeDirectory = "/home/${username}";
    sessionPath = ["$HOME/.cargo/bin"];

    enableNixpkgsReleaseCheck = false;
    sessionVariables = {
      GOROOT = "$HOME/.go";
      QT_QPA_PLATFORMTHEME = "qt5ct";
    };

    keyboard = null;
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  nix = {
    extraOptions = lib.mkIf (config ? sops.secrets && config.sops.secrets ? access.path) ''
      !include ${config.sops.secrets.access.path}
    '';
  };
}
