{
  lib,
  config,
  options,
  ...
}: {
  options.mods = {
    drives = {
      useSwap = {
        enable = lib.mkOption {
          default = true;
          example = false;
          type = lib.types.bool;
          description = ''
            Use default drive config
          '';
        };
      };
      defaultDrives = {
        enable = lib.mkOption {
          default = true;
          example = false;
          type = lib.types.bool;
          description = ''
            Use default drive config
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
        #  TODO:  how to make this work
        # type = with lib.types; listOf (attrsOf driveModule);
        type = with lib.types; listOf (attrsOf anything);
        description = ''
          Extra drives to add.
        '';
      };
    };
  };

  config = (
    lib.optionalAttrs (options ? fileSystems) {
      disko.devices = {
        disk =
          {
            main = (lib.optionalAttrs config.mods.drives.defaultDrives.enable) {
              device = "${config.conf.defaultDiskId}";
              type = "disk";
              content = {
                type = "gpt";
                partitions = {
                  root = {
                    start = "33G";
                    end = "30%";
                    content = {
                      type = "filesystem";
                      format = "btrfs";
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
                    start = "30%";
                    end = "100%";
                    content = {
                      type = "filesystem";
                      format = "btrfs";
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
