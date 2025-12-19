<div align = center>

![Logo of DashNix](logo.svg)

</div>

An opinionated flake to bootstrap NixOS systems with default configurations for various programs and services from both NixOS and HomeManager which can be enabled, disabled, configured or replaced at will.

# Usage

This flake is intended to be used as an input to your own NixOS configuration:

```nix
dashNix = {
  url = "github:Xetibo/DashNix";
  inputs = {
    # ensure these are here to update the packages on your own
    nixpkgs.follows = "nixpkgs";
    stable.follows = "stable";
  };
};
```

You can then configure your systems in your flake outputs with a provided library command:

Please note that overriding inputs will invalidate the cache configuration, this means you will have to add this manually:

```nix
  builders-use-substitutes = true;

  extra-substituters = [
    "https://hyprland.cachix.org"
    "https://anyrun.cachix.org"
    "https://cache.garnix.io"
    "https://oxipaste.cachix.org"
    "https://oxinoti.cachix.org"
    "https://oxishut.cachix.org"
    "https://oxidash.cachix.org"
    "https://oxicalc.cachix.org"
    "https://hyprdock.cachix.org"
    "https://reset.cachix.org"
    "https://dashvim.cachix.org"
  ];

  extra-trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    "oxipaste.cachix.org-1:n/oA3N3Z+LJP7eIWOwuoLd9QnPyZXqFjLgkahjsdDGc="
    "oxinoti.cachix.org-1:dvSoJl2Pjo5HMaNngdBbSaixK9BSf2N8gzjP2MdGvfc="
    "oxishut.cachix.org-1:axyAGF3XMh1IyMAW4UMbQCdMNovDH0KH6hqLLRJH8jU="
    "oxidash.cachix.org-1:5K2FNHp7AS8VF7LmQkJAUG/dm6UHCz4ngshBVbjFX30="
    "oxicalc.cachix.org-1:qF3krFc20tgSmtR/kt6Ku/T5QiG824z79qU5eRCSBTQ="
    "hyprdock.cachix.org-1:HaROK3fBvFWIMHZau3Vq1TLwUoJE8yRbGLk0lEGzv3Y="
    "reset.cachix.org-1:LfpnUUdG7QM/eOkN7NtA+3+4Ar/UBeYB+3WH+GjP9Xo="
    "dashvim.cachix.org-1:uLRdxp1WOWHnsZZtu3SwUWZRsvC7SXo0Gyk3tIefuL0="
  ];
```

```nix
nixosConfigurations = inputs.dashNix.dashNixLib.buildSystems { root = ./.; };
```

This command will build each system that is placed within the hosts/ directory.
In this directory create one directory for each system you want to configure with DashNix.
This will automatically pick up the hostname for the system and look for 3 different files that are explained below.
(Optionally, you can also change the parameter root (./.) to define a different starting directory than hosts/)

In order for your configuration to work, you are required to at least provide a single config file with a further config file being optional for custom configuration.
The hardware.nix specifies additional NixOS configuration, while home.nix specifies additional home-manager configuration. (both optional)

|- flake.nix\
|- flake.lock\
|- hosts/\
|--- system1/\
|------ configuration.nix (required)\
|------ hardware.nix (optional)\
|------ home.nix (optional)\
|--- system2/\
|------ configuration.nix (required)\
|------ hardware.nix (optional)\
|------ home.nix (optional)\
|--- system3/\
|------ configuration.nix (required)\
|------ hardware.nix (optional)\
|------ home.nix (optional)

Here is a minimal required configuration.nix (the TODOs mention a required change):

```nix
{config, ...}: {
  # TODO denote important changes

  # variables for system
  conf = {
    # TODO your username
    username = "YOURNAME";
    # TODO only needed when you use intel -> amd is default
    # cpu = "intel";
    # TODO your xkb layout
    locale = "something.UTF-8";
    # TODO your timezone
    timezone = "CONTINENT/CITY";
  };

  # modules
  mods = {
    # default disk config has root home boot and swap partition, overwrite if you want something different
    sops.enable = false;
    nextcloud.enable = false;
    wm.monitors = [
      # Example
      # {
      #   name = "DP-1";
      #   resolutionX = 3440;
      #   resolutionY = 1440;
      #   refreshrate = 180;
      #   positionX = 2560;
      #   positionY = 0;
      #   scale = 1;
      #   transform = "0";
      #   vrr = false;
      # }
    ];
    gpu.nvidia.enable = true;
    kdeConnect.enable = true;
    # login manager:
    # default is greetd
    # greetd = { };
    # sddm = { };
    # gdm = { };
    drives = {
      # default assumes ROOT, BOOT, HOME and SWAP labaled drives exist
      # for an example without HOME see below
      # defaultDrives.enable = false;
      # extraDrives = [
      #   {
      #     name = "boot";
      #     drive = {
      #       device = "/dev/disk/by-label/BOOT";
      #       fsType = "vfat";
      #       options = [ "rw" "fmask=0022" "dmask=0022" "noatime" ];
      #     };
      #   }
      #   {
      #     name = "";
      #     drive = {
      #       device = "/dev/disk/by-label/ROOT";
      #       fsType = "ext4";
      #       options = [ "noatime" "nodiratime" "discard" ];
      #     };
      #   }
      # ];
      # You can also use disko to format your disks on installation.
      # Please refer to the Documentation about the drives module for an example.
    };
  };
}
```

## First Login

After logging in the first time, your password will be set to "firstlogin", please change this to whatever you like.

## Configuring pkgs

While DashNix offers a default pkgs config, you may want to permit an unsecure packages,
add additional modules/inputs, or add an overlay to them.
You can configure both stable and unstable pkgs the following way:

