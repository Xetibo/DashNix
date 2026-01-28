{lib, ...}: {
  listToMapping = list:
    list
    |> (map (pkg: {
      name = let
        splits = lib.strings.splitString "-" pkg.name;
        alternativeName = builtins.head splits;
      in "${
        if (pkg ? pname)
        then pkg.pname
        else alternativeName
      }";
      value = pkg;
    }))
    |> lib.listToAttrs;
  mappingToList = mapping:
    mapping
    |> (lib.attrsets.mapAttrsToList (_: value: value))
    |> (builtins.filter (value: value != null));
}
