{
  inputs,
  unstable,
  self,
  system,
  permittedPackages,
  dashNixAdditionalProps ? {},
  ...
}: let
  defaultConfig = {
    config = {
      allowUnfree = true;
      permittedInsecurePackages = permittedPackages;
    };
    overlays = [
      inputs.nur.overlays.default
      inputs.chaoticNyx.overlays.cache-friendly
    ];
    inherit system;
  };
  mkPkgs = {
    pkgs,
    config,
  }: let
    overlays =
      if (config ? overlays)
      then config.overlays
      else [];
    comnbinedConfig = config // {overlays = overlays ++ defaultConfig.overlays;};
  in
    import pkgs comnbinedConfig;
in {
  /*
  *
  # buildSystems

  Builds system given a list of system names which are placed within your hosts/ directory. Note that each system has its own directory in hosts/ as well.

  A minimal configuration requires the file configuration.nix within each system directory, this will be the base config that is used across both NisOS and home-manager, specific optional files can also be added, hardware.nix for NisOS configuration and home.nix for home-manager configuration.

  The second parameter is the root of your configuration, which should be ./. in most cases.

  `root`

  : the root path of your configuration

  # Example usage
  :::{.example}
  ```nix
  nixosConfigurations = buildSystems { root = ./.; };
  ```
  :::
  */
  # let
  #   paths = builtins.readDir ;
  #   names = lib.lists.remove "default" (
  #     map (name: lib.strings.removeSuffix ".nix" name) (lib.attrsets.mapAttrsToList (name: _: name) paths)
  #   );

  # in
  buildSystems = {
    root,
    additionalMods ? {
      nixos = [];
      home = [];
    },
    mods ? {
      nixos = [
        inputs.lanzaboote.nixosModules.lanzaboote
        inputs.nixos-wsl.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.stylix.nixosModules.stylix
        inputs.disko.nixosModules.disko
        inputs.superfreq.nixosModules.default
        inputs.sops-nix.nixosModules.sops
        ../base
        ../home
        ../modules
        inputs.chaoticNyx.nixosModules.default
      ];
      home = [
        inputs.anyrun.homeManagerModules.default
        inputs.ironbar.homeManagerModules.default
        inputs.oxicalc.homeManagerModules.default
        inputs.oxishut.homeManagerModules.default
        inputs.oxinoti.homeManagerModules.default
        inputs.oxidash.homeManagerModules.default
        inputs.oxipaste.homeManagerModules.default
        inputs.oxirun.homeManagerModules.default
        inputs.hyprdock.homeManagerModules.default
        inputs.hyprland.homeManagerModules.default
        inputs.reset.homeManagerModules.default
        inputs.sops-nix.homeManagerModules.sops
        inputs.dashvim.homeManagerModules.dashvim
        inputs.chaoticNyx.homeManagerModules.default
        ../modules
      ];
    },
    additionalInputs ? {},
    unstableBundle ? {},
    stableBundle ? {},
    overridePkgs ? false,
    ...
  }: let
    unstableInput = unstableBundle.pkgs or inputs.unstable;
    stableInput = stableBundle.pkgs or inputs.stable;
    unstableConfig = unstableBundle.config or defaultConfig;
    stableConfig = stableBundle.config or defaultConfig;

    unstablePkgs = mkPkgs {
      pkgs = unstableInput;
      config = unstableConfig;
    };
    stablePkgs = mkPkgs {
      pkgs = stableInput;
      config = stableConfig;
    };
    inputlib = unstableInput.lib;
    inherit (unstablePkgs) lib;
  in
    builtins.listToAttrs (
      map
      (name: {
        inherit name;
        value = let
          mod = root + /hosts/${name}/configuration.nix;
          additionalNixosConfig = root + /hosts/${name}/hardware.nix;
          additionalHomeConfig = root + /hosts/${name}/home.nix;
          args = {
            inherit
              self
              inputs
              mod
              additionalHomeConfig
              system
              root
              additionalInputs
              dashNixAdditionalProps
              lib
              ;
            stable = stablePkgs;
            unstable = unstablePkgs;
            pkgs = lib.mkForce (
              if overridePkgs
              then stablePkgs
              else unstablePkgs
            );
            alternativePkgs =
              if overridePkgs
              then unstablePkgs
              else stablePkgs;
            hostName = name;
            homeMods = mods.home;
            additionalHomeMods = additionalMods.home;
            mkDashDefault = import ./override.nix {inherit lib;};
          };
        in
          inputlib.nixosSystem {
            modules =
              [
                {_module.args = args;}
                mod
              ]
              ++ mods.nixos
              ++ additionalMods.nixos
              ++ lib.optional (builtins.pathExists additionalNixosConfig) additionalNixosConfig
              ++ lib.optional (builtins.pathExists mod) mod;
          };
      })
      (
        lib.lists.remove "" (
          lib.attrsets.mapAttrsToList (name: fType:
            if fType == "directory"
            then name
            else "") (
            builtins.readDir (root + /hosts)
          )
        )
      )
    );

  buildIso = inputs.unstable.lib.nixosSystem {
    specialArgs = {
      inherit self inputs unstable;
    };
    modules = [
      ../iso/configuration.nix
    ];
  };
}
