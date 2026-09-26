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

    perSystem = { system, pkgs, ... } :  let

      cl = inputs.cl-nix-forge.lib.${system};

      lispSystem = pkgs.lib.removeSuffix ".asd" (builtins.baseNameOf ./git-agent-workflow.asd);
      version = cl.fromAsdSystem ./git-agent-workflow.asd;
      src = cl.mkLispSource {
        root = ./.;
      };

      gaw = cl.lispDerivation {
        inherit lispSystem version src;
      };

    in {

      packages = {
        default = cl.mkExecutable {
          args = {
            pname = "git-gaw";
            inherit lispSystem version src;
          };
          programPath = "git-gaw";
        };
      };

      checks = {
        git-agent-workflow-test = cl.mkTestCheck gaw;
      };

      devShells = { };

    };

  };

}
