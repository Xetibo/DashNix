# Decisions

Log of notable design decisions for LLM continuity. Keep entries concise; do
not duplicate component-specific details that live in module code or docs.

## 2026-10-26: ROCm ICD compatibility without compiler libc metadata

- The graphics guard rejected the already-pinned `rocmPackages.clr.icd` during an AMD/ROCm rebuild. Its custom ROCm sysroot compiler does not expose `stdenv.cc.libc`; missing metadata was not evidence of a package-set mismatch.
- Accept only the exact pinned native ICD output as an alternative to libc metadata. Host-derived ICDs and the native ICD in the 32-bit driver environment remain rejected. Preserve the cached ROCm derivation and compiler.
- Cover ROCm-enabled AMD configurations on both channels and negative ICD/package-architecture cases. Verify the consumer `spaceship` system derivation with the fixed local DashNix input without changing its dependency lock or activating a generation.

## 2026-10-26: ELF-safe Hyprland capabilities and enforced graphics agreement

- Current NixOS wraps Hyprland with `cap_sys_nice`, but cached nixpkgs 0.56.2 exposes a shell wrapper at `bin/Hyprland`. Keep NixOS's capability and integrity checks; build a small native launcher around the cached `bin/.Hyprland-wrapped` payload, preserving its binutils/Qt utilities/PCI/pkgconf PATH suffix. Do not rebuild the compositor or grant capabilities to a shell script.
- Import the unchanged release package set with unfree packages allowed for NVIDIA. Build its driver userspace with the release stdenv while deriving open/closed kernel modules from the actual host kernel's scope. Normalize NixOS's automatically added EGL and VA-API helpers to the same release, retaining its version-specific EGL priority adjustments.
- Reject inconsistent compositor/portal/Mesa derivations, native/32-bit graphics libc, NVIDIA userspace/module versions and exact kernel build paths. Build the built-in Hyprspace plugin against the pinned compositor; Home Manager rejects mismatched compositor/portal packages and plugin build metadata. Null Home Manager packages can still reuse system selections.
- Apply the shared NixOS runtime module through the base and installer imports; keep Home Manager assertions in its existing module scope. Extend merged graphics options with `apply` to normalize upstream-added helpers without replacing host `pkgs` or its kernel toolchain.
- Add a CI flake check for both channels, deliberate mismatch failures, real wrapper-integrity execution, ELF headers, and a cleared-environment launcher `--version` smoke test. Full activation/rendering remains a host-level check; existing full-system/installer evaluation blockers remain tracked separately.

## 2026-10-24: Faster unstable channel promotion

- Point the existing `unstable` input at `nixos-unstable-small` so default host, kernel, security-service, Home Manager, installer, and tooling package selections follow the faster-promoting channel together. Preserve the public input/output and bundle names and existing consumer overrides instead of mixing core packages across nixpkgs revisions.
- The small channel still exposes all nixpkgs packages; its smaller required build/test set trades binary coverage for faster updates. Keep release-pinned Hyprland/graphics and independent upstream cache graphs intact.
- Match CI's fallback channel and the example consumer to the new default. Correct the example/documented follows edge to `unstable`, matching both DashNix's input and `unstableBundle.pkgs`. Framework locks remain ignored and consumer-owned.
- The newer revision removes scripted initrd options. Drop the obsolete `boot.initrd.verbose` default; existing quiet kernel arguments and console log level continue to apply.
- Broader evaluation reproduced the installer's wireless/NetworkManager conflict and an upstream editor's removed `typescript-go` alias on the previous unstable revision; track them as existing verification blockers.

## 2026-10-22: Opt-in desktop and server security presets