Please note that modules and inputs are merged together to ensure functionality.

```nix
currentSystem = "x86_64-linux";
permittedPackages = [
  "some package"
];
config = {
  system = currentSystem;
  config = {
    allowUnfree = true;
    permittedInsecurePackages = permittedPackages;
  };
  inputs = {
    # Some inputs
  }
  mods = {
    home = [
      # Some home manager module
    ];
    nixos = [
      # Some nixos module
    ];
}
};
unstableBundle = {
  pkgs = inputs.unstable;
  inherit config mods;
};
inputs.dashNix.dashNixLib.buildSystems {
  root = ./.;
  inherit unstableBundle;
}
```

With this you could also change your input to something different should you wish to do so.
Note that overriding inputs via the flake still works,
this way however ensures you can also configure the inputs.

## Stable/Unstable

Sometimes you want to differentiate between systems that are stable and unstable, e.g. for servers and desktops/laptops.
This can be done with the overridePkgs flag for the lib function:

(overridePkgs simply inverts the default bundle that is used for the nix standard library as well as NixOS itself)

```nix
nixosConfigurations =
  inputs.dashNix.dashNixLib.buildSystems {
    root = ./stable;
    inherit stableBundle;
    overridePkgs = true;
  }
  // inputs.dashNix.dashNixLib.buildSystems {
    inherit unstableBundle;
    root = ./unstable;
  };
```

You can now place your systems in the respective directories.
Keep in mind that the hosts directory will still need to exist in each variant.
E.g. stable/hosts/yourserver and unstable/hosts/yourdesktop

# Installation via ISO

You can find a custom ISO in the releases: [Link](https://github.com/Xetibo/DashNix/releases).
With this, you will receive the example config in /iso/example alongside the gnome desktop environment,
as well as a few tools like gnome-disks, Neovim, Vscodium, a browser etc.

Alternatively, you can use whatever NixOS installer and just install your config from there, just make sure to set the drive configuration before.

## Commands

First, copy the read-only config from /iso/example-config to a location of your choice.

```sh
cp /iso/example-config ~/config -r
```

Then configure as you please and choose a command below depending on your disk installation variant.

Installation via manual configuration:

```sh
sudo nixos-install --flake <flakelocation>#<hostname> --root <mountpoint> --option experimental-features "nix-command flakes pipe-operators"
#example
#nixos-install --flake ~/config#globi --root /mnt --option experimental-features "nix-command flakes pipe-operators"
```

Installation via disko:

```sh
sudo disko-install --flake <flakelocation>#<hostname> --disk <disk-name> <disk-device> --option experimental-features "nix-command flakes pipe-operators"
#example
#disko-install -- --flake ~/config#globi --disk main /dev/nvme0n1 --option experimental-features "nix-command flakes pipe-operators"
```

# Installation via flake

If you already have nix installed, you can instead just copy the default config onto your system and install DashNix with it.
To create the example config for a base to start with, you can just run this flake with the mkFlake command:

```sh
nix run github:Xetibo/DashNix#mkFlake
```

This command will put the default configuration into $HOME/gits/nixos

# Modules

This configuration features several modules that can be used as preconfigured "recipies".
These modules attempt to combine the home-manager and nixos packages/options to one single configuration file for each new system.
For package lists, please check the individual modules, as the lists can be long.

- Hyprland: Installs and configures Hyprland with various additional packages
- Niri: Installs and configures Niri with various additional packages
- acpid : Enables the acpid daemon
- base packages : A list of system packages to be installed by default
- bluetooth : Configures/enables bluetooth and installs tools for bluetooth
- coding packages : A list of coding packages to be installed by default
- drives : A drive configuration module
- firefox: Enables and configures firefox (extensions and settings)
- fish: Enables and configures fish shell
- gaming : Configures gaming related features (launchers, gamemode)
- git : Git key and config module
- gnome_services : Gnome services for minimal enviroments -> Window managers etc
- gpu : GPU settings (AMD)
- greetd : Enables and configures the greetd/regreet login manager with Hyprland
- home packages : A list of home packages to be installed by default
- kde_connect : Enables KDE connect and opens its ports
- keepassxc : Configures keepassxc
- kitty: Enables and configures kitty terminal
- layout : Modules to configure keyboard layout system wide
- media packages : A list of media packages to be installed by default
- mime: Mime type configuration
- nextcloud : Handles synchronization via nextcloud cmd. (requires config.sops.secrets.nextcloud)
- oxi: My own programs, can be selectively disabled, or as a whole
- piper : Installs and enables piper alongside its daemon
- plymouth: enable or disable plymouth
- printing : Enables and configures printing services
- scripts: Various preconfigured scripts with the ability to add more
- sops: Enables sops-nix
- starship : Configures the starship prompt
- stylix : Configures system themes, can also be applied to dashvim if used.
- teams: For the poor souls that have to use this....
- virtualbox : Enables and configures virtualbox
- xkb: Keyboard layout configuration
- xone : Installs the xone driver
- yazi: Installs yazi and sets custom keybinds

# Credits

- [Fufexan](https://github.com/fufexan) for the xdg-mime config:
- [Catppuccin](https://github.com/catppuccin) for base16 colors and zen-browser css
- [Danth](https://github.com/danth) for providing a base for the nix docs
- [chermnyx](https://github.com/chermnyx) for providing a base for zen configuration
- [voronind-com](https://github.com/voronind-com) for providing the darkreader configuration
- [Nix-Artwork](https://github.com/NixOS/nixos-artwork/tree/master/logo) for the Nix/NixOS logo (Tim Cuthbertson (@timbertson))
- [xddxdd](https://github.com/xddxdd) for the CachyOS-Kernel flake
