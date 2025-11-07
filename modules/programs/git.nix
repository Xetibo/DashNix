{
  lib,
  config,
  options,
  ...
}: {
  options.mods.git = {
    username = lib.mkOption {
      default = "";
      example = "globi";
      type = lib.types.str;
      description = "Git user name";
    };
    email = lib.mkOption {
      default = "";
      example = "globi@globus.glob";
      type = lib.types.str;
      description = "Git email";
    };
    additionalConfig = lib.mkOption {
      default = {
        merge = {
          tool = "nvimdiff";
        };
        diff = {
          tool = "nvimdiff";
        };
        pull.rebase = true;
      };
      example = {
        pull.rebase = false;
      };
      type = with lib.types; attrsOf anything;
      description = "Additional git config";
    };
    sshConfig = lib.mkOption {
      default = "";
      example = ''
        Host github.com
          ${
          if (config ? sops.secrets && config.sops.secrets ? hub.path)
          then "IdentityFile ${config.sops.secrets.hub.path}"
          else ""
        }
      '';
      type = lib.types.lines;
      description = "ssh configuration (keys for git)";
    };
  };
  config = lib.optionalAttrs (options ? programs.git && options ? home.file) {
    programs.git = {
      enable = true;
      settings =
        {
          user = {
            name = config.mods.git.username;
            inherit (config.mods.git) email;
          };
        }
        // config.mods.git.additionalConfig;
    };
    home.file.".ssh/config".text = config.mods.git.sshConfig;
  };
}