- Add `mods.security.enable` (default false) and `preset = "desktop" | "server"`, preserving the existing `mods.clam` API. Both presets enable catch-up scan timers, bounded logging, targeted auditd records, firewall logging, conservative sysctls, and root-only Nix daemon trust. The base's legacy user trust grant applies only without a security preset.
- Desktop adds OpenSnitch with a graphical-session UI and a custom-kernel-compatible `proc` monitor, plus weekly/two-thread ClamAV scans. Server uses daily/four-thread scans, disables ClamTK by default, enables AppArmor support and Fail2ban, and hardens an already-enabled SSH service without enabling it itself. AppArmor profiles and application-specific jails remain host-owned.
- Use `mkDashDefault` for native defaults and actual native enable flags for unit/timer additions. Expose ClamTK and timer persistence controls in the existing ClamAV module. Put shared preset selections in `configuration.nix` and native system overrides in `hardware.nix`.
- Add a focused flake check for both pinned NixOS channels and direct Home Manager scope, plus a framework-example trust regression check with the known `services.watt` duplicate disabled. Runtime enforcement and remote-access recovery still require deployment checks.

## 2026-10-15: Opt-in YubiKey and PAM module

- Add `mods.yubikey` in `modules/programs/yubikey.nix`, disabled by default and imported with the shared program modules. System settings are emitted only in NixOS scope.
- Reuse NixOS's YubiKey Manager module for `ykman`, PC/SC, and udev rules. Install `pam_u2f` even with PAM disabled so enrollment is available in tools-only mode.
- Enabling the module enables U2F PAM by default, using upstream's `sufficient` control for key authentication with password fallback and a touch reminder. Expose a separate PAM toggle, control, runtime mapping path, and cue; preserve native NixOS service overrides through `mkDashDefault`.
- Keep enrollment outside Nix configuration and document a tools-only enrollment/rebuild workflow in `docs/src/README.md` (also exposed through the root README symlink). The greeter inherits the `login` PAM stack rather than defining its own U2F rule.

## 2026-10-14: Greeter environment survives PAM isolation

- The live OxiSession cursor still used Hyprland's fallback despite the generated service containing the correct Bibata theme. greetd builds the greeter's environment from PAM and does not pass through its daemon environment, dropping both cursor variables and `OXI_HYPRLAND_CONFIG`.
- Export the cursor theme, size, asset paths, XKB root/variant, and immutable Lua include from OxiSession's kiosk package wrapper. This restores cursor and input inheritance after the PAM boundary while preserving upstream session commands and explicit greeter overrides.
- Verify the installed wrapper from a cleared environment and decode configured cursor shapes through the pinned Xcursor library; daemon environment assertions alone missed this regression.

## 2026-10-14: OxiSession Hyprland Lua and desktop input parity

- Override only OxiSession's Hyprland package with the shared pinned desktop release and patch its kiosk to write Lua and launch `start-hyprland --path <Hyprland> -- --config <lua>`. Start the greeter child and apply the cursor from `hyprland.start`, after Wayland and IPC are ready. Preserve upstream authentication, private kiosk state, and session handoff.
- `start-hyprland` supervises a separate compositor PID. The owned-instance check now requires the recorded instance signature and kernel process-group membership in the kiosk launcher's group before dispatching exit; regression coverage rejects unrelated desktop instances.
- Generate an immutable Lua include from the primary user's resolved Home Manager `config.input`, `config.cursor`, and `device` settings. Share framework defaults through `lib/hyprland-input.nix`, preserving per-key override priorities. Cursor environment and package assets, keyboard layout/variant, and the system XKB root are available to the greeter user; user autostart commands and mutable configuration are not imported.

## 2026-10-13: Hyprland OxiSession kiosk default

- `mods.greetd.oxisession.backend` defaults to `"hyprland"`, so OxiSession's greetd login screen launches in its upstream-owned Hyprland kiosk. This supersedes the earlier Cage default; an explicit `"cage"` override remains supported.

## 2026-10-13: Oxi shell clipboard shortcut

