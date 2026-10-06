{ pkgs, oracle } : let

  candidate = pkgs.callPackage ../../package.nix {
    haskellPackages = pkgs.haskell.packages.ghc912;
  };
  harness = pkgs.haskell.packages.ghc912.callCabal2nix
    "gaw-differential-harness" ../../cabal/differential { };

in pkgs.runCommand "git-gaw-haskell-cli-differential" {

  nativeBuildInputs = [ pkgs.git ];
  GIT = pkgs.lib.getExe pkgs.git;
  GAW_ORACLE_EXECUTABLE = pkgs.lib.getExe oracle;
  GAW_HASKELL_EXECUTABLE = pkgs.lib.getExe candidate;

} (builtins.concatStringsSep "\n" [
  "${pkgs.lib.getExe' harness "git-gaw-differential"}"
  "touch \"$out\""
])
