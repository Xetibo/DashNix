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

    #file.".local/share/flatpak/overrides/global".text = lib.mkForce ''
    #  [Context]
    #  filesystems=xdg-config/gtk-3.0;xdg-config/gtk-4.0
    #'';
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
