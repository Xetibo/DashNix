{
  mkDashDefault,
  lib,
  config,
  options,
  pkgs,
  ...
}: let
  cfg = config.mods.security;
  isServer = cfg.preset == "server";
  defaults = lib.mapAttrs (_: mkDashDefault);
  journalSettings = {
    Storage = "persistent";
    SystemMaxUse =
      if isServer
      then "1G"
      else "512M";
    RuntimeMaxUse = "128M";
    MaxRetentionSec = "30day";
  };
  scanServiceSettings = {
    Nice = mkDashDefault 10;
    CPUWeight = mkDashDefault 20;
    IOWeight = mkDashDefault 20;
  };
in {
  options.mods.security = {
    enable = lib.mkEnableOption "the DashNix security preset";
    preset = lib.mkOption {
      type = lib.types.enum ["desktop" "server"];
      default = "desktop";
      description = "Security defaults for an interactive desktop or a server";
    };
    audit.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable auditd with a write/attribute watch on /etc";
    };
    apparmor.enable = lib.mkOption {
      type = lib.types.bool;
      default = isServer;
      defaultText = lib.literalExpression ''config.mods.security.preset == "server"'';
      description = "Enable AppArmor support; workload-specific policies still need configuration";
    };
    opensnitch = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = !isServer;
        defaultText = lib.literalExpression ''config.mods.security.preset == "desktop"'';
        description = "Enable the interactive OpenSnitch outbound firewall";
      };
      ui.enable = lib.mkOption {
        type = lib.types.bool;
        default = !isServer;
        defaultText = lib.literalExpression ''config.mods.security.preset == "desktop"'';
        description = "Start the OpenSnitch UI with the Home Manager graphical session";
      };
    };
    ssh.enable = lib.mkOption {
      type = lib.types.bool;
      default = isServer;
      defaultText = lib.literalExpression ''config.mods.security.preset == "server"'';
      description = "Apply key-only authentication defaults to an already-enabled OpenSSH server";
    };
    fail2ban.enable = lib.mkOption {
      type = lib.types.bool;
      default = isServer;
      defaultText = lib.literalExpression ''config.mods.security.preset == "server"'';
      description = "Enable Fail2ban; the SSH jail follows the native OpenSSH enable flag and ports";
    };
    tools.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Lynis and vulnix for manual hardening and vulnerability reviews";
    };
  };

  config = lib.mkIf cfg.enable (
    {
      mods.clam = {
        enable = mkDashDefault true;
        gui.enable = mkDashDefault (!isServer);
        scanner = {
          enable = mkDashDefault true;
          interval = mkDashDefault (
            if isServer
            then "*-*-* 04:00:00"
            else "Sun *-*-* 12:00:00"
          );
          persistent = mkDashDefault true;
        };
      };
    }
    // lib.optionalAttrs (options ? security.auditd) {
      networking.firewall = {
        enable = mkDashDefault true;
        logRefusedConnections = mkDashDefault true;
      };
      nix.settings = defaults {
        sandbox = true;
        require-sigs = true;
        trusted-users = ["root"];
      };
      boot.kernel.sysctl = defaults {
        "kernel.unprivileged_bpf_disabled" = 2;
        "kernel.kptr_restrict" = 2;
        "kernel.dmesg_restrict" = 1;
        "fs.protected_fifos" = 2;
        "fs.protected_regular" = 2;
        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.default.accept_redirects" = 0;
        "net.ipv4.conf.all.send_redirects" = 0;
        "net.ipv4.conf.default.send_redirects" = 0;
        "net.ipv6.conf.all.accept_redirects" = 0;
        "net.ipv6.conf.default.accept_redirects" = 0;
      };
      security = {
        audit = lib.mkIf cfg.audit.enable {
          enable = mkDashDefault true;
          rules = mkDashDefault ["-w /etc -p wa -k system_configuration"];
        };
        auditd = lib.mkIf cfg.audit.enable {
          enable = mkDashDefault true;
          settings = defaults {
            max_log_file = 64;
            num_logs = 5;
            max_log_file_action = "ROTATE";
          };
        };
        apparmor.enable = lib.mkIf cfg.apparmor.enable (mkDashDefault true);
      };
      services = {
        journald =
          if options ? services.journald.settings
          then {settings.Journal = defaults journalSettings;}
          else {
            storage = mkDashDefault journalSettings.Storage;
            extraConfig = mkDashDefault (lib.generators.toKeyValue {} (removeAttrs journalSettings ["Storage"]));
          };
        opensnitch = lib.mkIf cfg.opensnitch.enable {
          enable = mkDashDefault true;
          settings.ProcMonitorMethod = mkDashDefault "proc";
        };
        openssh.settings = lib.mkIf (cfg.ssh.enable && config.services.openssh.enable) (defaults {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          X11Forwarding = false;
          AllowAgentForwarding = false;
        });
        fail2ban = lib.mkIf cfg.fail2ban.enable {
          enable = mkDashDefault true;
          bantime = mkDashDefault "1h";
          maxretry = mkDashDefault 5;
          bantime-increment = {
            enable = mkDashDefault true;
            maxtime = mkDashDefault "1d";
          };
        };
        clamav.daemon.settings = lib.mkIf (config.mods.clam.enable && config.services.clamav.daemon.enable) (defaults {
          MaxThreads =
            if isServer
            then 4
            else 2;
          MaxFiles = 100000;
          MaxFileSize = "256M";
          MaxScanSize = "1024M";
          MaxRecursion = 30;
          MaxScanTime = 300000;
          AlertExceedsMax = true;
        });
      };
      systemd = {
        services = {
          clamav-daemon = lib.mkIf (config.mods.clam.enable && config.services.clamav.daemon.enable) {
            serviceConfig = scanServiceSettings;
          };
          clamdscan = lib.mkIf (config.mods.clam.enable && config.services.clamav.scanner.enable) {
            serviceConfig = scanServiceSettings;
          };
        };
        timers.clamdscan = lib.mkIf (config.mods.clam.enable && config.services.clamav.scanner.enable) {
          timerConfig.RandomizedDelaySec = mkDashDefault "15m";
        };
      };
      environment.systemPackages = lib.mkIf cfg.tools.enable [pkgs.lynis pkgs.vulnix];
    }
    // lib.optionalAttrs (options ? services.opensnitch-ui) {
      services.opensnitch-ui.enable = lib.mkIf (cfg.opensnitch.enable && cfg.opensnitch.ui.enable) (mkDashDefault true);
    }
  );
}
