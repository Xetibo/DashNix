{
  lib,
  config,
  pkgs,
  options,
  ...
}:
{
  options.conf = {

    system = lib.mkOption {
      default = "x86_64-linux";
      # no fisherprice unix support
      type =
        with lib.types;
        (enum [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-linux-android"
        ]);
      example = "aarch64-linux";
      description = ''
        System architecture.
      '';
    };

    cpu = lib.mkOption {
      # TODO: how to enable arm?
      default = "amd";
      type =
        with lib.types;
        (enum [
          "amd"
          "intel"
        ]);
      example = "intel";
      description = ''
        cpu microcode.
      '';
    };

    additionalBootKernalParams = lib.mkOption {
      default = [
        "video=${config.conf.defaultMonitor}:${config.conf.defaultMonitorMode}"
      ];
      example = [ ];
      type = with lib.types; listOf str;
      description = ''
        additional kernelParams passed to bootloader
      '';
    };

    defaultMonitor = lib.mkOption {
      default = "";
      example = "eDP-1";
      type = lib.types.str;
      description = ''
        main monitor
      '';
    };

    defaultMonitorMode = lib.mkOption {
      default = "";
      example = "3440x1440@180";
      type = lib.types.str;
      description = ''
        main monitor mode: width x height @ refreshrate
      '';
    };

    defaultMonitorScale = lib.mkOption {
      default = "1";
      example = "1.5";
      type = lib.types.str;
      description = ''
        main monitor scaling
      '';
    };

    ironbar = {
      modules = lib.mkOption {
        default = [ ];
        example = [
          {
            type = "upower";
            class = "memory-usage";
          }
        ];
        type = with lib.types; listOf attrs;
        description = ''
          Adds modules to ironbar. See https://github.com/JakeStanger/ironbar/wiki/ for more information.
        '';
      };
    };

    boot_params = lib.mkOption {
      default = [ ];
      example = [ "resume=something" ];
      type = with lib.types; listOf str;
      description = ''
        Boot params
      '';
    };

    streamdeck = {
      enable = lib.mkOption {
        default = false;
        example = true;
        type = lib.types.bool;
        description = ''
          Install streamdeck configuration program.
        '';
      };
    };

    kernelOverride = lib.mkOption {
      default = null;
      type = with lib.types; nullOr package;
      description = ''
        kernel to be used
        Has no examples as doc complains...
        #example = pkgs.linuxPackages_xanmod_latest;
      '';
    };

    username = lib.mkOption {
      default = "dashie";
      example = "pingpang";
      type = lib.types.str;
      description = ''
        The username.
      '';
    };

    timezone = lib.mkOption {
      default = "Europe/Zurich";
      example = "Europe/Berlin";
      type = lib.types.str;
      description = ''
        The timezone.
      '';
    };

    locale = lib.mkOption {
      default = "en_US.UTF-8";
      example = "de_DE.UTF-8";
      type = lib.types.str;
      description = ''
        The locale.
      '';
    };

    nixos-config-path = lib.mkOption {
      default = "/home/${config.conf.username}/gits/nixos/.";
      example = "yourpath/.";
      type = lib.types.str;
      description = ''
        The path for your build command, you can then simply type rebuild to switch to a new configuration.
      '';
    };

    nvim-colorscheme = lib.mkOption {
      default = {
        tokyonight = {
          enable = true;
        };
      };
      example = {
        catppuccin = {
          enable = true;
        };
      };
      type = lib.types.attrs;
      description = ''
        nixvim colorscheme.
      '';
    };

    nix_path = lib.mkOption {
      default = "/home/${config.conf.username}/gits/nixos";
      example = "yourpath";
      type = lib.types.str;
      description = ''
        The default path for your configuration.
      '';
    };

    kb_layout = lib.mkOption {
      default = "dashie";
      example = "us";
      type = lib.types.str;
      description = ''
        The layout used in services. 
      '';
    };

    systemStateVersion = lib.mkOption {
      example = "24.05";
      default = "23.05";
      type = lib.types.str;
      description = ''
        System state version 
      '';
    };
    homeStateVersion = lib.mkOption {
      default = "24.05";
      example = "23.05";
      type = lib.types.str;
      description = ''
        Home state version 
      '';
    };

  };

  config =
    (lib.optionalAttrs (options ? system.stateVersion) {
      boot = {
        kernelPackages = lib.mkIf (config.conf.kernelOverride != null) config.conf.kernel;
        kernelParams = config.conf.additionalBootKernalParams;
      };
      system.stateVersion = config.conf.systemStateVersion;
    })
    // (lib.optionalAttrs (options ? home.stateVersion) {
      home.stateVersion = config.conf.homeStateVersion;
    });
}
