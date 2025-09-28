{lib, ...}: let
  wmWorkspace = with lib.types; {
    options = {
      name = lib.mkOption {
        default = "";
        example = "1";
        type = str;
        description = "Name of the workspace";
      };
      default = lib.mkOption {
        default = false;
        example = true;
        type = bool;
        description = "Whether the workspace is the default workspace. (Currently doesn't do anything on niri)";
      };
      monitor = lib.mkOption {
        default = "";
        example = "DP-1";
        type = str;
        description = "Name of the monitor to bind the workspace to";
      };
    };
  };

  wmOptions = with lib.types; {
    options = {
      name = lib.mkOption {
        default = "DP-1";
        example = "DP-1";
        type = str;
        description = "Name of the monitor";
      };
      resolutionX = lib.mkOption {
        default = 1920;
        example = 2560;
        type = number;
        description = "ResolutionX of the monitor";
      };
      resolutionY = lib.mkOption {
        default = 1080;
        example = 1440;
        type = number;
        description = "ResolutionY of the monitor";
      };
      refreshrate = lib.mkOption {
        default = 60;
        example = 144;
        type = number;
        description = "Refreshrate of the monitor";
      };
      positionX = lib.mkOption {
        default = 0;
        example = 1920;
        type = number;
        description = "PositionX of the monitor";
      };
      positionY = lib.mkOption {
        default = 0;
        example = 1080;
        type = number;
        description = "PositionY of the monitor";
      };
      scale = lib.mkOption {
        default = 1;
        example = 2;
        type = number;
        description = "Scale of the monitor";
      };
      transform = lib.mkOption {
        default = "0";
        example = "90";
        type = enum ["0" "90" "180" "270" "360"];
        description = "Transform of the monitor";
      };
      vrr = lib.mkOption {
        default = false;
        example = true;
        type = bool;
        description = "VRR status of the monitor";
      };
    };
  };

  modKeys = lib.types.enum ["Mod" "Super" "Alt" "Shift" "Ctrl"];

  customCommand = with lib.types; {
    options = {
      niri = lib.mkOption {
        default = null;
        example = "kitty";
        type = either null str;
        description = "Command to use in niri";
      };
      hyprland = lib.mkOption {
        default = null;
        example = "kitty";
        type = either null str;
        description = "Command to use in hyprland";
      };
    };
  };

  envOptions = with lib.types; {
    options = {
      all = lib.mkOption {
        default = {};
        example = {};
        type = attrsOf str;
        description = "General Env";
      };
      niri = lib.mkOption {
        default = {};
        example = {};
        type = attrsOf str;
        description = "Niri Env";
      };
      hyprland = lib.mkOption {
        default = {};
        example = {};
        type = attrsOf str;
        description = "Hyprland Env";
      };
    };
  };

  startupOptions = with lib.types; {
    options = {
      all = lib.mkOption {
        default = [];
        example = [];
        type = listOf str;
        description = "General Startup commands";
      };
      niri = lib.mkOption {
        default = [];
        example = [];
        type = listOf str;
        description = "Niri Startup commands";
      };
      hyprland = lib.mkOption {
        default = [];
        example = [];
        type = listOf str;
        description = "Hyprland Startup commands";
      };
    };
  };

  windowRuleOptions = with lib.types; {
    options = {
      niri = lib.mkOption {
        default = [];
        example = [];
        type = listOf lines;
        description = "Niri window rules";
      };
      hyprland = lib.mkOption {
        default = [];
        example = [];
        type = listOf str;
        description = "Hyprland window rules";
      };
    };
  };

  bindOptions = with lib.types; {
    options = {
      modKeys = lib.mkOption {
        default = [];
        example = ["Mod"];
        type = listOf modKeys;
        description = "List of modifier keys";
      };
      key = lib.mkOption {
        default = "";
        example = "Q";
        type = str;
        description = "Key to bind";
      };
      command = lib.mkOption {
        default = "";
        example = "killActive";
        type = either (submodule customCommand) (enum [
          "spawn"
          "spawn-sh"
          "quit"
          "killActive"
          "moveFocusUp"
          "moveFocusRight"
          "moveFocusDown"
          "moveFocusLeft"
          "moveWindowUp"
          "moveWindowRight"
          "moveWindowDown"
          "moveWindowLeft"
          "focusWorkspace"
          "moveToWorkspace"
          "toggleFloating"
          "toggleFullscreen"
        ]);
        description = "Command to execute";
      };
      args = lib.mkOption {
        default = [];
        example = [];
        type = listOf str;
        description = "Additional arguments for the command";
      };
      meta = lib.mkOption {
        default = {};
        example = {};
        type = submodule {
          options = {
            niri = lib.mkOption {
              default = {};
              type = submodule {
                options = {
                  desc = lib.mkOption {
                    default = "";
                    type = str;
                    description = "Description for Hotkey overview";
                  };
                  repeat = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Whether to repeat the keybind on hold";
                  };
                  allowInhibit = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Whether to allow inhibiting";
                  };
                  allowWhileLocked = lib.mkOption {
                    type = bool;
                    default = false;
                    description = "Whether to allow while locked";
                  };
                  cooldown = lib.mkOption {
                    type = number;
                    default = 0;
                    description = "Cooldown on bind";
                  };
                };
              };
              description = "Niri meta for keybinds";
            };
            hyprland = lib.mkOption {
              default = {};
              type = submodule {
                options = {
                  repeat = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Whether to repeat the keybind on hold";
                  };
                };
              };
              description = "Niri meta for keybinds";
            };
          };
        };
        description = "Custom metadata per bind. Note, only supported environments are taken into account.";
      };
    };
  };
