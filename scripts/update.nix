{pkgs, ...}:
pkgs.writeShellApplication {
  name = "update";
  runtimeInputs = with pkgs; [
    coreutils
    git
    nix
  ];
  text =
    /*
    bash
    */
    ''
      if [[ -z "''${FLAKE:-}" ]]; then
        echo "FLAKE is not set" >&2
        exit 1
      fi

      d=$(date +%Y-%m-%d)
      v=$(nixos-version)

      cd "$FLAKE"

      git add -A
      if ! git diff --cached --quiet; then
        git commit -m "Pre update: $d-$v"
      fi

      nix flake update --flake "$FLAKE" --accept-flake-config

      git add -A
      if ! git diff --cached --quiet; then
        git commit -m "Post update: $d-$v"
      fi
    '';
}
