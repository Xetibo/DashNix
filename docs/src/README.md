<div align = center>

![Logo of DashNix](logo.svg)

</div>

An opinionated flake to bootstrap NixOS systems with default configurations for various programs and services from both NixOS and HomeManager which can be enabled, disabled, configured or replaced at will.

# Usage

This flake is intended to be used as an input to your own NixOS configuration:

```nix
inputs = {
  unstable.url = "github:NixOs/nixpkgs/nixos-unstable-small";
  stable.url = "github:NixOs/nixpkgs/nixos-26.05";
  dashNix = {
    url = "github:Xetibo/DashNix";
    inputs = {
      # Keep package updates under your consumer flake's control.
      unstable.follows = "unstable";
      stable.follows = "stable";
    };
  };
};
```

You can then configure your systems in your flake outputs with a provided library command:

Binary-cache settings from dependency flakes are not inherited. Add the following settings to your root flake's `nixConfig` and accept them with `--accept-flake-config` when building. DashNix also enables its trusted caches in the installed system's `nix.settings.substituters`.

Hyprland is pinned to release v0.56.2. Its upstream release flake supplies the Home Manager module; runtime packages come from the separately pinned `hyprland-release` nixpkgs input because that release's upstream flake compositor was not available in the Hyprland cache. Keep `hyprland-release` independent of system nixpkgs: adding overlays, making it follow another input, or overriding build inputs changes derivation hashes and can force source builds. Consumer nixpkgs updates alone leave this release package unchanged. DashNix selects compositor, portal, Mesa, and userspace graphics drivers from the same package set to avoid libc mismatches.

```nix
  builders-use-substitutes = true;

  extra-substituters = [
    "https://hyprland.cachix.org"
    "https://anyrun.cachix.org"
    "https://cache.garnix.io"
    "https://oxipaste.cachix.org"
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

DashNix's `unstable` input defaults to `nixos-unstable-small`, including the system, kernel, and security-service package defaults. This channel exposes the full nixpkgs package set but advances after a smaller set of builds and tests, allowing security fixes to reach it sooner. Fewer binaries are available than on `nixos-unstable`, especially for GUI applications, so some packages may need source builds.

Consumer flakes control their own lockfiles: update the selected input and rebuild to receive newer revisions. Existing `unstable`, `unstablePkgs`, and `unstableBundle` names are unchanged. An explicit `unstableBundle.pkgs` or `dashNix.inputs.unstable.follows` still selects the consumer's package source. The separately pinned Hyprland/graphics packages and cache-sensitive upstream package graphs retain their own revisions.

While DashNix offers a default pkgs config, you may want to permit an unsecure packages,
add additional modules/inputs, or add an overlay to them.
You can configure both stable and unstable pkgs the following way:

Please note that modules and inputs are merged together to ensure functionality.

```nix
nixosConfigurations = let
  currentSystem = "x86_64-linux";
  permittedPackages = [
    # "some package"
  ];
  config = {
    system = currentSystem;
    config = {
      allowUnfree = true;
      permittedInsecurePackages = permittedPackages;
    };
  };
  inputOverrides = {
    # Some inputs
  };
  mods = {
    home = [
      # Some home manager module
    ];
    nixos = [
      # Some nixos module
    ];
  };
  unstableBundle = {
    pkgs = inputs.unstable;
    inputs = inputOverrides;
    inherit config mods;
  };
in
  inputs.dashNix.dashNixLib.buildSystems {
    root = ./.;
    inherit unstableBundle;
  };

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
- greetd : Enables greetd with the themed OxiSession kiosk for Oxi, or the Noctalia greeter
- home packages : A list of home packages to be installed by default
- kde_connect : Enables KDE connect and opens its ports
- keepassxc : Configures keepassxc
- kitty: Enables and configures kitty terminal
- layout : Modules to configure keyboard layout system wide
- media packages : A list of media packages to be installed by default
- mime: Mime type configuration
- nextcloud : Handles synchronization via nextcloud cmd. (requires config.sops.secrets.nextcloud)
- oxi: Oxibar desktop shell, OxiLock, and optional standalone Oxi programs
- piper : Installs and enables piper alongside its daemon
- plymouth: enable or disable plymouth
- printing : Enables and configures printing services
- scripts: Various preconfigured scripts with the ability to add more
- security: Opt-in desktop and server security presets, reusing the ClamAV module
- sops: Enables sops-nix
- starship : Configures the starship prompt
- stylix : Configures system themes, can also be applied to dashvim if used.
- teams: For the poor souls that have to use this....
- virtualbox : Enables and configures virtualbox
- xkb: Keyboard layout configuration
- xone : Installs the xone driver
- yazi: Installs yazi and sets custom keybinds
- yubikey: Opt-in YubiKey management, smart-card support, and U2F PAM authentication

## Security presets

Enable a preset in the host's shared `configuration.nix`. Security presets are
opt-in; the existing `mods.clam` options remain available independently.

