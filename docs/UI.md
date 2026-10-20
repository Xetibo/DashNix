# UI

- Desktop behavior and appearance are configured through NixOS and Home Manager modules.
- Shared window-manager options describe monitors, workspaces, keybindings, environment variables, and startup commands.
- Hyprland desktop and OxiSession kiosk configurations are generated as Lua and launched through `start-hyprland`. Login input behavior and cursor appearance follow the resolved desktop settings, including keyboard variants, mouse/touchpad settings, and per-device overrides.
- Themes are managed through Stylix and the framework's color helpers.
- Shell, lockscreen, and login screen use the same palette and sans-serif font. Authentication wallpapers reference immutable Nix store assets; administrator-owned greeter settings never read the user's shell overrides.
- Prefer resident shell surfaces and IPC actions over launching duplicate panels or docks. Audio and brightness keys use shell actions so their OSD feedback stays consistent.
- Preserve host-specific layouts and existing theme conventions when changing shared desktop configuration.
