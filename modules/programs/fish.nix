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
      default = '''';
      example = '''';
      type = lib.types.lines;
      description = "Additional fish config";
    };
    useDefaultConfig = lib.mkOption {
      default = true;
      example = false;
      type = lib.types.bool;
      description = "Use default fish config";
    };
  };
  config = lib.mkIf config.mods.fish.enable (
    lib.optionalAttrs (options ? programs.fish) {
      programs.fish = {
        enable = true;
        shellInit =
          if config.mods.fish.useDefaultConfig
          then
            ''
              if status is-interactive
                  # Commands to run in interactive sessions can go here
              end

              # =============================================================================
              #
              # Utility functions for zoxide.
              #

              export NIX_PATH="$NIX_PATH:${config.conf.nixosConfigPath}"

              set EDITOR "neovide --no-fork"

              alias rebuild='nh os switch -- --accept-flake-config'
              alias update='nix flake update --flake $FLAKE --accept-flake-config'
              alias gcli='gh'
              abbr --add ls 'lsd'
              abbr --add :q 'exit'
              abbr --add gh 'git push origin'
              abbr --add gu 'git push upstream'
              abbr --add gl 'git pull origin'
              abbr --add gm 'git commit -m'
              abbr --add ga "git add -A"
              abbr --add gc "git commit --amend --no-edit"
              abbr --add g+ 'bear -- g++ -Wextra -Werror -std=c++20'
              abbr --add s "kitty +kitten ssh"
              abbr --add zl 'z "" '
              abbr --add nv 'neovide'
              abbr --add cr 'cargo run'
              abbr --add grep 'rg'
              abbr --add cat 'bat'
              abbr --add find 'fd'
              abbr --add rm 'rip'
              abbr --add cp 'fcp'
              abbr --add cd 'z'
              abbr --add y 'yazi'

              set fish_color_autosuggestion '${scheme.base07}'
              set fish_color_param '${scheme.base06}'
              set fish_color_operator '${scheme.base0E}'

              set fish_greeting
              # pwd based on the value of _ZO_RESOLVE_SYMLINKS.
              function __zoxide_pwd
                  builtin pwd -L
              end

              # A copy of fish's internal cd function. This makes it possible to use
              # `alias cd=z` without causing an infinite loop.
              if ! builtin functions --query __zoxide_cd_internal
                  if builtin functions --query cd
                      builtin functions --copy cd __zoxide_cd_internal
                  else
                      alias __zoxide_cd_internal='builtin cd'
                  end
              end

              # cd + custom logic based on the value of _ZO_ECHO.
              function __zoxide_cd
                  __zoxide_cd_internal $argv
              end

              # =============================================================================
              #
              # Hook configuration for zoxide.
              #

              # Initialize hook to add new entries to the database.
              function __zoxide_hook --on-variable PWD
                  test -z "$fish_private_mode"
                  and command zoxide add -- (__zoxide_pwd)
              end

              # =============================================================================
              #
              # When using zoxide with --no-cmd, alias these internal functions as desired.
              #

              if test -z $__zoxide_z_prefix
                  set __zoxide_z_prefix 'z!'
              end
              set __zoxide_z_prefix_regex ^(string escape --style=regex $__zoxide_z_prefix)

              # Jump to a directory using only keywords.
              function __zoxide_z
                  set -l argc (count $argv)
                  if test $argc -eq 0
                      __zoxide_cd $HOME
                  else if test "$argv" = -
                      __zoxide_cd -
                  else if test $argc -eq 1 -a -d $argv[1]
                      __zoxide_cd $argv[1]
                  else if set -l result (string replace --regex $__zoxide_z_prefix_regex \'\' $argv[-1]); and test -n $result
                      __zoxide_cd $result
                  else
                      set -l result (command zoxide query --exclude (__zoxide_pwd) -- $argv)
                      and __zoxide_cd $result
                  end
              end

              # Completions.
              function __zoxide_z_complete
                  set -l tokens (commandline --current-process --tokenize)
                  set -l curr_tokens (commandline --cut-at-cursor --current-process --tokenize)

                  if test (count $tokens) -le 2 -a (count $curr_tokens) -eq 1
                      # If there are < 2 arguments, use `cd` completions.
                      complete --do-complete "\'\' "(commandline --cut-at-cursor --current-token) | string match --regex '.*/$'
                  else if test (count $tokens) -eq (count $curr_tokens); and ! string match --quiet --regex $__zoxide_z_prefix_regex. $tokens[-1]
                      # If the last argument is empty and the one before doesn't start with
                      # $__zoxide_z_prefix, use interactive selection.
                      set -l query $tokens[2..-1]
                      set -l result (zoxide query --exclude (__zoxide_pwd) --interactive -- $query)
                      and echo $__zoxide_z_prefix$result
                      commandline --function repaint
                  end
              end
              complete --command __zoxide_z --no-files --arguments '(__zoxide_z_complete)'

              # Jump to a directory using interactive search.
              function __zoxide_zi
                  set -l result (command zoxide query --interactive -- $argv)
                  and __zoxide_cd $result
              end

              # =============================================================================
              #
              # Commands for zoxide. Disable these using --no-cmd.
              #

              abbr --erase z &>/dev/null
              alias z=__zoxide_z

              abbr --erase zi &>/dev/null
              alias zi=__zoxide_zi

              # =============================================================================
              #
              # To initialize zoxide, add this to your configuration (usually
              # ~/.config/fish/config.fish):
              #
              #   zoxide init fish | source

              direnv hook fish | source
            ''
            + config.mods.fish.additionalConfig
          else config.mods.fish.additionalConfig;
      };
    }
  );
}
