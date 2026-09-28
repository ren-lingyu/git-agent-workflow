{

  description = "Git Agent Workflow (GAW)";

  inputs = {
    nixpkgs = {
      url = "git+https://github.com/NixOS/nixpkgs.git?ref=refs/heads/nixpkgs-unstable&shallow=1";
    };
    flake-parts = {
      url = "git+https://github.com/hercules-ci/flake-parts.git?ref=refs/heads/main&shallow=1";
    };
    cl-nix-forge = {
      url = "git+https://github.com/nerima-lisp/cl-nix-forge.git?ref=refs/tags/v0.5.0&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, ... }@inputs : inputs.flake-parts.lib.mkFlake { inherit inputs; } {

    systems = [
      "x86_64-linux"
    ];

    flake = {
      overlays = {
        default = final: prev: {
          git = assert (prev.lib.assertMsg
            (prev.lib.versionAtLeast prev.git.version "2.43")
            "GAW requires Git >= 2.43, but got ${prev.git.version}"
          );
          prev.git;
        };
      };
    };

    perSystem = { system, pkgs, ... } :  let

      cl = inputs.cl-nix-forge.lib.${system};

      lispArgs = {
        lispSystem = pkgs.lib.removeSuffix ".asd" (builtins.baseNameOf ./git-agent-workflow.asd);
        version = cl.fromAsdSystem ./git-agent-workflow.asd;
        src = cl.mkLispSource {
          root = ./.;
        };
      };

    in {

      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          self.overlays.default
        ];
      };

      packages = {
        default = cl.mkExecutable {
          args = {
            pname = "git-gaw";
            inherit (lispArgs) lispSystem version src;
          };
          programPath = "git-gaw";
        };
      };

      checks = {
        "${lispArgs.lispSystem}-test" = cl.mkTestCheck (
          cl.lispDerivation {
            inherit (lispArgs) lispSystem version src;
            nativeBuildInputs = [
              pkgs.git
            ];
          }
        );
      };

      devShells = { };

    };

  };

}
