{ pkgs } : let

  oracle = import ./oracle { inherit pkgs; };

in {

  oracle-v0_4_0-build = oracle;
  haskell-cli-differential = import ./differential {
    inherit pkgs oracle;
  };

}
