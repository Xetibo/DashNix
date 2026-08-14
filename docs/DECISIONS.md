# Decisions

Log of notable design decisions for LLM continuity. Keep entries concise; do
not duplicate component-specific details that live in module code or docs.

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
