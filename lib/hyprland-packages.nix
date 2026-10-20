{
  inputs,
  system,
}: let
  pkgs = inputs.hyprland-release.legacyPackages.${system};
in
  assert pkgs.hyprland.version == "0.56.2"; pkgs
