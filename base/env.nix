{
  mkDashDefault,
  pkgs,
  config,
  ...
}: {
  environment = {
    variables = {
      GSETTINGS_SCHEMA_DIR = mkDashDefault "${pkgs.glib.getSchemaPath pkgs.gsettings-desktop-schemas}";
      NEOVIDE_MAXIMIZED = mkDashDefault "0";
      GPG_TTY = mkDashDefault "$(tty)";
      EDITOR = mkDashDefault "neovide --no-fork";
      SUDO_EDITOR = mkDashDefault "neovide --no-fork";
      SCRIPTS = mkDashDefault "$HOME/.config/scripts";
    };
    sessionVariables = {
      NIXOS_OZONE_WL = mkDashDefault "1";
      GOPATH = mkDashDefault "$HOME/.go";
      FLAKE = mkDashDefault config.conf.nixosConfigPath;
      NH_FLAKE = mkDashDefault config.conf.nixosConfigPath;
    };
  };
}
