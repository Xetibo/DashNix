{
  pkgs,
  modulesPath,
  lib,
  self,
  inputs,
  ...
}: let
  system = "x86_64-linux";
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
      withUWSM = true;
      xwayland.enable = false;
    };
    uwsm.enable = true;
  };

  fonts.packages = [pkgs.adwaita-fonts];
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
          command = "${lib.getExe pkgs.hyprland}";
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

  system.stateVersion = "25.11";
}
