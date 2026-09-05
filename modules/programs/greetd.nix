{
  mkDashDefault,
  config,
  lib,
  inputs,
  pkgs,
  options,
  system,
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
        # pkgs.hyprland
        # console output is redirected to a log file so that the Plymouth ->
        # greeter transition stays clean instead of flashing compositor debug
        # output on the TTY.
        default = "${
          inputs.hyprland.packages.${system}.default
        }/bin/start-hyprland -- --config /etc/greetd/hyprgreet.lua > /tmp/hyprgreet.log 2>&1";
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
          # (lib.mkIf config.mods.hypr.hyprland.enable pkgs.hyprland)
          (lib.mkIf config.mods.hypr.hyprland.enable inputs.hyprland.packages.${system}.default)
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
    hyprlandPkg = inputs.hyprland.packages.${system}.default;

    # Wrap a Hyprland package so that starting the session via greetd redirects
    # the compositor's console output to a log file instead of printing it on
    # the TTY during the Plymouth -> Hyprland transition. The session is
    # launched through the desktop entry's Exec line (an absolute path into the
    # session package), so the wrapper has to ship its own start-hyprland and
    # patched desktop entry inside the package itself.
    # symlinkJoin preserves the whole original package (binaries, portal files,
    # version, ...) while postBuild swaps in the quiet start script and patched
    # desktop entries. lndir creates symlinks into the read-only original, so
    # the symlinks must be removed before writing replacements.
    mkQuietSession = pkg:
      pkgs.symlinkJoin {
        name = "${pkg.name}-quiet-session";
        paths = [pkg];
        version = pkg.version or null;
        passthru.providedSessions = pkg.providedSessions;
        postBuild = ''
          rm -f $out/bin/start-hyprland
          cat > $out/bin/start-hyprland <<EOF
          #!/bin/sh
          exec "${pkg}"/bin/start-hyprland "\$@" > /tmp/hyprland-session.log 2>&1
          EOF
          chmod +x $out/bin/start-hyprland
          for desktop in "${pkg}"/share/wayland-sessions/*.desktop; do
            base=$(basename "$desktop")
            rm -f "$out/share/wayland-sessions/$base"
            sed "s|Exec=${pkg}/bin/start-hyprland|Exec=$out/bin/start-hyprland|" "$desktop" \
              > "$out/share/wayland-sessions/$base"
          done
        '';
      };

    quietHyprland = mkQuietSession hyprlandPkg;

    sessionPackages = builtins.map (pkg:
      if pkg == hyprlandPkg
      then quietHyprland
      else pkg)
    config.mods.greetd.environments;
  in
    lib.mkIf config.mods.greetd.enable (
      lib.optionalAttrs (options ? environment) {
        # greetd display manager
        programs.hyprland = {
          # keep the real package for systemPackages/portal/xwayland handling;
          # the session is registered via displayManager.sessionPackages below.
          package = inputs.hyprland.packages.${system}.default;
          enable = mkDashDefault true;
        };
        programs.regreet = {
          enable = true;
          settings = config.mods.greetd.regreet.customSettings;
        };
        services = {
          # mkForce: the nixpkgs programs.hyprland module also registers
          # [cfg.package] (the unwrapped real package) as a session, which would
          # offer an extra, noisy Hyprland entry in the login prompt. Force our
          # wrapped session list so only the quiet session is offered.
          displayManager.sessionPackages = lib.mkForce sessionPackages;
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
        environment.etc."greetd/hyprgreet.lua".text =
          /*
          lua
          */
          ''
            hl.monitor({
              ["output"] = "${config.mods.greetd.monitor}",
              ["mode"] = "${config.mods.greetd.resolution}",
              ["position"] = "0x0",
              ["scale"] = "${config.mods.greetd.scale}"
            })
            hl.monitor({
              ["output"] = "",
              ["disabled"] = true
            })

            hl.config({
              ["input"] = {
                ["kb_layout"] = "${config.mods.xkb.layout}",
                ["kb_variant"] = "${config.mods.xkb.variant}",
                ["force_no_accel"] = true,
              },
              ["misc"] = {
                ["disable_splash_rendering"] = false,
                ["disable_hyprland_logo"] = true,
                ["disable_xdg_env_checks"] = true,
                ["disable_scale_notification"] = true,
              }
            })

            hl.env("HYPRCURSOR_THEME", "${config.mods.stylix.cursor.name}")
            hl.env("HYPRCURSOR_SIZE", "${toString config.mods.stylix.cursor.size}")
            hl.env("XCURSOR_THEME", "${config.mods.stylix.cursor.name}")
            hl.env("XCURSOR_SIZE", "${toString config.mods.stylix.cursor.size}")
            hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

            hl.on("hyprland.start", function()
              hl.exec_cmd("${pkgs.regreet}/bin/regreet --style /home/${username}/.config/gtk-3.0/gtk.css --config /home/${username}/.config/regreet/regreet.toml; hyprctl dispatch exit")
            end)
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
    );
}
