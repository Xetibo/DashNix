{
  mkDashDefault,
  lib,
  config,
  options,
  pkgs,
  inputs,
  ...
}: {
  options.mods = {
    starship = {
      enable = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = ''
          Enables starship prompt
        '';
      };
      useDefaultPrompt = lib.mkOption {
        default = true;
        example = false;
        type = lib.types.bool;
        description = ''
          Enables preconfigured prompt
        '';
      };
      customPrompt = lib.mkOption {
        default = {};
        example = {};
        type = with lib.types; attrsOf anything;
        description = ''
          Custom configuration for prompt.
          Will be merged with preconfigured prompt if that is used.
        '';
      };
      colorChange = lib.mkOption {
        default = "darken";
        example = "ligthen";
        type = with lib.types; oneOf [(enum ["ligthen" "darken"]) str];
        description = ''
          colorChangeFunction to choose (prompt can be wrong if not used)
        '';
      };
      colorChangeAmount = lib.mkOption {
        default = 25;
        example = 20;
        type = lib.types.int;
        description = ''
          Amount to change the color by
        '';
      };
    };
  };

  # environment.systemPackages needed in order to configure systemwide
  config = lib.mkIf config.mods.starship.enable (
    lib.optionalAttrs (options ? environment.systemPackages) {
      programs.starship = let
        base16 = pkgs.callPackage inputs.base16.lib {};
        scheme = base16.mkSchemeAttrs config.stylix.base16Scheme;
        colorLib = import ../../lib/colors.nix {inherit lib;};
        colorChange =
          if config.mods.starship.colorChange == "darken"
          then colorLib.darkenColor
          else colorLib.ligthenColor;
        darkenedAccent = colorChange scheme.base0D config.mods.starship.colorChangeAmount;
        code_format = "[](bg:prev_bg fg:#${darkenedAccent})[ $symbol ($version)](bg:#${darkenedAccent})";
      in {
        enable = true;
        interactiveOnly = mkDashDefault true;
        presets = lib.mkIf config.mods.starship.useDefaultPrompt ["pastel-powerline"];
        settings =
          lib.mkIf config.mods.starship.useDefaultPrompt {
            # derived from https://starship.rs/presets/pastel-powerline
            format = "$username$directory$git_branch$git_status$git_metrics[ ](bg:none fg:prev_bg)";
            right_format = "$c$elixir$elm$golang$gradle$haskell$java$julia$nodejs$nim$rust$scala$python$ocaml$opa$perl$zig$dart$dotnet$nix_shell$shell$solidity[](bg:prev_bg fg:#${darkenedAccent})$time$os";
            username = {
              show_always = false;
              style_user = "bg:#${darkenedAccent} fg:#${scheme.base05}";
              style_root = "bg:#${darkenedAccent} fg:#${scheme.base05}";
              format = "[ $user ]($style)[](bg:#${darkenedAccent} fg:#${scheme.base05})";
              disabled = false;
            };
            os = {
              symbols = {
                NixOS = "  ";
              };
              style = "bg:#${darkenedAccent} fg:#${scheme.base05}";
              disabled = false;
            };
            directory = {
              style = "bg:#${darkenedAccent} fg:#${scheme.base05}";
              format = "[ $path ]($style)";
              truncation_length = 3;
              truncation_symbol = "…/";
            };
            git_branch = {
              always_show_remote = true;
              symbol = "";
              style = "bg:#${darkenedAccent} fg:#${scheme.base05}";
              format = "[ ](bg:#${darkenedAccent} fg:prev_bg)[$symbol ($remote_name )$branch ]($style)";
            };
            git_status = {
              staged = "+\${count} (fg:#${scheme.base0A})";
              ahead = "⇡\${count} (fg:#${scheme.base0A})";
              diverged = "⇕⇡\${count} (fg:#${scheme.base0A})";
              behind = "⇣\${count} (fg:#${scheme.base0A})";
              stashed = " ";
              untracked = "?\${count} (fg:#${scheme.base0A})";
              modified = "!\${count} (fg:#${scheme.base0A})";
              deleted = "✘\${count} (fg:#${scheme.base0A})";
              conflicted = "=\${count} (fg:#${scheme.base0A})";
              renamed = "»\${count} (fg:#${scheme.base0A})";
              style = "bg:#${darkenedAccent} fg:fg:#${scheme.base0A}";
              format = "[$all_status$ahead_behind]($style)";
            };
            git_metrics = {
              disabled = false;
              format = "([| ](bg:#${darkenedAccent})[+$added](fg:#${scheme.base0B} bg:#${darkenedAccent})[ -$deleted](fg:#${scheme.base08} bg:#${darkenedAccent}))";
            };
            c = {
              format = code_format;
            };
            elixir = {
              format = code_format;
            };
            elm = {
              format = code_format;
            };
            golang = {
              format = code_format;
            };
            gradle = {
              format = code_format;
            };
            haskell = {
              format = code_format;
            };
            java = {
              format = code_format;
            };
            julia = {
              format = code_format;
            };
            nodejs = {
              format = code_format;
            };
            nim = {
              format = code_format;
            };
            nix_shell = {
              symbol = "";
              format = code_format;
            };
            rust = {
              format = code_format;
            };
            scala = {
              format = code_format;
            };
            typst = {
              format = code_format;
            };
            python = {
              format = code_format;
            };
            ocaml = {
              format = code_format;
            };
            opa = {
              format = code_format;
            };
            perl = {
              format = code_format;
            };
            zig = {
              format = code_format;
            };
            dart = {
              format = code_format;
            };
            dotnet = {
              format = code_format;
            };
            time = {
              disabled = false;
              time_format = "%R"; # Hour:Minute Format
              style = "bg:#${darkenedAccent} fg:#${scheme.base05}";
              format = "[ $time ]($style)";
            };
          }
          // config.mods.starship.customPrompt;
      };
    }
  );
}