- Mod+A (Super+A by default) invokes `oxibar oxipaste toggle` through the absolute package path and `spawn-sh` for both Niri and Hyprland. The resident picker takes precedence over the standalone app while the shell clipboard is enabled; the standalone binding remains a fallback.
- Advance Oxibar to `c2dbc96cb63fd3fa3c6d49abc8e771ef38d8d806`, which includes the picker command and its default Home Manager plugin package. Include `liboxipaste.so` in DashNix's enabled providers when `mods.oxi.oxibar.clipboard.enable` is true; explicit plugin settings remain authoritative.
- This supersedes the launcher/`:` clipboard shortcut below. The Tools `:` provider remains available. OxiPaste daemon installation/startup stays separately configured; the published daemon's missing new D-Bus methods are tracked in technical debt.

## 2026-10-12: Oxi resident shell and authentication

- Pin Oxibar to `a5e00d2d549e26154bd49f9f47a476cf904e742e`, the current full-shell/authentication revision on `wip`. Import its shell and locker Home Manager modules and NixOS authentication module without rewriting upstream dependencies.
- The default Oxi suite uses built-in launcher, controls, settings, session menu, overview, dock, and Tools clipboard. Old OxiRun/OxiDash/OxiShut/OxiPaste, ReSet, and hyprdock remain opt-in; OxiCalc remains suite-independent. Native audio/brightness actions provide OSD feedback. Battery insertion is deduplicated; settings recursively merge, with lists replacing defaults.
- Shared shortcuts use shell IPC: Mod+Space/R launcher, Mod+M controls, Mod+D session, Mod+Shift+D settings, Mod+W overview, Mod+A launcher followed by `:` for clipboard. Commands use absolute package paths; multi-argument calls use `spawn-sh` for both compositor backends. Optional shell systemd startup and the sleep watcher import Wayland environment before starting.
- Niri startup strings now run through the package set's runtime shell with escaped KDL arguments; previously multi-argument commands were treated as a single executable name, breaking environment import and service startup.
- OxiSession's greetd service receives the system XKB configuration root so custom layouts, including the framework's default `enIntUmlaut`, are available inside the owned kiosk.
- Replace ReGreet with OxiSession in `mods.greetd.greeter`; Oxi defaults to OxiSession, other suites to Noctalia. Use upstream's dedicated `oxisession` user, admin-owned `/etc/oxibar/auth.toml`, and Cage kiosk; preserve quiet Hyprland desktop entries for real user sessions. `greeterCommand = null` uses upstream defaults; explicit overrides remain supported. Greeter console output goes to journald.
- OxiLock replaces default Hyprlock only in Oxi. NixOS installs PAM and polkit; Home Manager owns appearance and the sole sleep watcher. Mod+Shift+L locks; Mod+Shift+Alt+L uses `oxilock-sleep --suspend`, waiting for lock readiness. Hibernate requires enabled sleep integration. Standalone homes still need administrator-installed PAM policy.
- `lib/oxi-theme.nix` shares resolved Stylix Base16 colors as lowercase `theme.base24` slots plus font across shell, locker, and greeter; auth wallpaper is a Nix store asset. User shell overrides cannot affect administrator greeter settings.
- Existing ReGreet-specific options/settings are removed. Greeter output/scale options remain Noctalia-only because OxiSession's kiosk owns output configuration. Upstream lacks direct clipboard IPC, keyboard variants in the kiosk, and a strict hibernate helper; track these limitations in technical debt.
- Verification passed for 12 system/home configuration variants, standalone Home Manager modules, generated shell/authentication/greetd TOML, pinned Niri and Hyprland config validation, formatting, and documentation. Statix reports six existing warnings; full-system evaluation remains blocked by the unrelated `services.watt` duplicate. Runtime authentication has not been activated or tested.

## 2026-10-06: Noctalia configuration schema 15

