{
  mkDashDefault,
  pkgs,
  ...
}: let
  layout = pkgs.writeText "dashie" ''
    xkb_symbols "dashie"
    {
      include "us(basic)"
      include "level3(ralt_switch)"
      key <AC01> { [ a, A, adiaeresis, Adiaeresis ] };
      key <AD09> { [ o, O, odiaeresis, Odiaeresis ] };
      key <AD07> { [ u, U, udiaeresis, Udiaeresis ] };
    };
  '';
in {
  environment.systemPackages = mkDashDefault [pkgs.xorg.xkbcomp];
  services.xserver.xkb.extraLayouts.dashie = {
    description = "US layout with 'umlaut'";
    languages = ["eng"];
    symbolsFile = "${layout}";
  };
}
