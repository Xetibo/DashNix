# Architecture

- DashNix is a Nix flake providing reusable NixOS and Home Manager modules.
- `lib/default.nix` exposes `dashNixLib.buildSystems` and `buildHome`, combining framework inputs with consumer host directories and package bundles.
- Shared system defaults live in `base/`, Home Manager defaults in `home/`, and configurable features in `modules/`.
- `example/` provides a consumer flake; `iso/` provides the installer image.
- Hyprland's module/source input is pinned to a release. Runtime compositor, portal, and graphics packages come from a separate revision-pinned, unoverlaid nixpkgs input via `lib/hyprland-packages.nix`, preserving official binary-cache derivations independently of consumer overlays and updates.
- The user session, Home Manager, installer, and OxiSession Hyprland kiosk share this package selection; Noctalia retains its upstream kiosk package. Mesa and userspace graphics drivers must use the compositor's package set because they are loaded into its process and depend on its libc ABI.
- Consumer flakes maintain their own lock graph and must configure build-time caches at the root; dependency `nixConfig` is not inherited.
- `mods.wm.suite` (`oxi`/`noctalia`/`none`, default `oxi`) selects the desktop shell suite for niri and Hyprland. Oxi uses the resident Oxibar shell, OxiLock, and OxiSession; standalone Oxi apps are opt-in except compositor-independent OxiCalc. Noctalia uses its upstream home module and nixpkgs NixOS integration.
- Authentication crosses a system/user boundary: NixOS owns greetd, its dedicated greeter user, session packages, and locker PAM policy; Home Manager owns shell settings, locker appearance, and the single per-user sleep watcher. Standalone Home Manager cannot install system PAM policy. Hardware-backed PAM authentication is opt-in, with enrollment data managed outside the Nix store.
- The Hyprland login kiosk inherits the primary user's resolved declarative input, cursor, and per-device settings through an immutable Lua file, with shared defaults when the desktop compositor is disabled. Its launcher exports the Lua path, cursor theme/assets, and XKB data after greetd's PAM environment isolation, making them available to the dedicated greeter user.
- Shell and authentication components share a pinned upstream revision and upstream dependency graph. Immutable Nix settings provide defaults; Oxibar's sparse user overrides remain a separate layer. A shared theme helper maps the resolved Stylix palette to canonical theme tokens for all Oxi surfaces.
