# Technical Debt

- `flake.lock` is ignored by Git in this framework repository; consumer flakes own their tracked dependency locks. Explicit source revision pins are needed for components that must survive broad input updates.
- Full system builds involve many third-party inputs and can fail independently of the desktop compositor.
- Policy evaluation checks do not replace deployment tests of firewall prompts, remote access, audit loading, or application confinement. AppArmor requires workload-specific profiles and a compatible running kernel/LSM configuration.
- The base user retains the public `firstlogin` bootstrap password and broad administrator/container groups. Production hosts need explicit credential and privilege management; security presets do not rotate accounts or remove those grants.
- The upstream scheduled ClamAV unit joins scan roots without quoting; paths containing whitespace need a customized unit until this is corrected upstream.
- Current nixpkgs and the standalone `superfreq` module both declare `services.watt`; full service/configuration evaluation fails with duplicate options until that input integration is reconciled.
- The standalone `buildHome` helper passes priority-wrapped `pkgs` directly to Home Manager, failing before module evaluation. Standalone module checks need a direct Home Manager configuration with an unwrapped package set until the helper is corrected.
- Hyprland plugins from a different package set may not match the pinned compositor ABI; plugin compatibility requires separate verification when enabled.
- Binary-cache availability depends on upstream CI publishing the exact derivation, not just matching the source version.
- Upstream Hyprland release v0.56.2's flake compositor was absent from its Cachix cache when checked; the runtime uses the cached official nixpkgs release instead.
- An ignored framework `flake.lock` can override a consumer's nested locks when using a local path input. Keep it absent or deliberately synchronized rather than introducing stale unrelated dependency revisions.
- Sharing pinned graphics drivers prevents compositor libc mismatches but still requires runtime testing of graphics applications when host and pinned package sets differ.
- Oxibar's OxiPaste picker requires a separately running, updated OxiPaste daemon with payload-addressed `CopyContent`/`DeleteContent` D-Bus methods. The currently published OxiPaste `main` revision (`13e28873344d217bc4704c76f6114c0c7d56e848`) lacks those methods; copying/deleting through the picker needs the upstream daemon update.
- OxiSession's owned kiosk uses preferred output modes; the framework's greeter monitor/resolution/scale overrides apply to Noctalia only. Its Hyprland backend now inherits declarative input/cursor/device settings, but arbitrary desktop `extraConfig` Lua is not evaluated in the login kiosk.
- The pinned OxiSession revision requires a local compatibility patch for Hyprland Lua configuration, watchdog startup, and process-group ownership checks. Reconcile this patch when updating the upstream authentication package.
- OxiLock exposes a readiness-gated suspend command but no hibernate command. Hibernate relies on its logind sleep watcher and logind's bounded delay-inhibitor timeout; it is not an unlimited veto of external sleep requests.
