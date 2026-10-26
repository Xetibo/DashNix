{
  inputs,
  system,
}: let
  pkgs = import inputs.hyprland-release {
    inherit system;
    config.allowUnfree = true;
  };
in
  assert pkgs.hyprland.version == "0.56.2"; pkgs
