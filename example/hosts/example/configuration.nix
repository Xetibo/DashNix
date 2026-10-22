{config, ...}: {
  # TODO denote important changes

  # variables for system
  conf = {
    # TODO your username
    username = "exampleName";
    # TODO only needed when you use intel -> amd is default
    # cpu = "intel";
    # TODO your xkb layout
    locale = "en_US.UTF-8";
    # TODO your timezone
    timezone = "Europe/Zurich";
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
    # Security presets are opt-in: "desktop" or "server".
    # security = { enable = true; preset = "desktop"; };
    # YubiKey management and U2F PAM authentication are opt-in.
    # yubikey.enable = true;
    # yubikey.pam.enable = false; # Keep PAM disabled during initial key enrollment.
    # The default Oxi suite uses Oxibar's shell/dock, OxiLock, and OxiSession.
    # oxi.oxibar.battery.enable = true;
    # oxi.oxibar.settings.dock.pinned = ["firefox" "kitty"];
    # oxi.oxibar.clipboard.enable = false;
    # oxi.oxilock.settings.appearance.clock_format = "%H:%M";
    # Noctalia shell (only active with `wm.suite = "noctalia"`):
    # selects the noctalia suite instead of the default oxi suite
    # wm.suite = "noctalia";
    # Noctalia ships dashnix defaults (full-width bar, enlarged
    # clock/workspaces, clock in the palette accent). Override per key via
    # https://docs.noctalia.dev/noctalia/configuration/shell/ and
    # https://github.com/noctalia-dev/noctalia/blob/main/example.toml
    # (theme.* keys are owned by stylix and would be overridden).
    # noctalia.settings = {
    #   widget.clock.font_scale = 1.8;
    # };
    # login manager:
    # Default is greetd with the suite's greeter (oxisession for Oxi).
    # greetd.oxisession.settings.appearance.clock_format = "%H:%M";
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
