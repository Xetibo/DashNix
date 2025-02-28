{
  description = "DashNix";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
    stable.url = "github:NixOs/nixpkgs/nixos-24.11";
    nur.url = "github:nix-community/NUR";

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";

    Hyprspace = {
      url = "github:KZDKM/Hyprspace";
      inputs.hyprland.follows = "hyprland";
    };

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";

    ironbar = {
      url = "github:JakeStanger/ironbar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser.url = "github:youwen5/zen-browser-flake";

    stylix.url = "github:danth/stylix";
    base16.url = "github:SenchoPens/base16.nix";
    disko.url = "github:nix-community/disko/latest";

    anyrun.url = "github:Kirottu/anyrun";
    oxicalc.url = "github:DashieTM/OxiCalc";
    oxishut.url = "github:DashieTM/OxiShut";
    oxinoti.url = "github:DashieTM/OxiNoti";
    oxidash.url = "github:DashieTM/OxiDash";
    oxipaste.url = "github:DashieTM/OxiPaste";
    hyprdock.url = "github:DashieTM/hyprdock";
    reset.url = "github:Xetibo/ReSet";
    reset-plugins.url = "github:Xetibo/ReSet-Plugins";

    # absolute insanity
    chaoticNyx.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    dashvim = {
      url = "github:DashieTM/DashVim";
    };
  };

  outputs = {self, ...} @ inputs: let
    currentSystem = "x86_64-linux";
    permittedPackages = [
      "olm-3.2.16"
      # well done dotnet...
      # this is just for omnisharp
      "dotnet-core-combined"
      "dotnet-wrapped-combined"
      "dotnet-combined"
      "dotnet-sdk-6.0.428"
      "dotnet-sdk-wrapped-6.0.428"
      "dotnet-sdk-6.0.136"
      "dotnet-sdk-wrapped-6.0.136"
      "dotnet-sdk-7.0.120"
      "dotnet-sdk-wrapped-7.0.120"
      "dotnet-sdk-7.0.410"
      "dotnet-sdk-wrapped-7.0.410"
      "jitsi-meet-1.0.8043"
      "nextcloud-27.1.11"
    ];
    stable = import inputs.stable {
      system = currentSystem;
      config = {
        allowUnfree = true;
        permittedInsecurePackages = permittedPackages;
      };
      overlays = [
        inputs.nur.overlays.default
        inputs.chaoticNyx.overlays.default
      ];
    };
    pkgs = import inputs.nixpkgs {
      system = currentSystem;
      config = {
        allowUnsupportedSystem = true;
        permittedInsecurePackages = permittedPackages;
        # Often happens with neovim, this should not block everything.
        allowBroken = true;
        allowUnfree = true;
      };
      overlays = [
        inputs.nur.overlays.default
        inputs.chaoticNyx.overlays.default
      ];
    };
  in rec {
    dashNixLib = import ./lib {
      inherit
        self
        inputs
        pkgs
        stable
        ;
      lib = inputs.nixpkgs.lib;
    };
    docs = import ./docs {
      inherit inputs pkgs stable;
      lib = inputs.nixpkgs.lib;
      build_systems = dashNixLib.build_systems;
    };
    dashNixInputs = inputs;
    stablePkgs = stable;
    unstablePkgs = pkgs;
    modules = ./modules;
    iso = dashNixLib.buildIso.config.system.build.isoImage;
  };

  nixConfig = {
    builders-use-substitutes = true;

    extra-substituters = [
      "https://hyprland.cachix.org"
      "https://anyrun.cachix.org"
      "https://cache.garnix.io"
      "https://oxipaste.cachix.org"
      "https://oxinoti.cachix.org"
      "https://oxishut.cachix.org"
      "https://oxidash.cachix.org"
      "https://oxicalc.cachix.org"
      "https://hyprdock.cachix.org"
      "https://reset.cachix.org"
      "https://chaotic-nyx.cachix.org/"
    ];

    extra-trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "oxipaste.cachix.org-1:n/oA3N3Z+LJP7eIWOwuoLd9QnPyZXqFjLgkahjsdDGc="
      "oxinoti.cachix.org-1:dvSoJl2Pjo5HMaNngdBbSaixK9BSf2N8gzjP2MdGvfc="
      "oxishut.cachix.org-1:axyAGF3XMh1IyMAW4UMbQCdMNovDH0KH6hqLLRJH8jU="
      "oxidash.cachix.org-1:5K2FNHp7AS8VF7LmQkJAUG/dm6UHCz4ngshBVbjFX30="
      "oxicalc.cachix.org-1:qF3krFc20tgSmtR/kt6Ku/T5QiG824z79qU5eRCSBTQ="
      "hyprdock.cachix.org-1:HaROK3fBvFWIMHZau3Vq1TLwUoJE8yRbGLk0lEGzv3Y="
      "reset.cachix.org-1:LfpnUUdG7QM/eOkN7NtA+3+4Ar/UBeYB+3WH+GjP9Xo="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
    ];
  };
}
