{
  lib,
  config,
  options,
  ...
}: {
  options.mods.drives = {
    variant = lib.mkOption {
      default = "manual";
      example = "disko";
      type = with lib.types; (enum [
        "manual"
        "disko"
      ]);
      description = ''
        Disk configuration type, either "manual" for regular NixOS disk configuration,
        or "disko" for using disko to automatically format your drives.
      '';
    };
    useSwap = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = ''
        Use swap in drive.
      '';
    };
    useEncryption = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = ''
        Enables encryption.
        !WARNING!
        You need your root drive to be named root exactly!
        Otherwise there will not be a root crypt!
        !WARNING!
      '';
    };
    homeAndRootFsTypes = lib.mkOption {
      default = "ext4";
      example = "btrfs";
      type = with lib.types; (enum [
        "btrfs"
        "ext2"
        "ext3"
        "ext4"
        "exfat"
        "f2fs"
        "fat8"
        "fat16"
        "fat32"
        "ntfs"
        "xfs"
        "zfs"
      ]);
      description = ''
        Filesystem for the home and root partitions.
      '';
    };
    defaultDrives = {
      enable = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = ''
          Use default drive config.

          - Manual variant
            This config expects 4 different partitions on a single drive:
            - boot partition with BOOT label and vfat format (filesystem configurable)
            - swap partition with SWAP label
            - root partition with ROOT label and ext4 format (filesystem configurable)
            - home partition with HOME label and ext4 format (filesystem configurable)
            - gpt disk format

            NOTE: Any different configuration must be done manually with this turned off.

          - Disko variant
            This config creates 4 different partitions on a single drive:
            - boot partition with 1GB size and vfat format
            - swap partition with 32GB (size configurable)
            - root partition with 30% size and ext4 format (size and filesystem configurable)
            - home partition with 70%~ size and ext4 format (size and filesystem configurable)
            - gpt disk format

            NOTE: Any different configuration must be done manually with this turned off.
        '';
      };
    };
    extraDrives = lib.mkOption {
      default = [
      ];
      example = [
        {
          name = "drive2";
          drive = {
            device = "/dev/disk/by-label/DRIVE2";
            fsType = "ext4";
            options = [
              "noatime"
              "nodiratime"
              "discard"
            ];
          };
        }
      ];
      type = with lib.types; listOf (attrsOf anything);
      description = ''
        Extra drives to add.
        Please ensure to add variant compliant attrsets (manual/disko).
        (The example is for manual variant, here an example for disko):
        ```nix
          drive2 = (lib.optionalAttrs config.mods.drives.defaultDrives.enable) {
            device = "/dev/nvme1n1"
            type = "disk";
            content = {
              type = "gpt";
              partitions = {
                drive2 = {
                  start = "0%";
                  end = "100%";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/drive2";
                    mountOptions = [
                      "noatime"
                      "nodiratime"
                      "discard"
                    ];
                  };
                };
              };
            };
          };
        ```
      '';
    };
    disko = {
      defaultDiskId = lib.mkOption {
        default = "TODO";
        example = "/dev/nvme0n1";
        type = lib.types.str;
        description = "The name, ID, UUID or similar for the default drive.";
      };
      rootAmount = lib.mkOption {
        default = 30;
        example = 40;
        type = lib.types.number;
        description = "The percentage of the disk for root. (Home will take up the rest) (Only for disko)";
      };
      swapAmount = lib.mkOption {
        default = 32;
        example = 64;
        type = lib.types.number;
        description = "The amount of swap to use. (Only for disko)";
      };
    };
  };

  config = (
    lib.optionalAttrs (options ? fileSystems) {
      boot.initrd.luks.devices = lib.mkIf (config.mods.drives.variant == "manual" && config.mods.drives.useEncryption) (
        builtins.listToAttrs (
          map (
            {
              name,
              drive,
            }: {
              cryptstorage.device = lib.mkIf (name != "root") drive?device;
              cryptoroot.device = lib.mkIf (name == "root") drive?device;
            }
          )
          config.mods.drives.extraDrives
        )
      );

      fileSystems = lib.mkIf (config.mods.drives.variant == "manual" && !config.conf.wsl) (
        builtins.listToAttrs (
          map (
            {
              name,
              drive,
            }: {
              name = "/" + name;
              value = drive;
            }
          )
          config.mods.drives.extraDrives
        )
        // (lib.optionalAttrs config.mods.drives.defaultDrives.enable) {
          "/" = {
            device = "/dev/disk/by-label/ROOT";
            fsType = config.mods.drives.homeAndRootFsTypes;
            options = [
              "noatime"
              "nodiratime"
              "discard"
            ];
          };

          "/boot" = {
            device = "/dev/disk/by-label/BOOT";
            fsType = "vfat";
            options = [
              "rw"
              "fmask=0022"
              "dmask=0022"
              "noatime"
            ];
          };

          "/home" = {
            device = "/dev/disk/by-label/HOME";
            fsType = config.mods.drives.homeAndRootFsTypes;
            options = [
              "noatime"
              "nodiratime"
              "discard"
            ];
          };
        }
      );

      swapDevices = lib.mkIf (config.mods.drives.useSwap && config.mods.drives.variant == "manual" && !config.conf.wsl) [
        {device = "/dev/disk/by-label/SWAP";}
      ];

      disko.devices = lib.mkIf (config.mods.drives.variant == "disko") {
        disk =
          {
            main = (lib.optionalAttrs config.mods.drives.defaultDrives.enable) {
              device = "${config.mods.drives.disko.defaultDiskId}";
              type = "disk";
              content = {
                type = "gpt";
                partitions = {
                  root = {
                    start = "${
                      if config.mods.drives.useSwap
                      then builtins.toString config.mods.drives.disko.swapAmount
                      else builtins.toString 1
                    }G";
                    end = "${builtins.toString config.mods.drives.disko.rootAmount}%";
                    content = {
                      type = "filesystem";
                      format = config.mods.drives.homeAndRootFsTypes;
                      mountpoint = "/";
                      mountOptions = [
                        "noatime"
                        "nodiratime"
                        "discard"
                      ];
                    };
                  };
                  plainSwap = {
                    start = "1G";
                    end = "33G";
                    content = {
                      type = "swap";
                      discardPolicy = "both";
                      resumeDevice = true;
                    };
                  };
                  boot = {
                    start = "0G";
                    end = "1G";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                      mountOptions = [
                        "rw"
                        "fmask=0022"
                        "dmask=0022"
                        "noatime"
                      ];
                    };
                  };
                  home = {
                    start = "${builtins.toString config.mods.drives.disko.rootAmount}%";
                    end = "100%";
                    content = {
                      type = "filesystem";
                      format = config.mods.drives.homeAndRootFsTypes;
                      mountpoint = "/home";
                      mountOptions = [
                        "noatime"
                        "nodiratime"
                        "discard"
                      ];
                    };
                  };
                };
              };
            };
          }
          // builtins.listToAttrs (
            map (
              {
                name,
                drive,
              }: {
                name = "/" + name;
                value = drive;
              }
            )
            config.mods.drives.extraDrives
          );
      };
    }
  );
}
