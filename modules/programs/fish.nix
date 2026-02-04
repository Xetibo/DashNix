{
  lib,
  pkgs,
  inputs,
  config,
  options,
  ...
}: let
  base16 = pkgs.callPackage inputs.base16.lib {};
  scheme = base16.mkSchemeAttrs config.stylix.base16Scheme;
in {
  options.mods.fish = {
    enable = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Enables fish";
    };
    additionalConfig = lib.mkOption {
      default = {};
      example = {};
      type = with lib.types; attrsOf anything;
      description = "Additional fish config";
    };
    useDefaultConfig = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use default fish config";
    };
    enableZoxide = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use zoxide for changing directories";
    };
    enableNixIndex = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use nix-index";
    };
    enableDirenv = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use direnv";
    };
    enableStarship = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use starship";
    };
    enableYazi = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use yazi";
    };
    enableLsd = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use lsd";
    };
    enableWorktree = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use worktree switcher";
    };
  };
  config = let
    both = {
      nix-index = {
        enable = config.mods.fish.enableNixIndex;
        enableFishIntegration = config.mods.fish.enableNixIndex;
      };
      direnv = {
        enable = config.mods.fish.enableDirenv;
        enableFishIntegration = config.mods.fish.enableDirenv;
      };
      zoxide = {
        enable = config.mods.fish.enableZoxide;
        enableFishIntegration = config.mods.fish.enableZoxide;
      };
      fish =
        if config.mods.fish.useDefaultConfig
        then
          ({
              enable = true;
              shellAbbrs = {
                ls = "lsd";
                ":q" = "exit";
                gh = "git push origin";
                gu = "git push upstream";
                gl = "git pull origin";
                gm = "git commit -m";
                ga = "git add -A";
                gc = "git commit --amend --no-edit";
                "g+" = "bear -- g++ -Wextra -Werror -std=c++20";
                s = "kitty +kitten ssh";
                zl = "z ''";
                nv = "neovide";
                cr = "cargo run";
                grep = "rg";
                cat = "bat";
                find = "fd";
                rm = "rip";
                cp = "cpz";
                cd = "z";
                y = "yazi";
              };
              shellAliases = {
                rebuild = "nh os switch -- --accept-flake-config";
                update = "nix flake update --flake $FLAKE --accept-flake-config";
                gcli = "gh";
              };

              shellInit = ''
                export NIX_PATH="$NIX_PATH:${config.conf.nixosConfigPath}"

                set EDITOR "neovide --no-fork"

                set fish_color_autosuggestion '${scheme.base07}'
                set fish_color_param '${scheme.base06}'
                set fish_color_operator '${scheme.base0E}'

                set fish_greeting
              '';
            }
            // config.mods.fish.additionalConfig)
        else config.mods.fish.additionalConfig;
    };
  in
    lib.mkIf config.mods.fish.enable (
      (lib.optionalAttrs (options ? environment.systemPackages) {
        programs = both;
      })
      // (lib.optionalAttrs (options ? home.packages) {
        programs =
          {
            # starship.enableTransience.enable = config.mods.fish.enableStarship;
            yazi.enableFishIntegration = config.mods.fish.enableYazi;
            git-worktree-switcher = {
              enable = config.mods.fish.enableWorktree;
              enableFishIntegration = config.mods.fish.enableWorktree;
            };
          }
          // both;
      })
    );
}
