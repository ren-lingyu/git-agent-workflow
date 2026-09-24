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

    systems = inputs.nixpkgs.lib.systems.flakeExposed;

    perSystem = { ... } : {

      packages = { };

      checks = { };

      devShells = { };

    };

  };

}
