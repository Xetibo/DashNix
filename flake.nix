{
  description = "DashNix";

  inputs = {
    unstable.url = "github:NixOs/nixpkgs/nixos-unstable";
    stable.url = "github:NixOs/nixpkgs/nixos-25.05";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nur.url = "github:nix-community/NUR";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "unstable";
    };
    statix.url = "github:oppiliappan/statix?ref=master";
    # Darkreader requires es20, hence a stable pin
    pkgsDarkreader.url = "github:NixOs/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "unstable";
    };

    sops-nix.url = "github:Mic92/sops-nix";

    hyprland.url = "github:hyprwm/Hyprland";

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
    oxinoti.url = "github:Xetibo/OxiNoti";
    oxidash.url = "github:Xetibo/OxiDash";
    oxipaste.url = "github:Xetibo/OxiPaste";
    oxirun.url = "github:Xetibo/OxiRun";
    dashvim.url = "github:Xetibo/DashVim";

    hyprdock.url = "github:Xetibo/hyprdock";
    reset.url = "github:Xetibo/ReSet";
    reset-plugins.url = "github:Xetibo/ReSet-Plugins";

    superfreq.url = "github:NotAShelf/superfreq";

    # absolute insanity
    chaoticNyx.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    compose.url = "github:garnix-io/nixos-compose";
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
    pkgsDarkreader = defaultConfigureFn inputs.pkgsDarkreader;
  in rec {
    dashNixLib = import ./lib {
      inherit
        self
        inputs
        unstable
        permittedPackages
        ;
      dashNixAdditionalProps = {
        inherit pkgsDarkreader;
      };
      system = currentSystem;
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
    dashNixInputs = inputs;
    stablePkgs = stable;
    unstablePkgs = unstable;
    modules = ./modules;
    iso = dashNixLib.buildIso.config.system.build.isoImage;
    nixosConfigurations = dashNixLib.buildSystems {root = ./example/.;};
  };
}
