{
  lib,
  config,
  options,
  ...
}: {
  options.mods.oxi.oxipaste = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables standalone OxiPaste and its clipboard daemon. Mod+A uses Oxibar's picker when the shell clipboard is enabled.";
    };
  };
  config = lib.mkIf (config.mods.oxi.oxipaste.enable && config.mods.oxi.enable && config.mods.wm.suite == "oxi") (
    lib.optionalAttrs (options ? xdg.configFile) {
      programs.oxipaste.enable = true;
      xdg.configFile."oxipaste/style.css" = {
        text = ''
          .main-window {
            padding: 10px;
            border-radius: 10px;
            border: 2px solid #2AC3DE;
          }

          .item-window {
            padding: 10px;
            border-radius: 10px;
            border: 2px solid #C0CAF5;
          }

          .item-button {
            background-color: #1A1B26;
            border-radius: 5px;
            border: 1px solid #6D728D;
          }

          .delete-button {
            margin: 5px 25px 5px 5px;
          }

          .item-box {
          }
        '';
      };
    }
  );
}
