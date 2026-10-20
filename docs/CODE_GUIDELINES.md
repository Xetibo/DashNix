# Code Guidelines

- Keep changes small and consistent with existing functional Nix modules and helpers.
- Expose configuration through typed module options and use `mkDashDefault` for overridable framework defaults.
- Use the flake's `format` (Alejandra) and `lint` (Statix) outputs for tooling.
- Preserve upstream package dependency graphs when using upstream binary caches; changing nixpkgs or build inputs changes derivation hashes.
- Select desktop runtime packages through the shared pinned package helper rather than overlaid host packages; advance release version and package-set revision together.
- Bind greeter runtime environment in its launcher or command; greetd's PAM-created sessions do not inherit the systemd daemon environment.
- Document low-impact implementation decisions in `docs/DECISIONS.md`.
