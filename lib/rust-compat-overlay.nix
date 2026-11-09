# Cargo's system-library policy requires explicit native dependencies.
final: prev: let
  withNativeLibraries = package: libraries:
    package.overrideAttrs (old: {
      nativeBuildInputs = prev.lib.unique ((old.nativeBuildInputs or []) ++ [(prev.lib.getBin final.pkg-config)]);
      buildInputs = prev.lib.unique ((old.buildInputs or []) ++ map prev.lib.getDev libraries);
    });
in
  {
    asm-lsp = withNativeLibraries prev.asm-lsp [final.zstd];
    flake-checker = withNativeLibraries prev.flake-checker [final.zstd];
    neocmakelsp = withNativeLibraries prev.neocmakelsp [final.oniguruma];
  }
  // prev.lib.optionalAttrs (prev ? pyrefly) {
    pyrefly = withNativeLibraries prev.pyrefly [final.zstd];
  }
  // prev.lib.optionalAttrs (prev ? codex) {
    codex =
      if prev.lib.versionAtLeast prev.codex.version "0.167.0"
      then withNativeLibraries prev.codex [final.aws-lc final.oniguruma final.sqlite final.zlib final.zstd]
      else prev.codex;
  }
