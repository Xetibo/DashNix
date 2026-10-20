{
  lib,
  config,
  options,
  ...
}: {
  options.mods.oxi.oxishut = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables standalone OxiShut instead of the Oxibar session-menu shortcut.";
    };
  };
  config = lib.mkIf (config.mods.oxi.oxishut.enable && config.mods.oxi.enable && config.mods.wm.suite == "oxi") (
    lib.optionalAttrs (options ? xdg.configFile) {
      programs.oxishut.enable = true;
      xdg.configFile."oxishut/style.css" = {
        text = ''
          #mainwindow {
            border-radius: 10px;
          }

          .mainbox {
            border-radius: 5px;
            padding: 20px;
          }

          .button {
            margin: 5px;
            background-color: #2b2c3b;
            -gtk-icon-size: 5rem;
          }

          .button:hover {
            background-color: #3e4152;
          }
        '';
      };
    }
  );
}
