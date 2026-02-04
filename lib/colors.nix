{lib, ...}: rec {
  darkenColor = col: amt: let
    darken = value: clamp (value * (100 - amt) / 100);
    chars = map (x: lib.strings.toLower x) (lib.strings.stringToCharacters col);
    r = hexToBase10 (lib.lists.take 2 chars);
    g = hexToBase10 (lib.lists.take 2 (lib.lists.drop 2 chars));
    b = hexToBase10 (lib.lists.take 2 (lib.lists.drop 4 chars));
    rDark = base10ToHex (darken r);
    gDark = base10ToHex (darken g);
    bDark = base10ToHex (darken b);
  in "${rDark}${gDark}${bDark}";

  lightenColor = col: amt: let
    ligthen = value: clamp (value * (1 + amt / 100));
    chars = map (x: lib.strings.toLower x) (lib.strings.stringToCharacters col);
    r = hexToBase10 (lib.lists.take 2 chars);
    g = hexToBase10 (lib.lists.take 2 (lib.lists.drop 2 chars));
    b = hexToBase10 (lib.lists.take 2 (lib.lists.drop 4 chars));
    rDark = base10ToHex (ligthen r);
    gDark = base10ToHex (ligthen g);
    bDark = base10ToHex (ligthen b);
  in "${rDark}${gDark}${bDark}";

  clamp = x:
    if x < 0
    then 0
    else if x > 255
    then 255
    else x;
  hexToBase10 = chars: let
    first = builtins.elemAt chars 0;
    second = builtins.elemAt chars 1;
    firstInt = hexToBase10Map.${first};
    secondInt = hexToBase10Map.${second};
    firstIntCalc = power16 1 * firstInt;
    secondIntCalc = power16 0 * secondInt;
  in
    clamp (firstIntCalc + secondIntCalc);

  base10ToHex = value: let
    first = value / (power16 1);
    second = (value - first) / 16 |> builtins.toString;
    firstHex = base10ToHexMap.${builtins.toString first};
    secondHex = base10ToHexMap.${second};
  in "${firstHex}${secondHex}";

  power16 = power:
    if power > 0
    then (power16 (power - 1)) * 16
    else 1;
  hexToBase10Map = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };
  base10ToHexMap = {
    "0" = "0";
    "1" = "1";
    "2" = "2";
    "3" = "3";
    "4" = "4";
    "5" = "5";
    "6" = "6";
    "7" = "7";
    "8" = "8";
    "9" = "9";
    "10" = "a";
    "11" = "b";
    "12" = "c";
    "13" = "d";
    "14" = "e";
    "15" = "f";
  };
}
