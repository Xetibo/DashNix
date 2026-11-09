{
  inputs,
  pkgs,
  system,
}: let
  inherit (pkgs) lib;
  overlay = import ../lib/rust-compat-overlay.nix;
  check = name: condition: lib.assertMsg condition "Rust native dependency check failed: ${name}";
  channelChecks = name: nixpkgs: let
    packages = import ../lib/importPkgs.nix {
      inherit inputs;
      currentSystem = system;
      permittedPackages = [];
      pkgs = nixpkgs;
    };
    repeated = packages.appendOverlays [overlay];
    packageChecks = packageName: libraries: let
      package = packages.${packageName};
    in
      [
        (check "${name}: ${packageName} has pkg-config" (lib.elem (lib.getBin packages.pkg-config) package.nativeBuildInputs))
        (check "${name}: ${packageName} keeps Cargo's system-library policy" (!(package.dontCargoUseSystemLibs or false)))
        (check "${name}: ${packageName} overlay is idempotent" (package.drvPath == repeated.${packageName}.drvPath))
      ]
      ++ map (library: check "${name}: ${packageName} has ${library.pname}" (lib.elem (lib.getDev library) package.buildInputs)) libraries;
  in
    packageChecks "asm-lsp" [packages.zstd]
    ++ packageChecks "flake-checker" [packages.zstd]
    ++ packageChecks "neocmakelsp" [packages.oniguruma]
    ++ lib.optionals (packages ? pyrefly) (packageChecks "pyrefly" [packages.zstd])
    ++ lib.optionals (packages ? codex && lib.versionAtLeast packages.codex.version "0.167.0") (packageChecks "codex" (with packages; [aws-lc oniguruma sqlite zlib zstd]));
  checks = lib.concatLists (lib.mapAttrsToList channelChecks {inherit (inputs) stable unstable;});
in
  assert lib.all (result: result) checks;
    pkgs.runCommand "dashnix-rust-native-dependencies" {
      nativeBuildInputs = with pkgs; [asm-lsp flake-checker neocmakelsp] ++ lib.optional (pkgs ? pyrefly) pkgs.pyrefly ++ lib.optional (pkgs ? codex) pkgs.codex;
    } ''
      asm-lsp --help
      flake-checker --version
      neocmakelsp --version
      ${lib.optionalString (pkgs ? pyrefly) "pyrefly --version"}
      ${lib.optionalString (pkgs ? codex) "codex --version"}
      touch "$out"
    ''
