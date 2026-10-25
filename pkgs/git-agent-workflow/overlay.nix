{ extraArgs }: final_: prev_: {
  git-agent-workflow = final_.callPackage ./package.nix {
    inherit (extraArgs) src;
    haskellPackages = final_.haskell.packages.ghc912;
  };
}
