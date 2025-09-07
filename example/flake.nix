{
  description = "some dots";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
    stable.url = "github:NixOs/nixpkgs/nixos-24.05";
    dashNix = {
      url = "github:Xetibo/DashNix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        stable.follows = "stable";
      };
    };
  };

  outputs = inputs: {
    nixosConfigurations = inputs.dashNix.dashNixLib.buildSystems {root = ./.;};
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
      "https://dashvim.cachix.org"
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
      "dashvim.cachix.org-1:uLRdxp1WOWHnsZZtu3SwUWZRsvC7SXo0Gyk3tIefuL0="
    ];
  };
}