```nix
mods.security = {
  enable = true;
  preset = "desktop"; # Use "server" for the server defaults.
};
```

Both presets enable the stateful inbound firewall and refused-connection logging,
kernel hardening defaults, auditd with a write/attribute watch on `/etc`, bounded
persistent journals, and scheduled ClamAV scans. Nix builds use the sandbox and
require signatures; only `root` is a trusted Nix user by default. Ordinary users
can still build through the daemon, but privileged daemon settings and arbitrary
cache overrides require administrator configuration.

| Default | Desktop | Server |
| --- | --- | --- |
| ClamAV schedule | Sunday at 12:00 | Daily at 04:00 |
| Maximum ClamAV worker threads | 2 | 4 |
| OpenSnitch daemon and graphical-session UI | Enabled | Disabled |
| ClamTK GUI | Installed | Disabled |
| AppArmor support | Disabled | Enabled |
| Existing SSH server | Native authentication settings | Key-only, no root login, X11 or agent forwarding |
| Fail2ban | Disabled | Enabled; SSH jail follows OpenSSH enablement and ports |
| Journal disk limit | 512 MiB | 1 GiB |

Scan timers catch missed runs after startup and add up to 15 minutes of random
delay. ClamAV's daemon and scheduled client run with lower scheduling weights.
Scans report detections without deleting or quarantining files. The presets set
256 MiB per-file and 1 GiB expanded-data limits, 100,000 archive entries, recursion
depth 30, and a five-minute per-file scan limit. Limit alerts indicate incomplete
inspection, not necessarily malware. Scheduled scanning is separate from
ClamAV's optional on-access scanning.

The default scan roots remain `/home`, `/var/lib`, `/tmp`, `/etc`, and `/var/tmp`.
Add existing data mounts, uploads, or application directories through the existing
API, and choose a schedule appropriate for their size:

```nix
mods.clam.scanner = {
  interval = "Sat *-*-* 10:00:00";
  scanDirectories = ["/home" "/var/lib" "/etc" "/tmp" "/var/tmp" "/drive2"];
};
```

Use existing absolute paths without whitespace: the upstream scheduled scanner
currently joins its path arguments without quoting. Review scan summaries for
errors and limit alerts; encrypted files and VM disks need their own checks.

### Desktop outbound firewall

OpenSnitch prompts for application connections. Its UI starts with the user's
Home Manager graphical session; allow the applications and background services
you need. The default process monitor is `proc`, avoiding an extra eBPF kernel
module on custom kernels. Nix package updates can change executable paths and
require rule maintenance. Configure rules with `services.opensnitch.rules` in
`hardware.nix`, or disable the daemon and UI together in `configuration.nix`:

```nix
mods.security.opensnitch.enable = false;
```

Standalone Home Manager can configure the UI and ClamTK only; a system
administrator must enable the associated daemons and system policy.

### Server access and confinement

Select `preset = "server"` in `configuration.nix`. Configure server services and
desktop selection separately. To enable SSH, place the administrator's public key
in `admin.pub`, then configure the NixOS-only `hardware.nix`:

```nix
{config, ...}: {
  services.openssh.enable = true;
  users.users.${config.conf.username}.openssh.authorizedKeys.keyFiles = [./admin.pub];
}
```

Before applying the key-only SSH policy remotely, ensure the non-root
administrator can log in with that key and has working sudo access; keep a
recovery session or console available. The preset hardens SSH when it is
enabled. Fail2ban follows custom SSH ports; configure additional application
jails explicitly. Patching exposed services and restricting server-to-client
network access remain essential against application RCE.

On new installations, replace DashNix's `firstlogin` bootstrap password before
exposing the host. The security preset does not rotate existing passwords or
remove administrator/container groups; review those privileges for the server.

AppArmor enablement installs the LSM/profile-loading infrastructure. Add and test
workload-specific `security.apparmor.policies`; enabling support alone does not
confine every application. Reboot to load the LSM, and ensure custom kernels and
explicit `security.lsm` overrides include AppArmor.

### Overrides and checks

Feature toggles include `audit.enable`, `apparmor.enable`, `opensnitch.enable`,
`opensnitch.ui.enable`, `ssh.enable`, `fail2ban.enable`, and `tools.enable` under
`mods.security`. Existing `mods.clam.enable`, `mods.clam.gui.enable`, and scanner
settings override preset defaults. Native NixOS options in `hardware.nix` also
take precedence through `mkDashDefault`, for example:

```nix
services.clamav.daemon.settings.MaxThreads = 1;
services.clamav.scanner.enable = false;
services.journald.settings.Journal.SystemMaxUse = "2G"; # Unstable nixpkgs API.
```

