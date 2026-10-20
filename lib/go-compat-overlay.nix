# Compatibility shim for Go builder removals in recent nixpkgs.
#
# nixpkgs removed `buildGo125Module` on 2026-09-15 (Go 1.25 EOL), but some of
# our flake inputs (e.g. sops-nix's `pkgs/sops-install-secrets`) still build
# with it, which breaks evaluation of `sops.package` with:
#   error: Go 1.25 is end-of-life, and 'buildGo125Module' has been removed.
#
# Map the removed builder onto the current one until upstream migrates.
#
# NOTE: cannot gate on `prev ? buildGo125Module`, because nixpkgs keeps the
# removed name as a throwing alias (`pkgs/top-level/aliases.nix`), so `?`
# still returns true. Instead gate on the new builder: revisions that have
# `buildGo126Module` are the ones where `buildGo125Module` is EOL/removed.
# Older revisions are left completely untouched (returns {}).
# TODO: drop this shim once no input references `buildGo125Module` anymore.
final: prev:
if prev ? buildGo126Module
then {buildGo125Module = prev.buildGo126Module;}
else {}
