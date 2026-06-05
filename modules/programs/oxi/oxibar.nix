{
  lib,
  config,
  options,
  ...
}: {
  options.mods.oxi.oxibar = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables OxiBar";
    };
  };
  config = lib.mkIf (config.mods.oxi.oxibar.enable && config.mods.oxi.enable) (
    lib.optionalAttrs (options ? xdg.configFile) {
      programs.oxibar.enable = true;
    }
  );
}
