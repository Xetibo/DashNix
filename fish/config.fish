if status is-interactive
    # Commands to run in interactive sessions can go here
end
# =============================================================================
#
# Utility functions for zoxide.
#
set fish_greeting
function sudo --description "Replacement for Bash 'sudo !!' command to run last command using sudo."
    if test "$argv" = !!
        echo sudo $history[1]
        eval command sudo $history[1]
    else
        command sudo $argv
    end
end
alias ls='lsd'
alias :q='exit'
alias gh='git push origin'
alias gl='git pull origin'
alias gm='git commit -m'
alias ga="git add -A"
alias g+='bear -- g++ -Wextra -Werror -std=c++20'
alias s="kitty +kitten ssh"
alias zl='z "" '
alias jo='joshuto'
alias nv='neovide'
alias cr='cargo run'
alias grep='rg'
alias cat='bat'
alias find='fd'
alias rm='rip'

# pwd based on the value of _ZO_RESOLVE_SYMLINKS.
function __zoxide_pwd
    builtin pwd -L
end

# A copy of fish's internal cd function. This makes it possible to use
# `alias cd=z` without causing an infinite loop.
if ! builtin functions -q __zoxide_cd_internal
    if builtin functions -q cd
        builtin functions -c cd __zoxide_cd_internal
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

set __zoxide_z_prefix 'z!'

# Jump to a directory using only keywords.
function __zoxide_z
    set -l argc (count $argv)
    set -l completion_regex '^'(string escape --style=regex $__zoxide_z_prefix)'(.*)$'

    if test $argc -eq 0
        __zoxide_cd $HOME
    else if test "$argv" = -
        __zoxide_cd -
    else if test $argc -eq 1 -a -d $argv[1]
        __zoxide_cd $argv[1]
    else if set -l result (string match --groups-only --regex $completion_regex $argv[-1])
        __zoxide_cd $result
    else
        set -l result (command zoxide query --exclude (__zoxide_pwd) -- $argv)
        and __zoxide_cd $result
    end
end

# Completions for `z`.
function __zoxide_z_complete
    set -l tokens (commandline --current-process --tokenize)
    set -l curr_tokens (commandline --cut-at-cursor --current-process --tokenize)

    if test (count $tokens) -le 2 -a (count $curr_tokens) -eq 1
        # If there are < 2 arguments, use `cd` completions.
        __fish_complete_directories "$tokens[2]" ''
    else if test (count $tokens) -eq (count $curr_tokens)
        # If the last argument is empty, use interactive selection.
        set -l query $tokens[2..-1]
        set -l result (zoxide query --exclude (__zoxide_pwd) -i -- $query)
        and echo $__zoxide_z_prefix$result
        commandline --function repaint
    end
end

# Jump to a directory using interactive search.
function __zoxide_zi
    set -l result (command zoxide query -i -- $argv)
    and __zoxide_cd $result
end

# =============================================================================
#
# Commands for zoxide. Disable these using --no-cmd.
#

abbr --erase z &>/dev/null
complete --command z --erase
function z
    __zoxide_z $argv
end
complete --command z --no-files --arguments '(__zoxide_z_complete)'

abbr --erase zi &>/dev/null
complete --command zi --erase
function zi
    __zoxide_zi $argv
end

# =============================================================================
#
# To initialize zoxide, add this to your configuration (usually
# ~/.config/fish/config.fish):
#
#   zoxide init fish | source
#
# Note: zoxide only supports fish v3.4.0 and above.
#
