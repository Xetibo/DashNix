{
  pkgs,
  config,
  lib,
  hostName,
  modulesPath,
  ...
}: let
  username = config.conf.username;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    #(modulesPath + "/misc/nixpkgs/read-only.nix")
  ];

  wsl.enable = config.conf.wsl;

  # Bootloader.
  boot = lib.mkIf (!config.conf.wsl) {
    consoleLogLevel = 0;

    lanzaboote = lib.mkIf config.conf.secureBoot {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      settings.reboot-for-bitlocker = true;
    };

    loader = {
      systemd-boot = {
        enable =
          if config.conf.secureBoot
          then lib.mkForce false
          else if config.conf.useSystemdBootloader
          then true
          else false;
        configurationLimit = 5;
      };
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    initrd = {
      verbose = false;
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
    };
    kernelParams =
      [
        ''resume="PARTLABEL=SWAP"''
        ''quiet''
        ''udev.log_level=3''
      ]
      ++ config.conf.bootParams;
  };

  # Enable networking
  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager.enable = true;
    hostName = hostName;
  };

  # Set your time zone.
  time.timeZone = config.conf.timezone;

  # Select internationalisation properties.
  i18n.defaultLocale = config.conf.locale;

  # Enable the X11 windowing system.
  services = {
    lorri.enable = true;
    xserver.enable = true;
    fstrim.enable = lib.mkDefault true;
    # Enable sound with pipewire.
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      jack.enable = true;
      pulse.enable = true;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault config.conf.system;
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d --delete-generations +5";
    };
    settings = {
      trusted-users = [username];
      auto-optimise-store = true;

      builders-use-substitutes = true;

      substituters = [
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
        "https://chaotic-nyx.cachix.org/"
      ];

      trusted-public-keys = [
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
        "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      ];

      experimental-features = "nix-command flakes pipe-operators";
    };
  };

  hardware = {
    cpu.${config.conf.cpu}.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  security.rtkit.enable = true;

  environment.variables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    DIRENV_LOG_FORMAT = "";
    QT_QPA_PLATFORMTHEME = "qt5ct";
  };

  # allows user change later on
  users = {
    mutableUsers = true;
    users.${username} = {
      isNormalUser = true;
      description = username;
      extraGroups = [
        "networkmanager"
        "wheel"
        "gamemode"
        "docker"
        "vboxusers"
        "video"
        "audio"
      ];
      packages = with pkgs; [
        home-manager
        xdg-desktop-portal-gtk
      ];
      # this password will only last for the first login
      # e.g. login, then change to whatever else, this also ensures no public hash is available
      password = "firstlogin";
    };
  };
}
