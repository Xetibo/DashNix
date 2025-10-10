{
  mkDashDefault,
  lib,
  config,
  options,
  pkgs,
  ...
}: let
  module =
    if config.conf.cpu == "intel"
    then "kvm-intel"
    else if config.conf.cpu == "amd"
    then "kvm-amd"
    else "";
in {
  options.mods = {
    virtmanager.enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      example = true;
      description = ''


        Enables virt-manager kvm.
      '';
    };
  };

  config =
    lib.optionalAttrs (options ? virtualisation.libvirtd) {
      boot.kernelModules = [
        module
      ];
      programs.virt-manager.enable = true;
      environment.systemPackages = with pkgs; [
        spice
        spice-gtk
        spice-protocol
        virt-viewer
      ];
      virtualisation = {
        libvirtd = {
          enable = true;
          qemu = {
            package = mkDashDefault pkgs.qemu_kvm;
            swtpm.enable = mkDashDefault true;
          };
        };
        spiceUSBRedirection.enable = mkDashDefault true;
      };
      services.spice-vdagentd.enable = mkDashDefault true;

      users.users.${config.conf.username}.extraGroups = [
        "libvirtd"
        "kvm"
        "qemu-libvirtd"
      ];
    }
    // lib.optionalAttrs (options ? dconf.settings) {
      dconf.settings = {
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = ["qemu:///system"];
          uris = ["qemu:///system"];
        };
      };
    };
}
