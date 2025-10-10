{
  lib,
  config,
  options,
  pkgs,
  ...
}: {
  options.mods.printing = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables the piper program and its daemon";
    };
  };
  config = lib.mkIf config.mods.printing.enable (
    lib.optionalAttrs (options ? services.printing) {
      # Enable CUPS to print documents.
      environment.systemPackages = with pkgs; [
        simple-scan
      ];
      hardware.sane.enable = true;
      services = {
        printing = {
          enable = true;
          browsing = true;
          drivers = [pkgs.hplip];
          startWhenNeeded = true; # optional
        };
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };
      };
    }
  );
}
