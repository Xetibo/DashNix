{
  mkDashDefault,
  lib,
  config,
  options,
  pkgs,
  ...
}: let
  cfg = config.mods.security.monitor;
  script = pkgs.writeScript "dashnix-security-monitor" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ../../../scripts/security-monitor.py}
  '';
  stateDirectory = "/var/lib/dashnix-security";
  settings = pkgs.writeText "dashnix-security-monitor.json" (builtins.toJSON {
    state_directory = stateDirectory;
    flake_path = cfg.flakePath;
    update_inputs = cfg.updateInputs;
    extra_profiles = cfg.extraProfiles;
    inherit (cfg) whitelist;
    known_exploited = cfg.knownExploited.enable;
    cvss_threshold = cfg.cvssThreshold;
    nix = "${pkgs.nix}/bin/nix";
    vulnix = lib.getExe pkgs.vulnix;
  });
  notifySettings = pkgs.writeText "dashnix-security-notify.json" (builtins.toJSON {
    state_directory = stateDirectory;
    notification_state = "${config.xdg.stateHome or ".local/state"}/dashnix-security";
    cvss_threshold = cfg.cvssThreshold;
    notify_send = "${pkgs.libnotify}/bin/notify-send";
  });
in {
  options.mods.security.monitor = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.mods.security.enable;
      defaultText = lib.literalExpression "config.mods.security.enable";
      description = "Check deployed package advisories daily and retain reports; independent of automatic upgrades";
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Systemd calendar schedule for advisory and selected flake-input checks";
    };
    flakePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.conf.nixosConfigPath or null;
      defaultText = lib.literalExpression "config.conf.nixosConfigPath or null";
      description = "Runtime consumer checkout to check without modifying its lock; never a Nix store source snapshot";
    };
    updateInputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["nixpkgs" "dashNix"];
      description = "Explicit root input names to check for revisions; empty disables update checks and preserves intentional pins";
    };
    extraProfiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional required runtime profile paths, beyond system, booted system and primary-user profiles";
    };
    whitelist = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime path to a reviewed vulnix TOML whitelist; use scoped CVEs, comments and expiry dates";
    };
    knownExploited.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Join findings with CISA's Known Exploited Vulnerabilities catalog independently of the installed vulnix version";
    };
    cvssThreshold = lib.mkOption {
      type = lib.types.addCheck lib.types.number (value: value >= 0 && value <= 10);
      default = 7;
      description = "CVSS score at or above which a possible vulnerability gets critical desktop urgency";
    };
    notifications.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.mods.security.preset == "desktop";
      defaultText = lib.literalExpression ''config.mods.security.preset == "desktop"'';
      description = "Deliver deduplicated reports and failures through the Home Manager graphical session; headless hosts retain reports and journal output";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.optionalAttrs (options ? security.auditd) {
      assertions = [
        {
          assertion = cfg.updateInputs == [] || cfg.flakePath != null;
          message = "mods.security.monitor.flakePath is required when updateInputs is nonempty.";
        }
      ];
      systemd = {
        services.dashnix-security-monitor = {
          description = "DashNix deployed-package advisory and update report";
          wants = ["network-online.target"];
          after = ["network-online.target"];
          path = [pkgs.nix pkgs.git];
          environment = {
            HOME = config.users.users.${config.conf.username}.home;
            XDG_CACHE_HOME = "${stateDirectory}/cache";
          };
          serviceConfig = {
            Type = "oneshot";
            User = config.conf.username;
            ExecStart = "${script} collect --config ${settings}";
            StateDirectory = "dashnix-security";
            StateDirectoryMode = "0700";
            UMask = "0077";
            TimeoutStartSec = "1h";
            Nice = mkDashDefault 10;
            CPUWeight = mkDashDefault 20;
            IOWeight = mkDashDefault 20;
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
            CapabilityBoundingSet = "";
          };
        };
        timers.dashnix-security-monitor = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = mkDashDefault cfg.interval;
            OnBootSec = "5m";
            RandomizedDelaySec = mkDashDefault "15m";
            Persistent = true;
          };
        };
      };
    }
    // lib.optionalAttrs (options ? home.packages) {
      systemd.user = lib.mkIf cfg.notifications.enable {
        services.dashnix-security-notify = {
          Unit = {
            Description = "Notify about DashNix security and update reports";
            PartOf = ["graphical-session.target"];
            After = ["graphical-session.target"];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${script} notify --config ${notifySettings}";
            UMask = "0077";
            NoNewPrivileges = true;
          };
        };
        timers.dashnix-security-notify = {
          Unit.PartOf = ["graphical-session.target"];
          Install.WantedBy = ["graphical-session.target"];
          Timer = {
            OnStartupSec = "10m";
            OnUnitActiveSec = "15m";
          };
        };
      };
    }
  );
}
