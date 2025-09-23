{
  pkgs,
  lib,
  config,
  options,
  ...
}: {
  options.mods.yazi = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables yazi";
    };
    useDefaultConfig = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use default yazi config (if disabled only additionalConfig is used)";
    };
    additionalConfig = lib.mkOption {
      default = {};
      example = {};
      type = with lib.types; attrsOf anything;
      description = "Additional config for yazi";
    };
    useDefaultKeymap = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use default yazi keymap (if disabled only additionalKeymap is used)";
    };
    additionalKeymap = lib.mkOption {
      default = {};
      example = {};
      type = with lib.types; attrsOf anything;
      description = "Additional keymap for yazi";
    };
    plugins = lib.mkOption {
      default = {
        inherit (pkgs.yaziPlugins) piper diff gitui wl-clipboard;
      };
      example = {};
      type = with lib.types; attrsOf anything;
      description = "Additional keymap for yazi";
    };
  };
  config = let
    conf = import ./yazi.nix;
  in
    lib.optionalAttrs (options ? home.packages) (
      lib.mkIf config.mods.yazi.enable {
        home.packages = [pkgs.glow];
        programs.yazi = {
          inherit (conf) enable;
          settings = conf.settings // config.mods.yazi.additionalKeymap;
          keymap = conf.keymap // config.mods.yazi.additionalConfig;
          inherit (config.mods.yazi) plugins;
        };
      }
    );
}
