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

## Nixos and Home-manager Modules

You can add additional modules or remove all of them by overriding parameters to the buildSystems command:

```nix
nixosConfigurations =
    let
        additionalMods = {
            nixos = [
            # your modules
            ]; home = [
            # your modules
            ];
        }
        # passing this parameter will override the existing modules
        mods = {
            nixos = [];
            home = [];
        }
    in
    inputs.dashNix.dashNixLib.buildSystems { root = ./.; inherit mods additionalMods; };
```

## Additional Inputs

Just like modules, you can add additional inputs to your configuration.

```nix
nixosConfigurations =
    let
        additionalInputs = {
            something.url = "yoururl"
        }
    in
    inputs.dashNix.dashNixLib.buildSystems { root = ./.; inherit additionalInputs; };
```

## Configuring pkgs

While DashNix offers a default pkgs config, you may want to permit an unsecure packages or add an overlay to them.
You can configure both stable and unstable pkgs the following way:

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
};
unstableBundle = {
  pkgs = inputs.unstable;
  inherit config;
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

```nix
 nixosConfigurations =
   inputs.dashNix.dashNixLib.buildSystems {
     root = ./stable;
     inherit additionalInputs;
     overridePkgs = true;
   }
   // inputs.dashNix.dashNixLib.buildSystems {
     root = ./unstable;
     inherit additionalInputs;
   };
```

You can now place your systems in the respective directories.
Keep in mind that the hosts directory will still need to exist in each variant.
E.g. stable/hosts/yourserver and unstable/hosts/yourdesktop

# Installation

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
sudo nixos-install --flake <flakelocation>#<hostname> --root <mountpoint>
#example
#nixos-install --flake ~/config#globi --root /mnt
```

Installation via disko:

```sh
sudo disko-install --flake <flakelocation>#<hostname> --disk <disk-name> <disk-device>
#example
#disko-install -- --flake ~/config#globi --disk main /dev/nvme0n1
```

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