On stable nixpkgs, journal settings use `services.journald.storage` and
`services.journald.extraConfig`. Both APIs are supported by the preset.
Presets retain service-opened firewall ports; review those services and restrict
them to the appropriate interfaces or networks. Configure passwords and tokens
through runtime secret files rather than literal Nix values or command arguments:
the store is readable, and journals/audit records can retain command arguments.

Lynis and vulnix are installed for manual reviews:

```sh
systemctl list-timers clamdscan.timer
journalctl -u clamdscan.service
sudo ausearch -k system_configuration -ts today
sudo lynis audit system --quick
vulnix --system
```

Lynis reviews hardening; vulnix flags possible vulnerable package versions and
needs verification of backports and false positives. Keep the consumer flake and
application dependencies updated alongside these checks.

## YubiKey

`mods.yubikey.enable` defaults to `false`. Enable it in the host configuration:

```nix
mods.yubikey.enable = true;
```

This installs `ykman` and `pamu2fcfg`, enables PC/SC smart-card support and YubiKey
udev rules, and enables U2F authentication for NixOS PAM services, including login,
sudo, and the desktop locker. The default `pam.control = "sufficient"` allows key
authentication with password fallback. Services with their own PAM stack can opt
out through `security.pam.services.<name>.u2f.enable = false`. The greeter inherits
the `login` PAM stack, so configure `login` to change its U2F policy.

For initial enrollment, set `mods.yubikey.pam.enable = false`, rebuild, then run
the following as the user who will authenticate, touching the key when requested.
Use this to create a new mapping file; preserve existing mappings when adding keys:

```sh
mkdir -p ~/.config/Yubico
umask 077
pamu2fcfg > ~/.config/Yubico/u2f_keys
```

Use `$XDG_CONFIG_HOME/Yubico/u2f_keys` instead if `XDG_CONFIG_HOME` is set. Remove
the `pam.enable = false` override and rebuild to enable authentication.
`mods.yubikey.pam.authFile` accepts a runtime path for a centrally managed mapping;
`pam.cue` controls the touch reminder. Enrollment files remain outside the Nix
store. The module configures system authentication only in NixOS scope.

## Oxi desktop suite

`mods.wm.suite = "oxi"` is the default for Hyprland and niri. It runs Oxibar's
resident shell and dock, uses OxiLock for locking and sleep integration, and
selects OxiSession as greetd's login screen. All three follow the Stylix theme.
OxiSession's login kiosk uses Hyprland by default, configured through
`mods.greetd.oxisession.backend`. It uses the same pinned Hyprland release as the
desktop, launches through `start-hyprland`, and generates Lua configuration.
The login kiosk shares the primary user's resolved cursor theme/size, keyboard
layout/variant, mouse/touchpad settings, and per-device overrides. Configure these
through the usual Stylix/XKB options and structured Hyprland settings; the kiosk
uses shared defaults when the user's Hyprland compositor is disabled.

| Shortcut | Surface |
| --- | --- |
| Mod+Space / Mod+R | Launcher |
| Mod+M | Control center |
| Mod+D | Session menu |
| Mod+Shift+D | Settings |
| Mod+W | Overview |
| Mod+A | OxiPaste clipboard picker |
| Mod+Shift+L | Lock |
| Mod+Shift+Alt+L | Lock, wait for readiness, then suspend |

Configure shell defaults with `mods.oxi.oxibar.settings`, lockscreen appearance
with `mods.oxi.oxilock.settings`, and login appearance with
`mods.greetd.oxisession.settings`. Settings merge recursively; lists replace
defaults. Shell GUI edits are stored separately in `~/.config/oxibar/overrides.toml`.
Set `mods.oxi.oxibar.clipboard.enable = false` to disable built-in clipboard history.
The OxiPaste picker uses `oxibar oxipaste toggle` and needs a separately running,
updated OxiPaste daemon. The launcher's `:` prefix still opens the in-memory Tools
clipboard history.

The older OxiRun, OxiDash, OxiShut, OxiPaste, ReSet, and hyprdock are opt-in;
their existing `mods.oxi.<app>.enable` options remain available. OxiCalc keeps
its independent Mod+G shortcut. Explicit ReGreet configurations must switch
`mods.greetd.greeter` to `"oxisession"` and migrate appearance settings.
Standalone Home Manager users need the system administrator to install
OxiLock's PAM policy.

# Credits

- [Fufexan](https://github.com/fufexan) for the xdg-mime config:
- [Catppuccin](https://github.com/catppuccin) for base16 colors and zen-browser css
- [Danth](https://github.com/danth) for providing a base for the nix docs
- [chermnyx](https://github.com/chermnyx) for providing a base for zen configuration
- [voronind-com](https://github.com/voronind-com) for providing the darkreader configuration
- [Nix-Artwork](https://github.com/NixOS/nixos-artwork/tree/master/logo) for the Nix/NixOS logo (Tim Cuthbertson (@timbertson))
- [xddxdd](https://github.com/xddxdd) for the CachyOS-Kernel flake
