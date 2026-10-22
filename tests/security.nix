{
  inputs,
  pkgs,
  system,
}: let
  inherit (pkgs) lib;
  modules = [
    ../modules/programs/clam.nix
    ../modules/programs/security.nix
  ];
  check = name: condition: lib.assertMsg condition "Security preset check failed: ${name}";
  checkNixos = name: nixpkgs: let
    evaluate = settings:
      (nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs.mkDashDefault = import ../lib/override.nix {inherit (nixpkgs) lib;};
        modules =
          modules
          ++ [
            {
              system.stateVersion = "26.05";
            }
            settings
          ];
      }).config;
    legacy = evaluate {};
    desktop = evaluate {mods.security.enable = true;};
    server = evaluate {
      mods.security = {
        enable = true;
        preset = "server";
      };
    };
    sshServer = evaluate {
      mods.security = {
        enable = true;
        preset = "server";
      };
      services.openssh = {
        enable = true;
        ports = [2222];
      };
    };
    overridden = evaluate {
      mods.security = {
        enable = true;
        preset = "server";
      };
      networking.firewall = {
        enable = false;
        allowedTCPPorts = [8443];
      };
      services = {
        openssh = {
          enable = true;
          settings.PasswordAuthentication = true;
        };
        clamav = {
          scanner.enable = false;
          daemon.settings.MaxThreads = 1;
        };
      };
      nix.settings.trusted-users = ["root" "builder"];
      security.audit.rules = ["-w /etc/passwd -p wa -k accounts"];
    };
    disabledFeatures = evaluate {
      mods = {
        security = {
          enable = true;
          preset = "server";
          audit.enable = false;
          apparmor.enable = false;
          opensnitch.enable = false;
          ssh.enable = false;
          fail2ban.enable = false;
          tools.enable = false;
        };
        clam.enable = false;
      };
      services.openssh.enable = true;
    };
    customScan = evaluate {
      mods = {
        security.enable = true;
        clam.scanner = {
          interval = "monthly";
          persistent = false;
          scanDirectories = ["/etc" "/var/lib/nextcloud"];
        };
      };
    };
  in [
    (check "${name}: legacy ClamAV defaults" (
      legacy.services.clamav.daemon.enable
      && legacy.services.clamav.updater.enable
      && !legacy.services.clamav.scanner.enable
      && !legacy.security.auditd.enable
      && !legacy.services.opensnitch.enable
      && !(legacy.systemd.timers ? clamdscan)
    ))
    (check "${name}: desktop outbound firewall and auditing" (
      desktop.networking.firewall.enable
      && desktop.networking.firewall.logRefusedConnections
      && desktop.services.opensnitch.enable
      && desktop.services.opensnitch.settings.ProcMonitorMethod == "proc"
      && desktop.security.audit.enable
      && desktop.security.auditd.enable
      && desktop.security.audit.rules == ["-w /etc -p wa -k system_configuration"]
      && desktop.security.auditd.settings.max_log_file_action == "ROTATE"
      && !desktop.security.apparmor.enable
      && !desktop.services.fail2ban.enable
    ))
    (check "${name}: desktop scan catches missed weekly runs" (
      desktop.services.clamav.scanner.enable
      && desktop.systemd.timers.clamdscan.timerConfig.OnCalendar == "Sun *-*-* 12:00:00"
      && desktop.systemd.timers.clamdscan.timerConfig.Persistent
      && desktop.systemd.timers.clamdscan.timerConfig.RandomizedDelaySec == "15m"
      && desktop.services.clamav.daemon.settings.MaxThreads == 2
      && desktop.services.clamav.daemon.settings.AlertExceedsMax
      && desktop.systemd.services.clamav-daemon.serviceConfig.Nice == 10
    ))
    (check "${name}: server protections without enabling SSH" (
      !server.services.openssh.enable
      && server.services.fail2ban.enable
      && !(server.services.fail2ban.jails ? sshd)
      && !server.services.opensnitch.enable
      && server.security.apparmor.enable
      && lib.elem "apparmor" server.security.lsm
      && server.services.clamav.daemon.settings.MaxThreads == 4
      && server.systemd.timers.clamdscan.timerConfig.OnCalendar == "*-*-* 04:00:00"
      && server.systemd.timers.clamdscan.timerConfig.Persistent
    ))
    (check "${name}: SSH is key-only and Fail2ban follows custom ports" (
      sshServer.services.openssh.settings.PermitRootLogin
      == "no"
      && !sshServer.services.openssh.settings.PasswordAuthentication
      && !sshServer.services.openssh.settings.KbdInteractiveAuthentication
      && !sshServer.services.openssh.settings.X11Forwarding
      && !sshServer.services.openssh.settings.AllowAgentForwarding
      && sshServer.services.fail2ban.jails.sshd.settings.port == "2222"
    ))
    (check "${name}: Nix trust and persistent bounded logs" (
      desktop.nix.settings.trusted-users
      == ["root"]
      && server.nix.settings.trusted-users == ["root"]
      && desktop.nix.settings.sandbox
      && server.nix.settings.require-sigs
      && lib.hasInfix "Storage=persistent" desktop.environment.etc."systemd/journald.conf".text
      && lib.hasInfix "SystemMaxUse=512M" desktop.environment.etc."systemd/journald.conf".text
      && lib.hasInfix "SystemMaxUse=1G" server.environment.etc."systemd/journald.conf".text
    ))
    (check "${name}: native settings override preset defaults" (
      !overridden.networking.firewall.enable
      && lib.elem 8443 overridden.networking.firewall.allowedTCPPorts
      && overridden.services.openssh.settings.PasswordAuthentication
      && overridden.services.clamav.daemon.settings.MaxThreads == 1
      && lib.unique overridden.nix.settings.trusted-users == ["root" "builder"]
      && overridden.security.audit.rules == ["-w /etc/passwd -p wa -k accounts"]
      && !(overridden.systemd.timers ? clamdscan)
      && !(overridden.systemd.services ? clamdscan)
    ))
    (check "${name}: disabled features create no scan units" (
      !disabledFeatures.services.clamav.daemon.enable
      && !disabledFeatures.services.clamav.updater.enable
      && !disabledFeatures.security.auditd.enable
      && !disabledFeatures.security.apparmor.enable
      && !disabledFeatures.services.fail2ban.enable
      && disabledFeatures.services.openssh.settings.PasswordAuthentication
      && !(disabledFeatures.systemd.services ? clamav-daemon)
      && !(disabledFeatures.systemd.services ? clamdscan)
      && !(disabledFeatures.systemd.timers ? clamdscan)
    ))
    (check "${name}: existing ClamAV API overrides presets" (
      customScan.services.clamav.scanner.interval
      == "monthly"
      && customScan.services.clamav.scanner.scanDirectories == ["/etc" "/var/lib/nextcloud"]
      && !customScan.systemd.timers.clamdscan.timerConfig.Persistent
    ))
  ];
  evaluateHome = settings:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.mkDashDefault = import ../lib/override.nix {inherit lib;};
      modules =
        modules
        ++ [
          {
            home = {
              username = "security-test";
              homeDirectory = "/home/security-test";
              stateVersion = "26.05";
            };
          }
          settings
        ];
    }).config;
  legacyHome = evaluateHome {};
  desktopHome = evaluateHome {mods.security.enable = true;};
  serverHome = evaluateHome {
    mods.security = {
      enable = true;
      preset = "server";
    };
  };
  noUiHome = evaluateHome {
    mods.security = {
      enable = true;
      opensnitch.ui.enable = false;
    };
    mods.clam.gui.enable = false;
  };
  homeChecks = [
    (check "Home Manager: legacy GUI remains available" (lib.elem pkgs.clamtk legacyHome.home.packages))
    (check "Home Manager: desktop UI belongs to graphical session" (
      desktopHome.services.opensnitch-ui.enable
      && lib.elem "graphical-session.target" desktopHome.systemd.user.services.opensnitch-ui.Install.WantedBy
    ))
    (check "Home Manager: server has no interactive security GUI" (
      !serverHome.services.opensnitch-ui.enable
      && !(lib.elem pkgs.clamtk serverHome.home.packages)
      && !(serverHome ? networking)
      && !(serverHome ? security)
    ))
    (check "Home Manager: GUI toggles override desktop defaults" (
      !noUiHome.services.opensnitch-ui.enable
      && !(lib.elem pkgs.clamtk noUiHome.home.packages)
    ))
  ];
  evaluateFramework = settings:
    (inputs.self.nixosConfigurations.example.extendModules {
      modules = [
        # The framework currently imports two services.watt declarations.
        {disabledModules = ["services/hardware/watt.nix"];}
        settings
      ];
    }).config;
  legacyFramework = evaluateFramework {};
  desktopFramework = evaluateFramework {mods.security.enable = true;};
  overrideFramework = evaluateFramework {
    mods.security.enable = true;
    nix.settings.trusted-users = ["builder"];
  };
  frameworkChecks = [
    (check "Framework: preserve legacy user trust and restrict security presets" (
      lib.elem legacyFramework.conf.username legacyFramework.nix.settings.trusted-users
      && desktopFramework.nix.settings.trusted-users == ["root"]
      && lib.unique overrideFramework.nix.settings.trusted-users == ["root" "builder"]
    ))
  ];
  checks =
    lib.concatLists (lib.mapAttrsToList checkNixos {
      inherit (inputs) stable unstable;
    })
    ++ homeChecks
    ++ frameworkChecks;
in
  assert lib.all (result: result) checks;
    pkgs.runCommand "dashnix-security-presets" {} ''
      touch "$out"
    ''
