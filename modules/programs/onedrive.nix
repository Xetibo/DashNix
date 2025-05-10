{
  lib,
  config,
  options,
  ...
}: {
  options.mods = {
    onedrive = {
      enable = lib.mkOption {
        default = false;
        example = true;
        type = lib.types.bool;
        description = "Enable onedrive program and service";
      };
    };
  };
  config = lib.mkIf config.mods.onedrive.enable (
    lib.optionalAttrs (options ? environment) {
      services.onedrive.enable = true;
      programs.onedrive.enable = true;
    }
  );
}
