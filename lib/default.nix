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
      inputs.cachy.overlays.pinned
      inputs.nur.overlays.default
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
in rec {
  mkNixos = {
    root,
    inputLib,
    lib,
    stablePkgs,
    unstablePkgs,
    stableMods,
    unstableMods,
    overridePkgs,
    stableInputs,
    unstableInputs,
    ...
  }:
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
              stableInputs
              unstableInputs
              mod
              additionalHomeConfig
              system
              root
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
            homeMods =
              if overridePkgs
              then unstableMods.home
              else stableMods.home;
            mkDashDefault = import ./override.nix {inherit lib;};
          };
          nixosMods =
            if overridePkgs
            then unstableMods.nixos
            else stableMods.nixos;
        in
          inputLib.nixosSystem {
            modules =
              [
                {_module.args = args;}
                mod
              ]
              ++ nixosMods
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

  mkHome = {
    root,
    lib,
    stablePkgs,
    unstablePkgs,
    stableMods,
    unstableMods,
    overridePkgs,
    ...
  }:
    builtins.listToAttrs (
      map
      (name: {
        inherit name;
        value = let
          mod = root + /homes/${name}/configuration.nix;
          additionalHomeConfig = root + /homes/${name}/home.nix;
          args = {
            inherit
              self
              inputs
              mod
              additionalHomeConfig
              system
              root
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
            userName = name;
            mkDashDefault = import ./override.nix {inherit lib;};
          };
          homeMods =
            if overridePkgs
            then unstableMods.home
            else stableMods.home;
        in
          inputs.home-manager.lib.homeManagerConfiguration
          {
            inherit (args) pkgs;
            modules =
              [
                {_module.args = args;}
                mod
              ]
              ++ homeMods
              ++ [
                ../home/common.nix
                ../home/themes
                ../home/sync.nix
                ./foxwrappers.nix
              ]
              ++ lib.optional (builtins.pathExists mod) mod;
          };
      })
      (
        lib.lists.remove "" (
          lib.attrsets.mapAttrsToList (name: fType:
            if fType == "directory"
            then name
            else "") (
            builtins.readDir (root + /homes)
          )
        )
      )
    );

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
  buildFunc = func: {
    root,
    unstableBundle ? {},
    stableBundle ? {},
    overridePkgs ? false,
    ...
  }: let
    defaultNixosMods = inputs: [
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
    ];

    defaultHomeMods = inputs: [
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
    ];

    unstableInput = unstableBundle.pkgs or inputs.unstable;
    stableInput = stableBundle.pkgs or inputs.stable;
    unstableConfig = unstableBundle.config or defaultConfig;
    stableConfig = stableBundle.config or defaultConfig;
    unstableInputs = (unstableBundle.inputs or {}) // inputs;
    stableInputs = (stableBundle.inputs or {}) // inputs;
    unstableMods = {
      home = (defaultHomeMods unstableInputs) ++ (unstableBundle.mods.home or []);
      nixos = (defaultNixosMods unstableInputs) ++ (unstableBundle.mods.nixos or []);
    };
    stableMods = {
      home = (defaultHomeMods stableInputs) ++ (stableBundle.mods.home or []);
      nixos = (defaultNixosMods stableInputs) ++ (stableBundle.mods.nixos or []);
    };

    unstablePkgs = mkPkgs {
      pkgs = unstableInput;
      config = unstableConfig;
    };
    stablePkgs = mkPkgs {
      pkgs = stableInput;
      config = stableConfig;
    };
    inputLib = unstableInput.lib;
    inherit (unstablePkgs) lib;
  in
    func {
      inherit lib inputLib stablePkgs unstablePkgs stableMods unstableMods stableInputs unstableInputs root overridePkgs;
    };

  buildSystems = buildFunc mkNixos;
  buildHome = buildFunc mkHome;

  buildIso = inputs.unstable.lib.nixosSystem {
    specialArgs = {
      inherit self inputs unstable;
    };
    modules = [
      ../iso/configuration.nix
    ];
  };
}
