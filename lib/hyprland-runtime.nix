{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  release = import ./hyprland-packages.nix {inherit inputs system;};
  mkDashDefault = import ./override.nix {inherit lib;};
  samePackage = actual: expected: actual != null && actual.drvPath == expected.drvPath;
  sameLibc = packages: package:
    (package.stdenv.cc.libc.outPath or null) == packages.stdenv.cc.libc.outPath;
  eglHelpers = ["egl-wayland" "egl-wayland2" "egl-gbm" "egl-x11"];
  graphicsHelpers = eglHelpers ++ ["nvidia-vaapi-driver"];
  isEglEnvironment = package:
    lib.elem (package.name or "") ["nvidia-egl-external-platforms" "nvidia-egl-external-platforms-x32"];
  replaceHelper = host: pinned: package: let
    name = lib.findFirst (name: toString package == toString host.${name}) null graphicsHelpers;
  in
    if name == null
    then package
    else pinned.${name};
  normalizeGraphics = host: pinned:
    builtins.map (package:
      if isEglEnvironment package
      then package.overrideAttrs (old: {paths = builtins.map (replaceHelper host pinned) old.paths;})
      else replaceHelper host pinned package);
  compatibleGraphics = pinned: package:
    if isEglEnvironment package
    then lib.all (path: lib.elem (toString path) (builtins.map (name: toString pinned.${name}) eglHelpers)) (package.paths or [])
    else
      sameLibc pinned package
      # ROCm's sysroot compiler has no cc.libc metadata. Match the exact
      # pinned ICD output instead, and never admit its native driver as 32-bit.
      || (pinned.stdenv.hostPlatform.system == "x86_64-linux" && toString package == toString pinned.rocmPackages.clr.icd);
  incompatibleNames = compatible: packages:
    lib.concatMapStringsSep ", " lib.getName (builtins.filter (package: !compatible package) packages);

  # Preserve the cached payload and its PATH suffix without executing a shell
  # after NixOS grants capabilities. Both launchers in this chain are ELF.
  launcher =
    release.runCommand "hyprland-native-launcher-${release.hyprland.version}" {
      nativeBuildInputs = [release.makeBinaryWrapper];
    } ''
      mkdir -p "$out/bin"
      makeBinaryWrapper ${release.hyprland}/bin/.Hyprland-wrapped "$out/bin/Hyprland" \
        --suffix PATH : ${lib.makeBinPath [release.binutils release.hyprland-qtutils release.pciutils release.pkgconf]}
    '';

  nixosConfig = let
    cfg = config.programs.hyprland;
    graphics = config.hardware.graphics;
    nvidiaEnabled = lib.elem "nvidia" config.services.xserver.videoDrivers;
    kernel = config.boot.kernelPackages.kernel;
    nvidia = config.hardware.nvidia.package;
    nvidiaModule =
      if config.hardware.nvidia.open != null && config.hardware.nvidia.open
      then nvidia.open
      else nvidia.mod;
    compatible32 = package:
      compatibleGraphics release.pkgsi686Linux package
      || (nvidiaEnabled && toString package == toString nvidia.lib32 && sameLibc release package);
  in
    lib.mkIf cfg.enable {
      programs.hyprland = {
        package = mkDashDefault release.hyprland;
        portalPackage = mkDashDefault release.xdg-desktop-portal-hyprland;
      };
      security.wrappers.Hyprland.source = lib.mkForce "${launcher}/bin/Hyprland";
      hardware = {
        graphics = {
          package = lib.mkDefault release.mesa;
          package32 = lib.mkIf (system == "x86_64-linux") (lib.mkDefault release.pkgsi686Linux.mesa);
        };
        nvidia.package = lib.mkIf nvidiaEnabled (mkDashDefault (
          # Userspace shares the compositor's libc; kernel modules retain the
          # configured kernel's build scope and compiler.
          (release.linuxPackagesFor kernel).nvidiaPackages.beta.override {inherit (release) stdenv;}
        ));
      };
      assertions = [
        {
          assertion = samePackage cfg.package release.hyprland && samePackage cfg.portalPackage release.xdg-desktop-portal-hyprland;
          message = "DashNix Hyprland and its portal must use lib/hyprland-packages.nix; update the release pins together instead of overriding individual packages.";
        }
        {
          assertion = samePackage graphics.package release.mesa && (!graphics.enable32Bit || samePackage graphics.package32 release.pkgsi686Linux.mesa);
          message = "DashNix Hyprland requires native and enabled 32-bit Mesa from lib/hyprland-packages.nix to avoid graphics ABI mismatches.";
        }
        {
          assertion = lib.all (compatibleGraphics release) graphics.extraPackages;
          message = "DashNix Hyprland graphics drivers must use its pinned libc/package set. Incompatible hardware.graphics.extraPackages: ${incompatibleNames (compatibleGraphics release) graphics.extraPackages}";
        }
        {
          assertion = !graphics.enable32Bit || lib.all compatible32 graphics.extraPackages32;
          message = "DashNix Hyprland 32-bit graphics drivers must use its pinned package set. Incompatible hardware.graphics.extraPackages32: ${incompatibleNames compatible32 graphics.extraPackages32}";
        }
        {
          assertion = !nvidiaEnabled || sameLibc release nvidia;
          message = "DashNix Hyprland requires NVIDIA userspace from its pinned package set, built for config.boot.kernelPackages.kernel.";
        }
        {
          assertion =
            !nvidiaEnabled
            || (nvidiaModule
              != null
              && nvidiaModule.version == "${nvidia.version}-${kernel.version}"
              && lib.elem "SYSSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/source" (nvidiaModule.makeFlags or [])
              && lib.elem "SYSOUT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" (nvidiaModule.makeFlags or []));
          message = "DashNix NVIDIA kernel module must match both the selected userspace driver version and the exact configured kernel build.";
        }
      ];
    };
in {
  options = {
    hardware.graphics = {
      # NixOS adds these helpers from host pkgs independently of the selected
      # NVIDIA package. Keep its version-specific EGL priority adjustments.
      extraPackages = lib.mkOption {
        apply = packages:
          if config.programs.hyprland.enable
          then normalizeGraphics pkgs release packages
          else packages;
      };
      extraPackages32 = lib.mkOption {
        apply = packages:
          if config.programs.hyprland.enable
          then normalizeGraphics pkgs.pkgsi686Linux release.pkgsi686Linux packages
          else packages;
      };
    };
  };
  config = nixosConfig;
}
