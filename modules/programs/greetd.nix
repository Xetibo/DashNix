{
  mkDashDefault,
  config,
  lib,
  inputs,
  pkgs,
  options,
  ...
}: {
  options.mods = {
    greetd = {
      enable = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = ''
          Enables the greetd login manager.
        '';
      };
      monitor = lib.mkOption {
        default =
          if config.mods.wm.monitors != []
          then (builtins.elemAt config.mods.wm.monitors 0).name
          else "";
        example = "eDP-1";
        type = lib.types.str;
        description = ''
          main monitor for the login screen.
          By default the main monitor is used.
        '';
      };
      scale = lib.mkOption {
        default =
          if config.mods.wm.monitors != []
          then builtins.toString (builtins.elemAt config.mods.wm.monitors 0).scale
          else "";
        example = "1.5";
        type = lib.types.str;
        description = ''
          Scale used by the monitor in the login screen.
          By default the scale of the main monitor is used.
        '';
      };
      greeterCommand = lib.mkOption {
        default = "${
          lib.getExe pkgs.hyprland
        } --config /etc/greetd/hyprgreet.conf";
        example = "${
          lib.getExe pkgs.cage
        } -s -- ${lib.getExe pkgs.regreet}";
        type = lib.types.str;
        description = "The compositor/greeter command to run";
      };
      resolution = lib.mkOption {
        default =
          if config.mods.wm.monitors != []
          then let
            resX = builtins.toString (builtins.elemAt config.mods.wm.monitors 0).resolutionX;
            resY = builtins.toString (builtins.elemAt config.mods.wm.monitors 0).resolutionY;
            refresh = builtins.toString (builtins.elemAt config.mods.wm.monitors 0).refreshrate;
          in "${resX}x${resY}@${refresh}"
          else "";
        example = "3440x1440@180";
        type = lib.types.str;
        description = ''
          Resolution/refreshrate used by the monitor in the login screen.
        '';
      };
      environments = lib.mkOption {
        default = [
          (lib.mkIf config.mods.hypr.hyprland.enable inputs.hyprland.packages.${config.conf.system}.hyprland)
          (lib.mkIf config.mods.niri.enable pkgs.niri)
        ];
        # no idea if these are written correctly
        example = [
          pkgs.niri
          pkgs.river-classic
          pkgs.swayfx
        ];
        type = with lib.types; listOf package;
        description = ''
          List of environments that should be available in the login prompt.
        '';
      };
      regreet = {
        customSettings = lib.mkOption {
          default = {};
          example = {};
          type = with lib.types; attrsOf anything;
          description = ''
            Custom regret settings. See https://github.com/rharish101/ReGreet/blob/main/regreet.sample.toml for more information.
          '';
        };
      };
    };
  };

  config = let
    inherit (config.conf) username;
  in
    lib.mkIf config.mods.greetd.enable (
      lib.optionalAttrs (options ? environment) {
        # greetd display manager
        programs.hyprland.enable = mkDashDefault true;
        services = {
          displayManager.sessionPackages = config.mods.greetd.environments;
          greetd = {
            enable = true;
            settings = {
              terminal.vt = mkDashDefault 1;
              default_session = {
                command = mkDashDefault config.mods.greetd.greeterCommand;
                user = mkDashDefault username;
              };
            };
          };
        };

        # should technically be the same, but this is configured instead in order to provide a decent out of the box login experience.
        environment.etc."greetd/hyprgreet.conf".text = ''
          monitor=${config.mods.greetd.monitor},${config.mods.greetd.resolution},0x0,${config.mods.greetd.scale}
          monitor=,disable

          input {
              kb_layout = ${config.mods.xkb.layout}
              kb_variant = ${config.mods.xkb.variant}
              force_no_accel = true
          }

          misc {
              disable_splash_rendering = false
              disable_hyprland_logo = true
          }

          env=STATE_DIR,var/cache/regreet
          env=CACHE_DIR,var/cache/regreet
          env=HYPRCURSOR_THEME,${config.mods.stylix.cursor.name}
          env=HYPRCURSOR_SIZE,${toString config.mods.stylix.cursor.size}
          env=XCURSOR_THEME,${config.mods.stylix.cursor.name}
          env=XCURSOR_SIZE,${toString config.mods.stylix.cursor.size}
          env=QT_QPA_PLATFORMTHEME,qt5ct

          exec-once=regreet --style /home/${username}/.config/gtk-3.0/gtk.css --config /home/${username}/.config/regreet/regreet.toml; hyprctl dispatch exit
        '';

        # unlock GPG keyring on login
        security.pam = {
          services.greetd = {
            enableGnomeKeyring = mkDashDefault true;
            sshAgentAuth = mkDashDefault true;
          };
          sshAgentAuth.enable = mkDashDefault true;
        };
      }
      // lib.optionalAttrs (options ? home) {
        xdg.configFile."regreet/regreet.toml".source =
          (pkgs.formats.toml {}).generate "regreet"
          config.mods.greetd.regreet.customSettings;
      }
    );
}
