{
  pkgs,
  modulesPath,
  lib,
  self,
  inputs,
  ...
}: let
  system = "x86_64-linux";
  graphicsPkgs = import ../lib/hyprland-packages.nix {inherit inputs system;};
in {
  imports = ["${modulesPath}/installer/cd-dvd/iso-image.nix"];
  nixpkgs.hostPlatform = {
    inherit system;
  };

  environment.systemPackages = with pkgs; [
    inputs.dashvim.packages.${system}.minimal
    disko
    git
    firefox
    kitty
    gnome-disk-utility
    inputs.disko.packages.${system}.disko-install
  ];

  networking = {
    wireless.enable = false;
    networkmanager.enable = true;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];

  users.users.nixos = {
    isNormalUser = true;
    password = "nixos";
    extraGroups = ["wheel"];
  };

  image.baseName = lib.mkForce "DashNix";

  programs = {
    hyprland = {
      enable = true;
      package = graphicsPkgs.hyprland;
      portalPackage = graphicsPkgs.xdg-desktop-portal-hyprland;
      withUWSM = true;
      # Match the cached release package's build flags.
      xwayland.enable = true;
    };
    uwsm.enable = true;
  };

  fonts.packages = [pkgs.adwaita-fonts];
  hardware.graphics.package = graphicsPkgs.mesa;
  hardware.graphics.package32 = graphicsPkgs.pkgsi686Linux.mesa;
  i18n.defaultLocale = "en_US.UTF-8";

  services = {
    displayManager.autoLogin = {
      enable = true;
      user = "nixos";
    };
    greetd = {
      enable = true;
      settings = {
        terminal.vt = 1;
        default_session = {
          # command = "${lib.getExe pkgs.hyprland}";
          command = lib.mkDefault "${pkgs.dbus}/bin/dbus-run-session ${lib.getExe graphicsPkgs.hyprland}";
          user = "nixos";
        };
      };
    };
  };

  isoImage = {
    makeEfiBootable = true;
    makeUsbBootable = true;
    contents = [
      {
        source = "${self}/example";
        target = "example-config";
      }
    ];
  };

  system.stateVersion = "26.05";
}
