{
  inputs,
  currentSystem,
  permittedPackages,
  pkgs,
}:
import pkgs {
  system = currentSystem;
  config = {
    allowUnfree = true;
    permittedInsecurePackages = permittedPackages;
  };
  overlays = [
    inputs.nur.overlays.default
    inputs.cachy.overlays.pinned
  ];
}