- Generated Noctalia TOML defaults to `config_version = 15` via `mkDashDefault`, preserving per-key user overrides. Existing framework settings already use current keys and need no other migration.
- Schema 15 replaces `dock.monitors` with `dock.monitor.<name>` overrides; DashNix has no legacy dock monitor defaults to migrate.

## 2026-10-02: Noctalia suite variant via mods.wm.suite

- `mods.wm.suite` enum `oxi`/`noctalia`/`none` (default `oxi`) selects the shell for both niri and Hyprland; default preserves existing behavior.
- New `modules/programs/noctalia.nix` (`mods.noctalia`) drives upstream `programs.noctalia` (HM scope) plus `recommendedServices` (NixOS scope, per-scope gating via `options ? ...` since nixpkgs ships its own NixOS `programs.noctalia` without settings). Theming intentionally goes through the stylix noctalia target, which derives its palette from the same `stylix.base16Scheme` (accent override respected), avoiding a competing custom palette; user `settings`/`customPalettes` pass through to the upstream module. Dashnix ships noctalia bar defaults (full-width `bar.main` with zero margins/radius, thickness 38, bar font_scale 1.15, clock 1.35 in the `primary` palette role tracking the dashnix accent, workspaces 1.25), all mkDashDefault so user `mods.noctalia.settings` win per key.
- Flake input `noctalia` tracks `github:noctalia-dev/noctalia/cachix` (latest cached commit) with no `nixpkgs.follows`, preserving its binary cache (`noctalia.cachix.org`); wired into `defaultHomeMods` and both cache lists (`base/common_hardware.nix`, root and example `nixConfig`).
- All `mods.oxi.*` configs additionally require `suite == "oxi"`, so switching suites removes oxi packages without touching per-app enables; oxicalc is exempt as compositor-independent (stays enabled with its Mod+G bind and float rule in every suite). Ironbar stays independent. Shared `lib/wm.nix` startup/binds/window-rules are suite-aware (noctalia autostart, float rules, launcher on Mod+Space/Mod+R, control-center on Mod+M, session menu on Mod+D replacing oxishut, clipboard on Mod+A replacing oxipaste, settings on Mod+Shift+D since Mod+Comma is niri's consume-window-into-column; hyprland no-anim layer rule for noctalia namespaces).

## 2026-10-02: Cached Hyprland release and matching graphics stack

- User requested latest release rather than latest master commit. Pin v0.56.2's module input to `efb50993780079460b0cbed1363e2166a2de1d9f`.
- Upstream release-flake compositor had a cache miss. Select official nixpkgs v0.56.2 from `c59305bab2065cfecc4944690d9eedbb56f3a9fa` without overlays. The shared helper asserts the expected version and supplies runtime packages to greetd, Home Manager, GPU configuration, and the ISO.
- `/tmp/hyprgreet.log` identified the startup failure: master compositor's glibc 2.42 could not load host Mesa requiring `GLIBC_2.43`. Match graphics packages to the pinned compositor instead of mixing package sets.
- Enable caches through `nix.settings.substituters`; `trusted-substituters` alone only permits their use. Root flake cache settings are required separately because dependency `nixConfig` is not inherited.
- Consumer `/home/dashie/gits/nixos` uses a local path input so uncommitted framework fixes are included when refreshing its locked source snapshot. Preserve its unrelated dependency revisions. Stale ignored framework lock was moved to `/tmp/opencode/dashnix-flake-lock-before-consumer-sync.json`; dependency lock remains consumer-owned.
- Keep the installer's XWayland build flag enabled to match the official cached compositor; disabling it changes the derivation and requires a source build.
- Verified consumer system/Home Manager compositor derivations match official cached package; compositor, portal, and both Mesa architectures fetched with local builds disabled; generated session and greeter Lua parsed successfully; spaceship system derivation evaluated successfully. Validation executes Lua startup commands, so future checks must stub `hl.exec_cmd`.

## 2026-08-14: OxiBar configurable via mods.oxi.oxibar

`modules/programs/oxi/oxibar.nix` now exposes user-facing options instead of a
hardcoded `plugin_config`.

Options:
- `mods.oxi.oxibar.settings` (`attrsOf anything`) — full OxiBar `plugin_config`
  (plugins list, `[bar]`, per-plugin tables). Default is the previous hardcoded
  config.
- `mods.oxi.oxibar.clock.enable` (default `true`) — removes clock from the
  plugins list, from `bar.center`, and drops the `[clock]` section when unset.
- `mods.oxi.oxibar.battery.enable` (default `false`) — adds `libbattery.so` to
  plugins and `battery` to `bar.end`, and carries `settings.battery` into the
  generated config when set.

Decision: keep the `settings` option type `attrsOf anything` with a
`default`. Setting any sub-path of `settings` *replaces* the whole option value
under the module system (`anything` merge is shallow), so the final
`plugin_config` is computed as `lib.recursiveUpdate defaultSettings
cfg.settings` to regain deep-merge semantics (user keys win, defaults fill the
rest; lists replace wholesale). Enable toggles are applied on top. This mirrors
the ironbar `customConfig` + `useBatteryModule` pattern.

## 2026-08-05: Quiet Hyprland output during Plymouth -> greeter/session handoff

The user wants a seamless Plymouth -> Hyprland transition without compositor
debug output flashing on the TTY. Hyprland's own logging is untouched — it
still writes to `$XDG_RUNTIME_DIR/hypr/<instance>/hyprland.log`; only the
console (stdout/stderr) stream is redirected.

Decisions:

- **Greeter** (`mods.greetd.greeterCommand` default): append
  `> /tmp/hyprgreet.log 2>&1`. greetd runs commands via `sh(1)` with standard
  POSIX shell syntax, so a plain redirect works — no `bash -c` wrapper needed.
- **Session**: the nixpkgs `programs.hyprland` module registers
  `services.displayManager.sessionPackages = [cfg.package]` *in addition to*
  the framework's `mods.greetd.environments` list. To offer only quiet
  sessions, `modules/programs/greetd.nix` now:
  - wraps the Hyprland flake package via `pkgs.symlinkJoin` (`mkQuietSession`,
    name suffix `-quiet-session`): replaces `$out/bin/start-hyprland` with a
    wrapper that does `exec <real>/bin/start-hyprland "$@" >
    /tmp/hyprland-session.log 2>&1`, and patches
    `share/wayland-sessions/hyprland.desktop` `Exec=` to point at the wrapper
    (must `rm` the lndir symlinks before writing replacements — original store
    files are read-only). `passthru.providedSessions` is preserved (required by
    the `sessionPackages` type check).
  - sets `services.displayManager.sessionPackages = lib.mkForce sessionPackages`
    where `sessionPackages` maps the wrapper over `mods.greetd.environments`
    (matching by derivation equality against the flake hyprland package) —
    dropping nixpkgs' unwrapped `[cfg.package]` entry.
  - leaves `programs.hyprland.package` as the real flake package: wrapping it
    would break nixpkgs' `genFinalPackage` (the flake pkg's `.override` is a
    functor; a symlinkJoin result lacks `.override`), and the real package is
    still wanted for `systemPackages`/portal/xwayland handling.
- **Keybind fallback (not implemented)**: to view Hyprland debug on demand,
  bind `Mod+F8` to `spawn-sh` running
  `tail -f $XDG_RUNTIME_DIR/hypr/*/hyprland.log` via the framework's
  `mods.wm.binds` mechanism. The console redirect loses no debug info because
  Hyprland already logs there.

Known caveat: `flake.lock` is gitignored in this repo and was auto-rewritten
("Added input ...") by `nix eval`/`nix build` runs; the resolved nixpkgs input
rev changed from `0954f7ee...` to `e72e4f29...` (stale local lock). The two
revs' relevant module code is identical.
