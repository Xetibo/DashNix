{
  inputs,
  pkgs,
  system,
}: let
  inherit (pkgs) lib;
  check = name: condition: lib.assertMsg condition "Ironbar scope check failed: ${name}";
  modules = [
    ../modules/programs/ironbar.nix
    ../modules/programs/wm.nix
    ({lib, ...}: {
      options.mods = {
        hypr.hyprland.useIronbar = lib.mkEnableOption "Ironbar in Hyprland";
        oxi = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          oxibar.enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
        };
        noctalia.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };
      config.mods = {
        ironbar.useDefaultCss = false;
        wm.monitors = [{name = "eDP-1";}];
      };
    })
  ];
  evaluateScope = settings:
    (lib.evalModules {
      specialArgs = {
        inherit inputs pkgs;
        mkDashDefault = import ../lib/override.nix {inherit lib;};
      };
      modules =
        modules
        ++ [
          {options.programs.ironbar.enable = lib.mkEnableOption "system Ironbar integration";}
          settings
        ];
    }).config;
  scopeCheck = check "a system program namespace alone must not enable Home Manager definitions" (
    !(evaluateScope {}).programs.ironbar.enable
    && !(evaluateScope {mods.ironbar.enable = true;}).programs.ironbar.enable
    && !(evaluateScope {mods.hypr.hyprland.useIronbar = true;}).programs.ironbar.enable
  );
  channelChecks = name: nixpkgs: let
    evaluate = settings:
      (nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          mkDashDefault = import ../lib/override.nix {inherit (nixpkgs) lib;};
        };
        modules = modules ++ [{system.stateVersion = "26.05";} settings];
      }).config;
    disabled = evaluate {};
    enabled = evaluate {mods.ironbar.enable = true;};
    hyprland = evaluate {mods.hypr.hyprland.useIronbar = true;};
  in [
    (check "${name}: disabled Ironbar emits no Home Manager options in NixOS" (!(disabled.programs.ironbar.enable or false)))
    (check "${name}: enabled Ironbar stays in Home Manager scope" (!(enabled.programs.ironbar.enable or false)))
    (check "${name}: Hyprland Ironbar flag stays in Home Manager scope" (!(hyprland.programs.ironbar.enable or false)))
  ];
  evaluateHome = settings:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        inherit inputs;
        mkDashDefault = import ../lib/override.nix {inherit lib;};
      };
      modules =
        modules
        ++ [
          inputs.ironbar.homeManagerModules.default
          inputs.oxibar.homeManagerModules.default
          {
            home = {
              username = "ironbar-test";
              homeDirectory = "/home/ironbar-test";
              stateVersion = "26.05";
            };
            programs.oxibar.package = pkgs.hello;
          }
          settings
        ];
    }).config;
  disabledHome = evaluateHome {};
  oxiHome = evaluateHome {mods.ironbar.enable = true;};
  noctaliaHome = evaluateHome {
    mods.ironbar.enable = true;
    mods.wm.suite = "noctalia";
  };
  standaloneHome = evaluateHome {
    mods.ironbar.enable = true;
    mods.wm.suite = "none";
  };
  hyprlandHome = evaluateHome {mods.hypr.hyprland.useIronbar = true;};
  customHome = evaluateHome {
    mods.ironbar = {
      enable = true;
      useDefaultConfig = false;
      customConfig.position = "bottom";
      customCss = ".test {}";
    };
  };
  controlCommand = config: let
    widget =
      lib.findFirst
      (entry: entry ? bar && (builtins.head entry.bar).label == "")
      (throw "Ironbar control-center button missing")
      config.programs.ironbar.config.monitors.eDP-1.end;
  in
    (builtins.head widget.bar).on_click;
  homeChecks = [
    (check "Home Manager: disabled Ironbar creates no config file" (
      !disabledHome.programs.ironbar.enable
      && !(disabledHome.xdg.configFile ? "ironbar/config.json")
    ))
    (check "Home Manager: Oxi button uses the selected shell package" (
      oxiHome.programs.ironbar.enable
      && oxiHome.xdg.configFile ? "ironbar/config.json"
      && controlCommand oxiHome == "!${pkgs.hello}/bin/oxibar control-center toggle"
    ))
    (check "Home Manager: Noctalia and standalone button commands are preserved" (
      controlCommand noctaliaHome
      == "!noctalia msg panel-toggle control-center"
      && controlCommand standaloneHome == "!oxidash"
    ))
    (check "Home Manager: Hyprland Ironbar flag enables user configuration" hyprlandHome.programs.ironbar.enable)
    (check "Home Manager: custom configuration and CSS are preserved" (
      customHome.programs.ironbar.config.position
      == "bottom"
      && customHome.programs.ironbar.style == ".test {}"
    ))
  ];
  checks = [scopeCheck] ++ lib.concatLists (lib.mapAttrsToList channelChecks {inherit (inputs) stable unstable;}) ++ homeChecks;
in
  assert lib.all (result: result) checks;
    pkgs.runCommand "dashnix-ironbar-scope" {} ''
      touch "$out"
    ''
