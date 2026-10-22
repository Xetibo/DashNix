{
  description = "DashNix";

  inputs = {
    unstable.url = "github:NixOs/nixpkgs/nixos-unstable";
    stable.url = "github:NixOs/nixpkgs/nixos-26.05";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nur.url = "github:nix-community/NUR";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "unstable";
    };
    statix.url = "github:oppiliappan/statix?ref=master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "unstable";
    };
    cachy.url = "github:xddxdd/nix-cachyos-kernel?rev=a26503528b4a4ab7310c6167da549f8fbee91f30";

    sops-nix.url = "github:Mic92/sops-nix";

    # v0.56.2 supplies the matching Home Manager module.
    hyprland.url = "github:hyprwm/Hyprland/efb50993780079460b0cbed1363e2166a2de1d9f";
    # Unoverlaid release packages retain cache.nixos.org derivation hashes.
    hyprland-release.url = "github:NixOS/nixpkgs/c59305bab2065cfecc4944690d9eedbb56f3a9fa";

    ironbar = {
      url = "github:JakeStanger/ironbar";
      inputs.nixpkgs.follows = "unstable";
    };

    zen-browser.url = "github:youwen5/zen-browser-flake";

    stylix.url = "github:danth/stylix";
    base16.url = "github:SenchoPens/base16.nix";
    disko.url = "github:nix-community/disko/latest";

    anyrun.url = "github:Kirottu/anyrun";
    oxicalc.url = "github:Xetibo/OxiCalc";
    oxishut.url = "github:Xetibo/OxiShut";
    oxibar.url = "github:Xetibo/OxiBar/c2dbc96cb63fd3fa3c6d49abc8e771ef38d8d806";
    oxidash.url = "github:Xetibo/OxiDash";
    oxipaste.url = "github:Xetibo/OxiPaste";
    oxirun.url = "github:Xetibo/OxiRun";
    dashvim.url = "github:Xetibo/DashVim";

    # cachix branch always points at the latest cached commit; do not add
    # nixpkgs.follows here, it would change derivations and break the cache.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    nix-gaming.url = "github:fufexan/nix-gaming";

    hyprdock.url = "github:Xetibo/hyprdock";
    reset.url = "github:Xetibo/ReSet";
    reset-plugins.url = "github:Xetibo/ReSet-Plugins";

    superfreq.url = "github:NotAShelf/superfreq";

    compose.url = "github:garnix-io/nixos-compose";
  };

  nixConfig = {
    extra-substituters = ["https://hyprland.cachix.org" "https://noctalia.cachix.org"];
    extra-trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="];
  };

  outputs = {self, ...} @ inputs: let
    currentSystem = "x86_64-linux";
    permittedPackages = [
      "olm-3.2.16"
    ];
    importPkgsFn = import ./lib/importPkgs.nix;
    defaultConfigureFn = pkgs:
      importPkgsFn {
        inherit inputs currentSystem permittedPackages pkgs;
      };
    stable = defaultConfigureFn inputs.stable;
    unstable = defaultConfigureFn inputs.unstable;
  in rec {
    dashNixLib = import ./lib {
      inherit
        self
        inputs
        unstable
        permittedPackages
        ;
      dashNixAdditionalProps = {};
      system = currentSystem;
    };
    colorLib = import ./lib/colors.nix {
      inherit (inputs.unstable) lib;
    };
    docs = import ./docs {
      inherit inputs;
      pkgs = unstable;
      system = currentSystem;
      inherit (inputs.unstable) lib;
      inherit (dashNixLib) buildSystems;
    };
    lint = inputs.statix.packages.${currentSystem}.default;
    format = unstable.alejandra;
    checks.${currentSystem}.security = import ./tests/security.nix {
      inherit inputs;
      pkgs = unstable;
      system = currentSystem;
    };
    dashNixInputs = inputs;
    stablePkgs = stable;
    unstablePkgs = unstable;
    modules = ./modules;
    iso = dashNixLib.buildIso.config.system.build.isoImage;
    nixosConfigurations = dashNixLib.buildSystems {root = ./example/.;};

    mkFlake = stablePkgs.writeShellApplication {
      name = "Create example config";
      text =
        /*
        bash
        */
        ''
          mkdir -p ~/gits/nixos
          mkdir -p ~/gits/backup_nixos

          mv ~/gits/nixos/* ~/gits/backup_nixos/
          cp -r ${./example}/* ~/gits/nixos/
        '';
    };
  };
}
