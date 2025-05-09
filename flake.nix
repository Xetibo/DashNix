{
  description = "DashNix";

  inputs = {
    unstable.url = "github:NixOs/nixpkgs/nixos-unstable";
    stable.url = "github:NixOs/nixpkgs/nixos-24.11";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nur.url = "github:nix-community/NUR";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "unstable";
    };

    sops-nix.url = "github:Mic92/sops-nix";

    Hyprspace = {
      url = "github:KZDKM/Hyprspace";
      inputs.hyprland.follows = "hyprland";
    };

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";

    ironbar = {
      url = "github:JakeStanger/ironbar";
      inputs.nixpkgs.follows = "unstable";
    };

    zen-browser.url = "github:youwen5/zen-browser-flake";

    # TODO move to upstream repository after merged nix flake pr
    fancontrol.url = "git+https://github.com/DashieTM/fancontrol-gui?ref=nix-flake";

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
    hyprdock.url = "github:Xetibo/hyprdock";
    reset.url = "github:Xetibo/ReSet";
    reset-plugins.url = "github:Xetibo/ReSet-Plugins";

    # absolute insanity
    chaoticNyx.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    dashvim = {
      url = "github:Xetibo/DashVim";
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
    unstable = import inputs.unstable {
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
        unstable
        stable
        ;
      system = currentSystem;
      lib = inputs.unstable.lib;
    };
    docs = import ./docs {
      inherit inputs;
      pkgs = unstable;
      system = currentSystem;
      lib = inputs.unstable.lib;
      build_systems = dashNixLib.build_systems;
    };
    dashNixInputs = inputs;
    stablePkgs = stable;
    unstablePkgs = unstable;
    modules = ./modules;
    iso = dashNixLib.buildIso.config.system.build.isoImage;
  };
}
