{
  lib,
  rustPlatform,
  rustfmt,
  clippy,
}:
rustPlatform.buildRustPackage {
  pname = "dashnix-security-monitor";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src ./tests];
  };
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [rustfmt clippy];
  doCheck = true;
  preCheck = ''
    cargo fmt --check
    cargo clippy --offline --all-targets -- -D warnings
  '';
  meta = {
    description = "Unprivileged DashNix advisory and update reports";
    license = lib.licenses.lgpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "dashnix-security-monitor";
  };
}
