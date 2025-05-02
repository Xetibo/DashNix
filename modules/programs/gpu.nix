{
  lib,
  config,
  options,
  pkgs,
  ...
}: {
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
        RUSTICL_ENABLE = "radeonsi";
      }
      else {};

    hardware = {
      nvidia = lib.mkIf config.mods.gpu.nvidia.enable {
        modesetting.enable = true;
        open = true;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
      graphics = let
        amdPackages = [
          (lib.mkIf (config.mods.gpu.intelgpu.enable && lib.mkIf config.mods.gpu.vapi.enable) pkgs.vpl-gpu-rt)
          (lib.mkIf (
              config.mods.gpu.intelgpu.enable && lib.mkIf config.mods.gpu.vapi.enable
            )
            pkgs.intel-media-driver)
          (lib.mkIf config.mods.gpu.vapi.enable pkgs.libvdpau-va-gl)
          (lib.mkIf config.mods.gpu.vapi.enable pkgs.libva)
          (lib.mkIf config.mods.gpu.vapi.enable pkgs.vaapiVdpau)
          (lib.mkIf (config.mods.gpu.intelgpu.enable || config.mods.gpu.amdgpu.enable) pkgs.mesa)
        ];
        rocmPackages = [
          pkgs.rocmPackages.clr.icd
          pkgs.mesa
          pkgs.mesa.opencl
          pkgs.vulkan-loader
          pkgs.vulkan-validation-layers
          pkgs.vulkan-tools
          pkgs.clinfo
        ];
      in {
        enable = true;
        enable32Bit = lib.mkDefault true;
        extraPackages =
          amdPackages
          ++ (lib.lists.optionals (config.mods.gpu.vapi.rocm.enable && config.mods.gpu.amdgpu.enable) rocmPackages);
      };
    };
  };
}
