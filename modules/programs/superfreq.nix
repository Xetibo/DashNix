{
  lib,
  options,
  config,
  ...
}: {
  options.mods.superfreq = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = ''Enables superfreq'';
    };
    settings = lib.mkOption {
      default = {};
      example = {};
      type = with lib.types; attrsOf anything;
      description = ''Superfreq config'';
    };
  };

  # TODO broken
  # config = lib.optionalAttrs (options ? services.superfreq) {
  #   services.superfreq = {
  #     enable = config.mods.superfreq.enable;
  #     settings = config.mods.superfreq.settings;
  #   };
  # };
}
