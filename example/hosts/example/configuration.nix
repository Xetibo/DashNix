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
    hypr.hyprland = {
      # TODO monitor configuration for hyprland (hyprland is default)
      # should be something like DP-1
      defaultMonitor = "YOURMONITOR";
      # width x height  @ refreshrate
      defaultMonitorMode = "1920x1080@60";
      # scale for your main monitor
      defaultMonitorScale = "1";
      # additional configruation can be done as well
      # customConfig = {
      #   monitor = [
      #     # default
      #     "${config.mods.hypr.hyprland.defaultMonitor},${config.mods.hypr.hyprland.defaultMonitorMode},0x0,${config.mods.hypr.hyprland.defaultMonitorScale}"
      #     # second example monitor
      #     "DP-2,3440x1440@180,auto,1"
      #     # all others
      #     ",highrr,auto,1"
      #   ];
      # }
    };
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
