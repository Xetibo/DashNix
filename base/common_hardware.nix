{
  mkDashDefault,
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
  ];

  wsl.enable = mkDashDefault config.conf.wsl;

  # Bootloader.
  boot = lib.mkIf (!config.conf.wsl) {
    consoleLogLevel = mkDashDefault 0;

    lanzaboote = lib.mkIf config.conf.secureBoot {
      enable = mkDashDefault true;
      pkiBundle = mkDashDefault "/var/lib/sbctl";
      settings.reboot-for-bitlocker = mkDashDefault true;
    };

    loader = {
      systemd-boot = {
        enable =
          if config.conf.secureBoot
          then lib.mkForce false
          else if config.conf.useSystemdBootloader
          then true
          else mkDashDefault false;
        configurationLimit = 5;
      };
      efi.canTouchEfiVariables = mkDashDefault true;
    };

    kernelPackages = mkDashDefault pkgs.linuxPackages_latest;
    initrd = {
      verbose = mkDashDefault false;
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

  networking = {
    useDHCP = mkDashDefault true;
    networkmanager.enable = mkDashDefault true;
    hostName = mkDashDefault hostName;
  };

  time = {
    timeZone = mkDashDefault config.conf.timezone;
    hardwareClockInLocalTime = mkDashDefault config.conf.systemLocalTime;
  };

  i18n.defaultLocale = mkDashDefault config.conf.locale;

  services = {
    lorri.enable = mkDashDefault true;
    xserver.enable = mkDashDefault true;
    fstrim.enable = mkDashDefault true;
    pulseaudio.enable = mkDashDefault false;
    pipewire = {
      enable = mkDashDefault true;
      alsa = {
        enable = mkDashDefault true;
        support32Bit = mkDashDefault true;
      };
      jack.enable = mkDashDefault true;
      pulse.enable = mkDashDefault true;
    };
  };

  nixpkgs.hostPlatform = mkDashDefault config.conf.system;
  nix = {
    gc = {
      automatic = mkDashDefault true;
      dates = mkDashDefault "weekly";
      options = mkDashDefault "--delete-older-than 7d --delete-generations +5";
    };
    settings = {
      trusted-users = [username];
      auto-optimise-store = mkDashDefault true;

      builders-use-substitutes = mkDashDefault true;

      substituters = [
        "https://chaotic-nyx.cachix.org/"
      ];

      trusted-substituters = [
        "https://hyprland.cachix.org"
        "https://anyrun.cachix.org"
        "https://oxipaste.cachix.org"
        "https://oxinoti.cachix.org"
        "https://oxishut.cachix.org"
        "https://oxidash.cachix.org"
        "https://oxicalc.cachix.org"
        "https://hyprdock.cachix.org"
        "https://reset.cachix.org"
        "https://dashvim.cachix.org"
      ];

      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
        "oxipaste.cachix.org-1:n/oA3N3Z+LJP7eIWOwuoLd9QnPyZXqFjLgkahjsdDGc="
        "oxinoti.cachix.org-1:dvSoJl2Pjo5HMaNngdBbSaixK9BSf2N8gzjP2MdGvfc="
        "oxishut.cachix.org-1:axyAGF3XMh1IyMAW4UMbQCdMNovDH0KH6hqLLRJH8jU="
        "oxidash.cachix.org-1:5K2FNHp7AS8VF7LmQkJAUG/dm6UHCz4ngshBVbjFX30="
        "oxicalc.cachix.org-1:qF3krFc20tgSmtR/kt6Ku/T5QiG824z79qU5eRCSBTQ="
        "hyprdock.cachix.org-1:HaROK3fBvFWIMHZau3Vq1TLwUoJE8yRbGLk0lEGzv3Y="
        "reset.cachix.org-1:LfpnUUdG7QM/eOkN7NtA+3+4Ar/UBeYB+3WH+GjP9Xo="
        "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
        "dashvim.cachix.org-1:uLRdxp1WOWHnsZZtu3SwUWZRsvC7SXo0Gyk3tIefuL0="
      ];

      experimental-features = mkDashDefault "nix-command flakes pipe-operators";
    };
  };

  hardware = {
    cpu.${config.conf.cpu}.updateMicrocode =
      mkDashDefault
      config.hardware.enableRedistributableFirmware;
  };

  security.rtkit.enable = mkDashDefault true;

  environment.variables = {
    XDG_CACHE_HOME = mkDashDefault "$HOME/.cache";
    DIRENV_LOG_FORMAT = mkDashDefault "";
    QT_QPA_PLATFORMTHEME = mkDashDefault "qt5ct";
  };

  # allows user change later on
  users = {
    mutableUsers = mkDashDefault true;
    users.${username} = {
      isNormalUser = mkDashDefault true;
      description = mkDashDefault username;
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
      password = mkDashDefault "firstlogin";
    };
  };
}
