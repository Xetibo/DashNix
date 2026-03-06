# https://github.com/0xc000022070/zen-browser-flake/issues/9#issuecomment-2711057434
{inputs, ...}: let
  mkFirefoxModule = import "${inputs.home-manager.outPath}/modules/programs/firefox/mkFirefoxModule.nix";
in {
  imports = [
    (mkFirefoxModule {
      modulePath = [
        "programs"
        "zen-browser"
      ];
      name = "Zen Browser";
      wrappedPackageName = "zen";
      unwrappedPackageName = "zen-unwrapped";
      platforms = {
        linux = {
          vendorPath = ".zen";
          configPath = ".zen";
        };
        darwin = {
          configPath = "Library/Application Support/Zen";
        };
      };
    })
    (mkFirefoxModule {
      modulePath = [
        "programs"
        "librewolf-dashnix"
      ];
      name = "LibreWolf";
      description = "LibreWolf is a privacy enhanced Firefox fork.";
      wrappedPackageName = "librewolf";
      unwrappedPackageName = "librewolf-unwrapped";

      platforms.linux = {configPath = ".librewolf";};
      platforms.darwin = {
        configPath = "Library/Application Support/LibreWolf";
      };

      enableBookmarks = false;
    })
  ];
}
