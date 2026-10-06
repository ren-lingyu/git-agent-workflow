{

  description = "Git Agent Workflow (GAW)";

  inputs = {
    nixpkgs = {
      url = "git+https://github.com/NixOS/nixpkgs.git?ref=refs/heads/nixpkgs-unstable&shallow=1";
    };
    flake-parts = {
      url = "git+https://github.com/hercules-ci/flake-parts.git?ref=refs/heads/main&shallow=1";
    };
  };

  outputs = { self, ... }@inputs : let

    mkPackage_ = pkgs_ : pkgs_.callPackage ./package.nix {
      haskellPackages = pkgs_.haskell.packages.ghc912;
    };

  in inputs.flake-parts.lib.mkFlake { inherit inputs; } {

    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];

    flake = {
      overlays.default = final_ : prev_ : {
        git-agent-workflow = mkPackage_ final_;
      };
    };

    perSystem = { pkgs, ... } : let

      package_ = mkPackage_ pkgs;

    in {

      packages = {
        default = package_;
        git-agent-workflow = package_;
      };

      checks = pkgs.lib.mergeAttrsList [
        {
          git-agent-workflow = package_;
        }
        (import ./tests { inherit pkgs; })
      ];

    };

  };

}
