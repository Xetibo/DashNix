{
  config,
  lib,
  ...
}: let
  scheme = config.stylix.base16Scheme;
  slots = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];
in {
  font = config.mods.stylix.fonts.sansSerif.name;
  base24 = builtins.listToAttrs (map (slot: {
      name = lib.toLower slot;
      value = "#" + lib.removePrefix "#" scheme.${slot};
    })
    slots);
}
