{
  lib,
  config,
  options,
  ...
}: {
  options.mods.oxi.oxirun = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables standalone OxiRun instead of the Oxibar launcher shortcut.";
    };
  };
  config = lib.mkIf (config.mods.oxi.oxirun.enable && config.mods.oxi.enable && config.mods.wm.suite == "oxi") (
    lib.optionalAttrs (options ? xdg.configFile) {
      programs.oxirun.enable = true;
    }
  );
}
