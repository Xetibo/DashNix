{
  mkDashDefault,
  config,
  lib,
  ...
}: let
  username = config.conf.username;
in {
  manual = {
    html.enable = mkDashDefault false;
    json.enable = mkDashDefault false;
    manpages.enable = mkDashDefault false;
  };

  fonts.fontconfig.enable = mkDashDefault true;

  home = {
    username = mkDashDefault username;
    homeDirectory = mkDashDefault "/home/${username}";
    sessionPath = ["$HOME/.cargo/bin"];

    enableNixpkgsReleaseCheck = mkDashDefault false;
    sessionVariables = {
      GOROOT = mkDashDefault "$HOME/.go";
      QT_QPA_PLATFORMTHEME = mkDashDefault "qt5ct";
    };

    keyboard = mkDashDefault null;
  };

  programs.nix-index = {
    enable = mkDashDefault true;
    enableFishIntegration = mkDashDefault true;
  };

  nix = {
    extraOptions = lib.mkDefault (lib.mkIf (config ? sops.secrets && config.sops.secrets ? access.path) ''
      !include ${config.sops.secrets.access.path}
    '');
  };
}
