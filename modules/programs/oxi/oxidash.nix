{
  lib,
  config,
  options,
  pkgs,
  inputs,
  ...
}: let
  # at time of using this here, stylix might not be evaluated yet
  # hence ensure it is by using base16 mkSchemeAttrs
  base16 = pkgs.callPackage inputs.base16.lib {};
  scheme = base16.mkSchemeAttrs config.stylix.base16Scheme;
in {
  options.mods.oxi.oxidash = {
    enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = "Enables standalone OxiDash instead of the Oxibar control-center shortcut.";
    };
  };
  config = lib.mkIf (config.mods.oxi.oxidash.enable && config.mods.oxi.enable && config.mods.wm.suite == "oxi") (
    lib.optionalAttrs (options ? xdg.configFile) {
      programs.oxidash.enable = true;
      xdg.configFile."oxidash/style.css" = {
        text = ''
          @define-color bg #${scheme.base00};
          @define-color primary #${scheme.base0D};

          #MainWindow {
            border-radius: 10px;
            background-color: transparent;
          }

          #MainBox {
            border-radius: 10px;
            border: 1px solid @primary;
            background-color: @bg;
          }

          #MainButtonBox {
            padding: 10px;
            margin: 5px 0px 5px 0px;
            border-radius: 5px;
            border: solid 1px @primary;
          }

          #DoNotDisturbButton {}

          #ExitButton {}

          #ClearNotificationsButton {}

          #NotificationsWindow {}

          .debugimage {
            border: solid 3px @primary;
          }

          .Notification {
            padding: 10px;
            margin: 5px 0px 5px 0px;
            border: solid 1px @primary;
            border-radius: 5px;
          }

          .CloseNotificationButton {
            margin: 0px 5px 0px 10px;
          }

          .PictureButtonBox {}

          .BaseBox {}
          }
        '';
      };
    }
  );
}
