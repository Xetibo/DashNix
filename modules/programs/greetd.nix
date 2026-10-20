{
  mkDashDefault,
  config,
  lib,
  inputs,
  pkgs,
  options,
  system,
  ...
}: let
  hyprlandPkgs = import ../../lib/hyprland-packages.nix {inherit inputs system;};
  hyprlandPkg = hyprlandPkgs.hyprland;
in {
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
          Main monitor for the Noctalia login screen.
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
          Scale used by the monitor in the Noctalia login screen.
          By default the scale of the main monitor is used.
        '';
      };
      greeterCommand = lib.mkOption {
        default = null;
        example = "/path/to/custom-greeter";
        type = lib.types.nullOr lib.types.str;
        description = "Override the upstream compositor/greeter command. Null uses the selected greeter's owned kiosk.";
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
          Resolution/refreshrate used by the monitor in the Noctalia login screen.
          OxiSession uses its kiosk's preferred output modes.
        '';
      };
      environments = lib.mkOption {
        default = [
          # (lib.mkIf config.mods.hypr.hyprland.enable pkgs.hyprland)
          (lib.mkIf config.mods.hypr.hyprland.enable hyprlandPkg)
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
      greeter = lib.mkOption {
        type = lib.types.enum ["oxisession" "noctalia"];
        default =
          if config.mods.wm.suite == "oxi"
          then "oxisession"
          else "noctalia";
        example = "oxisession";
        description = ''
          Greeter to show on the greetd login screen. Defaults to OxiSession
          for the Oxi suite and Noctalia otherwise. Both follow the DashNix theme.
        '';
      };
      oxisession = {
        backend = lib.mkOption {
          default = "hyprland";
          example = "cage";
          type = lib.types.enum ["cage" "hyprland"];
          description = "Owned kiosk compositor. Hyprland uses the pinned desktop release, Lua configuration, and the desktop's input and cursor settings.";
        };
        settings = lib.mkOption {
          default = {};
          example = {appearance.clock_format = "%H:%M";};
          inherit (pkgs.formats.toml {}) type;
          description = "Administrator-owned OxiSession authentication appearance settings, merged over the DashNix theme and wallpaper.";
        };
      };
      noctalia = {
        customSettings = lib.mkOption {
          default = {};
          example = {};
          type = with lib.types; attrsOf anything;
          description = ''
            Custom noctalia-greeter settings, merged over the dashnix-themed
            defaults. See https://docs.noctalia.dev/greeter/configuration/ for
            all keys.
          '';
        };
      };
    };
  };

  config = let
    inherit (config.conf) username;

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

    useNoctaliaGreeter = config.mods.greetd.greeter == "noctalia";

    oxisessionPackage =
      (inputs.oxibar.packages.${system}.oxisession.override {
        hyprland = hyprlandPkg;
      }).overrideAttrs (old: {
        patches = (old.patches or []) ++ [../../patches/oxisession-hyprland-lua.patch];
        postFixup =
          (old.postFixup or "")
          + ''
            wrapProgram "$out/bin/oxisession-kiosk" ${lib.escapeShellArgs (lib.concatLists (lib.mapAttrsToList (name: value: ["--set" name value]) kioskEnvironment))}
          '';
      });

    desktopHome = config.home-manager.users.${username} or {};
    desktopHyprland = desktopHome.wayland.windowManager.hyprland or {};
    inputSettings =
      if desktopHyprland.enable or false
      then {
        input = desktopHyprland.settings.config.input or {};
        cursor = desktopHyprland.settings.config.cursor or {};
      }
      else
        (import ../../lib/hyprland-input.nix) (
          if desktopHome ? mods
          then desktopHome
          else config
        );
    cursorConfig = desktopHome.mods.stylix.cursor or config.mods.stylix.cursor;
    cursorPackage = desktopHome.home.pointerCursor.package or cursorConfig.package;
    asList = value:
      if builtins.isList value
      then value
      else [value];
    cursorDefaults = {
      HYPRCURSOR_THEME = cursorConfig.name;
      HYPRCURSOR_SIZE = toString cursorConfig.size;
      XCURSOR_THEME = cursorConfig.name;
      XCURSOR_SIZE = toString cursorConfig.size;
    };
    cursorEnvironment =
      cursorDefaults
      // builtins.listToAttrs (builtins.map (entry: {
          name = builtins.elemAt entry._args 0;
          value = toString (builtins.elemAt entry._args 1);
        })
        (builtins.filter (entry:
          entry ? _args
          && builtins.length entry._args >= 2
          && builtins.elem (builtins.head entry._args) (builtins.attrNames cursorDefaults))
        (asList (desktopHyprland.settings.env or []))));
    toLua = lib.generators.toLua {};
    greeterHyprlandConfig = pkgs.writeText "oxisession-hyprland.lua" ''
      hl.config(${toLua inputSettings})
      ${lib.concatMapStringsSep "\n" (device: "hl.device(${toLua device})") (asList (desktopHyprland.settings.device or []))}
      hl.on("hyprland.start", function()
        hl.exec_cmd(${toLua (lib.escapeShellArgs ["${hyprlandPkg}/bin/hyprctl" "setcursor" cursorConfig.name (toString cursorConfig.size)])})
      end)
    '';
    # greetd constructs a fresh PAM environment instead of inheriting its daemon's.
    kioskEnvironment =
      cursorEnvironment
      // {
        XKB_CONFIG_ROOT = config.services.xserver.xkb.dir;
        XKB_DEFAULT_VARIANT = inputSettings.input.kb_variant or "";
        XCURSOR_PATH = "${cursorPackage}/share/icons";
        XDG_DATA_DIRS = "${cursorPackage}/share:/run/current-system/sw/share";
        OXI_HYPRLAND_CONFIG = "${greeterHyprlandConfig}";
      };

    # Greeter palette derived from the resolved stylix scheme (accent
    # override already applied), mirroring the shell's stylix palette roles.
    greeterScheme = config.stylix.base16Scheme;
    greeterHex = color: "#" + lib.removePrefix "#" color;
    greeterPalette = {
      primary = greeterHex greeterScheme.base0D;
      on_primary = greeterHex greeterScheme.base00;
      secondary = greeterHex greeterScheme.base0E;
      on_secondary = greeterHex greeterScheme.base00;
      tertiary = greeterHex greeterScheme.base0C;
      on_tertiary = greeterHex greeterScheme.base00;
      error = greeterHex greeterScheme.base08;
      on_error = greeterHex greeterScheme.base00;
      surface = greeterHex greeterScheme.base00;
      on_surface = greeterHex greeterScheme.base05;
      surface_variant = greeterHex greeterScheme.base01;
      on_surface_variant = greeterHex greeterScheme.base04;
      outline = greeterHex greeterScheme.base03;
      shadow = greeterHex greeterScheme.base00;
      hover = greeterHex greeterScheme.base0D;
      on_hover = greeterHex greeterScheme.base00;
    };

    # "RESxRES@RATE" -> { width, height, refresh_rate }, null when unset.
    greeterMode = let
      m = builtins.match "([0-9]+)x([0-9]+)@([0-9]+)" config.mods.greetd.resolution;
    in
      if m == null
      then null
      else {
        width = builtins.fromJSON (builtins.elemAt m 0);
        height = builtins.fromJSON (builtins.elemAt m 1);
        refresh_rate = builtins.fromJSON (builtins.elemAt m 2);
      };
  in
    lib.mkIf config.mods.greetd.enable (
      lib.optionalAttrs (options ? environment) {
        # greetd display manager
        programs.hyprland = {
          # keep the real package for systemPackages/portal/xwayland handling;
          # the session is registered via displayManager.sessionPackages below.
          package = hyprlandPkg;
          portalPackage = hyprlandPkgs.xdg-desktop-portal-hyprland;
          enable = mkDashDefault true;
        };
        services = {
          # mkForce: the nixpkgs programs.hyprland module also registers
          # [cfg.package] (the unwrapped real package) as a session, which would
          # offer an extra, noisy Hyprland entry in the login prompt. Force our
          # wrapped session list so only the quiet session is offered.
          displayManager.sessionPackages = lib.mkForce sessionPackages;
          oxisession = lib.mkIf (!useNoctaliaGreeter) {
            enable = true;
            package = mkDashDefault oxisessionPackage;
            inherit sessionPackages;
            inherit (config.mods.greetd.oxisession) backend;
            keyboardLayout = inputSettings.input.kb_layout or "us";
            settings =
              lib.recursiveUpdate {
                theme = import ../../lib/oxi-theme.nix {inherit config lib;};
                appearance.wallpaper = "${config.stylix.image}";
              }
              config.mods.greetd.oxisession.settings;
          };
          displayManager.noctalia-greeter = lib.mkIf useNoctaliaGreeter {
            enable = true;
            cursorTheme = {
              inherit (config.mods.stylix.cursor) package name;
            };
            settings = lib.mkMerge [
              {
                session.default =
                  if config.mods.niri.enable
                  then "niri"
                  else "Hyprland";
                user.default = username;
                appearance = {
                  scheme = "Synced";
                  theme_mode = config.stylix.polarity;
                  font_family = config.mods.stylix.fonts.sansSerif.name;
                  palette = greeterPalette;
                  wallpaper = {
                    path = "${config.stylix.image}";
                    fill_mode = "crop";
                  };
                };
                cursor.size = config.mods.stylix.cursor.size;
                keyboard =
                  {
                    layout = config.mods.xkb.layout;
                  }
                  // lib.optionalAttrs (config.mods.xkb.variant != "") {
                    variant = config.mods.xkb.variant;
                  };
              }
              (lib.optionalAttrs (config.mods.greetd.monitor != "") {
                output.name = config.mods.greetd.monitor;
              })
              (lib.optionalAttrs (config.mods.greetd.scale != "") {
                output.scale = builtins.fromJSON config.mods.greetd.scale;
              })
              (lib.optionalAttrs (greeterMode != null) {
                output = {
                  inherit (greeterMode) width height refresh_rate;
                };
              })
              config.mods.greetd.noctalia.customSettings
            ];
          };
          greetd = {
            enable = true;
            settings = {
              terminal.vt = mkDashDefault 1;
              default_session = lib.mkIf (config.mods.greetd.greeterCommand != null) {
                command = lib.mkForce config.mods.greetd.greeterCommand;
              };
            };
          };
        };

        systemd.services.greetd = {
          serviceConfig = {
            StandardOutput = "journal";
            StandardError = "journal";
          };
        };

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
