{
  inputs,
  pkgs,
  system,
}: let
  inherit (pkgs) lib;
  release = import ../lib/hyprland-packages.nix {inherit inputs system;};
  check = name: condition: lib.assertMsg condition "Hyprland runtime check failed: ${name}";
  passes = config: lib.all (entry: entry.assertion) config.assertions;
  rejects = message: config:
    lib.any (entry: !entry.assertion && lib.hasInfix message entry.message) config.assertions;
  evaluate = nixpkgs: settings:
    (nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs system;
        mkDashDefault = import ../lib/override.nix {inherit (nixpkgs) lib;};
      };
      modules = [
        ../lib/hyprland-runtime.nix
        ../modules/programs/gpu.nix
        {
          nixpkgs.config.allowUnfree = true;
          system.stateVersion = "26.05";
          fileSystems."/" = {
            device = "/dev/disk/by-label/test-root";
            fsType = "ext4";
          };
          boot.loader.grub.devices = ["nodev"];
          programs.hyprland.enable = lib.mkDefault true;
        }
        settings
      ];
    }).config;
  desktop = evaluate inputs.unstable {};
  nvidia = evaluate inputs.unstable {
    mods.gpu.nvidia.enable = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;
  };
  channelChecks = name: nixpkgs: let
    host = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    graphics = evaluate nixpkgs {
      mods.gpu = {
        amdgpu.enable = true;
        intelgpu.enable = true;
      };
    };
    rocm = evaluate nixpkgs {
      mods.gpu = {
        amdgpu.enable = true;
        vapi.rocm.enable = true;
      };
    };
    proprietary = evaluate nixpkgs {mods.gpu.nvidia.enable = true;};
    disabled = evaluate nixpkgs {
      programs.hyprland.enable = false;
      mods.gpu.nvidia.enable = true;
    };
  in [
    (check "${name}: AMD/Intel graphics share the cached compositor stack" (passes graphics))
    (check "${name}: enabling ROCm accepts the pinned OpenCL ICD and graphics stack" (
      passes rocm
      && lib.any (package: toString package == toString release.rocmPackages.clr.icd) rocm.hardware.graphics.extraPackages
    ))
    (check "${name}: capability wrapper keeps root ownership, cap_sys_nice and the native launcher" (
      graphics.security.wrappers.Hyprland.owner
      == "root"
      && graphics.security.wrappers.Hyprland.group == "root"
      && graphics.security.wrappers.Hyprland.capabilities == "cap_sys_nice+ep"
      && graphics.security.wrappers.Hyprland.source == desktop.security.wrappers.Hyprland.source
    ))
    (check "${name}: NVIDIA userspace, EGL helpers, VA-API and both architectures agree" (passes proprietary))
    (check "${name}: disabling Hyprland retains native host drivers" (
      passes disabled
      && disabled.hardware.graphics.package.drvPath == host.mesa.drvPath
      && disabled.hardware.nvidia.package.drvPath == disabled.boot.kernelPackages.nvidiaPackages.beta.drvPath
    ))
  ];
  mismatchChecks = [
    (check "reject an independently overridden compositor" (rejects "Hyprland and its portal" (evaluate inputs.unstable {
      programs.hyprland.package = lib.mkForce pkgs.hyprland;
    })))
    (check "reject an independently overridden portal" (rejects "Hyprland and its portal" (evaluate inputs.unstable {
      programs.hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;
    })))
    (check "reject native Mesa from host nixpkgs" (rejects "native and enabled 32-bit Mesa" (evaluate inputs.unstable {
      hardware.graphics.package = lib.mkForce pkgs.mesa;
    })))
    (check "reject 32-bit Mesa from host nixpkgs" (rejects "native and enabled 32-bit Mesa" (evaluate inputs.unstable {
      hardware.graphics.package32 = lib.mkForce pkgs.pkgsi686Linux.mesa;
    })))
    (check "reject extra native drivers from host nixpkgs" (rejects "hardware.graphics.extraPackages:" (evaluate inputs.unstable {
      hardware.graphics.extraPackages = [pkgs.intel-media-driver];
    })))
    (check "reject extra 32-bit drivers from host nixpkgs" (rejects "hardware.graphics.extraPackages32:" (evaluate inputs.unstable {
      hardware.graphics.extraPackages32 = [pkgs.pkgsi686Linux.intel-media-driver];
    })))
    (check "reject a ROCm OpenCL ICD from host nixpkgs" (rejects "hardware.graphics.extraPackages:" (evaluate inputs.unstable {
      mods.gpu = {
        amdgpu.enable = true;
        vapi.rocm.enable = true;
      };
      hardware.graphics.extraPackages = [pkgs.rocmPackages.clr.icd];
    })))
    (check "reject the native ROCm OpenCL ICD in the 32-bit driver environment" (rejects "hardware.graphics.extraPackages32:" (evaluate inputs.unstable {
      hardware.graphics.extraPackages32 = [release.rocmPackages.clr.icd];
    })))
    (check "reject NVIDIA userspace from host nixpkgs" (rejects "NVIDIA userspace" (evaluate inputs.unstable {
      mods.gpu.nvidia.enable = true;
      hardware.nvidia.package = lib.mkForce pkgs.linuxPackages_latest.nvidiaPackages.beta;
    })))
    (check "reject matching NVIDIA userspace bound to a different kernel" (rejects "exact configured kernel build" (evaluate inputs.unstable {
      mods.gpu.nvidia.enable = true;
      boot.kernelPackages = pkgs.linuxPackages_latest;
      hardware.nvidia.package = lib.mkForce release.linuxPackages_latest.nvidiaPackages.beta;
    })))
    (check "closed NVIDIA modules retain the configured kernel scope" (passes (evaluate inputs.unstable {
      mods.gpu.nvidia.enable = true;
      hardware.nvidia.open = false;
      boot.kernelPackages = pkgs.linuxPackages_latest;
    })))
  ];
  evaluateHome = settings:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        inherit inputs system;
        mkDashDefault = import ../lib/override.nix {inherit lib;};
      };
      modules = [
        ../modules/programs/hypr/hyprland.nix
        {
          home = {
            username = "hyprland-test";
            homeDirectory = "/home/hyprland-test";
            stateVersion = "26.05";
          };
          mods.hypr.hyprland.useDefaultConfig = false;
          wayland.windowManager.hyprland.extraConfig = "-- Runtime package compatibility test";
        }
        settings
      ];
    }).config;
  pluginHome = evaluateHome {mods.hypr.hyprland.hyprspaceEnable = true;};
  rejectsHome = settings: let
    result = builtins.tryEval (passes (evaluateHome settings));
  in
    !result.success || !result.value;
  homeChecks = [
    (check "Home Manager: built-in plugin uses the exact compositor ABI" (passes pluginHome))
    (check "Home Manager: null package selections reuse the system compositor and portal" (passes (evaluateHome {
      wayland.windowManager.hyprland = {
        package = lib.mkForce null;
        portalPackage = lib.mkForce null;
      };
    })))
    (check "Home Manager: reject independently overridden compositor" (rejectsHome {
      wayland.windowManager.hyprland.package = lib.mkForce pkgs.hyprland;
    }))
    (check "Home Manager: reject independently overridden portal" (rejectsHome {
      wayland.windowManager.hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;
    }))
    (check "Home Manager: reject plugins built against another compositor" (rejectsHome {
      mods.hypr.hyprland.plugins = [pkgs.hyprlandPlugins.hyprspace];
    }))
  ];
  integrity = lib.findFirst (drv: drv.name == "ensure-wrapper-integrity") null desktop.system.checks;
  checks =
    lib.concatLists (lib.mapAttrsToList channelChecks {inherit (inputs) stable unstable;})
    ++ mismatchChecks
    ++ homeChecks
    ++ [
      (check "NixOS retains its ELF wrapper integrity check" (integrity != null))
      (check "NVIDIA uses the cached release userspace derivation with the host kernel" (
        passes nvidia
        && nvidia.hardware.nvidia.package.drvPath == release.linuxPackages_latest.nvidiaPackages.beta.drvPath
      ))
      (check "runtime compositor still matches official unoverlaid nixpkgs" (
        desktop.programs.hyprland.package.drvPath == inputs.hyprland-release.legacyPackages.${system}.hyprland.drvPath
      ))
    ];
in
  assert lib.all (result: result) checks;
    pkgs.runCommand "dashnix-hyprland-runtime" {
      nativeBuildInputs = [pkgs.binutils];
      wrapperIntegrity = integrity;
    } ''
      test -e "$wrapperIntegrity"
      mkdir -p "$out"
      readelf -h ${desktop.security.wrappers.Hyprland.source}
      readelf -h ${release.hyprland}/bin/.Hyprland-wrapped
      mkdir -m 700 "$TMPDIR/runtime"
      env -i HOME="$TMPDIR" XDG_RUNTIME_DIR="$TMPDIR/runtime" PATH=${release.coreutils}/bin \
        ${desktop.security.wrappers.Hyprland.source} --version > "$out/version"
      grep -F 'Hyprland ${release.hyprland.version}' "$out/version"
    ''