in {
  options.mods.wm = {
    modKey = lib.mkOption {
      default = "Super";
      example = "Alt";
      type = modKeys;
      description = "Mod key";
    };

    env = lib.mkOption {
      default = {};
      example = {
        all = {
          EDITOR = "Neovim";
        };
        niri = {
          EDITOR = "Emacs";
        };
      };
      type = with lib.types; either (submodule envOptions) (attrsOf str);
      description = "Environment configuration";
    };

    useDefaultEnv = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Whether to use default env variables";
    };

    startup = lib.mkOption {
      default = [];
      example = {
        all = ["oxinoti"];
        niri = ["someniricommand"];
        hyprland = ["somehyprlandcommand"];
      };
      type = with lib.types; either (submodule startupOptions) (listOf str);
      description = "Start commands";
    };

    useDefaultStartup = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Whether to use default autostart commands";
    };

    useDefaultWindowRules = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Whether to use default window rules";
    };

    windowRules = lib.mkOption {
      default = [];
      example = {
        niri = [
          ''
            match app-id=r#"^org\.keepassxc\.KeePassXC$"#
            match app-id=r#"^org\.gnome\.World\.Secrets$"#

            block-out-from "screen-capture"
          ''
          ''
            match app-id=r#"^steam$"#
            open-on-workspace "0"
          ''
        ];
      };
      type = lib.types.submodule windowRuleOptions;
      description = "Window rules";
    };

    workspaces = lib.mkOption {
      default = [];
      example = [
        {
          name = "chat";
          monitor = "DP-1";
        }
      ];
      type =
        lib.types.listOf (lib.types.submodule wmWorkspace);
      description = "Workspace configuration";
    };

    monitors = lib.mkOption {
      default = [];
      example = [
        {
          name = "DP-1";
          resolutionX = 1920;
          resolutionY = 1080;
          refreshrate = 144;
          positionX = 0;
          positionY = 0;
          scale = 1;
          transform = "0";
          vrr = false;
        }
      ];
      type =
        lib.types.listOf (lib.types.submodule wmOptions);
      description = "Monitor configuration";
    };

    useDefaultBinds = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Whether to use default keybinds";
    };

    binds = lib.mkOption {
      default = [];
      example = [
        {
          modKeys = ["Mod"];
          key = "Q";
          command = "killActive";
          args = [];
          meta = {
            niri = {
              desc = "Kill the active window";
              repeat = false;
            };
            hyprland = {};
          };
        }
      ];
      type =
        lib.types.listOf (lib.types.submodule bindOptions);
      description = "Bind configuration";
    };
  };
}
