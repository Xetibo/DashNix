{
  mkDashDefault,
  lib,
  config,
  options,
  pkgs,
  inputs,
  system,
  ...
}: let
  # Mesa is loaded into the compositor process and must match its libc.
  graphicsPkgs =
    if config.programs.hyprland.enable
    then import ../../lib/hyprland-packages.nix {inherit inputs system;}
    else pkgs;
in {
  options.mods.gpu = {
    nvidia.enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = ''
        Enables nvidia support.
      '';
    };
    amdgpu.enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = ''
        Enables amdgpu support.
      '';
    };
    intelgpu.enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = ''
        Enables intel support.
      '';
    };
    vapi = {
      enable = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = ''
          Enables vapi.
        '';
      };
      rocm.enable = lib.mkOption {
        default = false;
        type = lib.types.bool;
        example = true;
        description = ''
          Enables rocm support.
        '';
      };
    };
  };

  config = lib.optionalAttrs (options ? boot) {
    boot = lib.mkIf config.mods.gpu.amdgpu.enable {
      kernelModules = ["kvm-amd"];
      initrd.kernelModules = ["amdgpu"];
      kernelParams = ["amdgpu.ppfeaturemask=0xffffffff"];
    };
    services.xserver.videoDrivers =
      if config.mods.gpu.amdgpu.enable
      then ["amdgpu"]
      else if config.mods.gpu.nvidia.enable
      then ["nvidia"]
      else [];

    environment.variables =
      if (config.mods.gpu.amdgpu.enable && config.mods.gpu.vapi.rocm.enable)
      then {
        RUSTICL_ENABLE = mkDashDefault "radeonsi";
      }
      else {};

    hardware = {
      nvidia = lib.mkIf config.mods.gpu.nvidia.enable {
        modesetting.enable = mkDashDefault true;
        open = mkDashDefault true;
        nvidiaSettings = mkDashDefault true;
        package = mkDashDefault config.boot.kernelPackages.nvidiaPackages.beta;
      };
      graphics = let
        amdPackages = [
          (lib.mkIf (config.mods.gpu.intelgpu.enable && config.mods.gpu.vapi.enable) graphicsPkgs.vpl-gpu-rt)
          (lib.mkIf (
              config.mods.gpu.intelgpu.enable && config.mods.gpu.vapi.enable
            )
            graphicsPkgs.intel-media-driver)
          (lib.mkIf config.mods.gpu.vapi.enable graphicsPkgs.libvdpau-va-gl)
          (lib.mkIf config.mods.gpu.vapi.enable graphicsPkgs.libva)
          (lib.mkIf config.mods.gpu.vapi.enable graphicsPkgs.libva-vdpau-driver)
        ];
        rocmPackages = [
          graphicsPkgs.rocmPackages.clr.icd
          graphicsPkgs.mesa.opencl
          graphicsPkgs.vulkan-loader
          graphicsPkgs.vulkan-validation-layers
          graphicsPkgs.vulkan-tools
          graphicsPkgs.clinfo
        ];
      in {
        enable = true;
        package = mkDashDefault graphicsPkgs.mesa;
        package32 = lib.mkIf (system == "x86_64-linux") (mkDashDefault graphicsPkgs.pkgsi686Linux.mesa);
        enable32Bit = mkDashDefault true;
        extraPackages =
          amdPackages
          ++ (lib.lists.optionals (config.mods.gpu.vapi.rocm.enable && config.mods.gpu.amdgpu.enable) rocmPackages);
      };
    };
  };
}
