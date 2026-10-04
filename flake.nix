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

    mkProject_ = pkgs_ : lib_ : lib_.asdfFunctions.mkProject {
      pkgs = pkgs_;
      asdFile = ./asdf/git-agent-workflow.asd;
      pname = "git-agent-workflow";
      program = "git-gaw";
      lispDependencies = ps_ : [
        ps_.babel
      ];
      derivationAttrs = {
        git ? pkgs_.git,
      } : assert
      (pkgs_.lib.assertMsg
        (pkgs_.lib.versionAtLeast git.version "2.54")
        "GAW requires Git >= 2.54, but got ${git.version}"
      );
      {
        package = {
          nativeBuildInputs = [
            git
          ];
          GIT = pkgs_.lib.getExe git;
        };
        check = {
          nativeBuildInputs = [
            git
          ];
        };
      };
      meta = {
        description = "Git Agent Workflow (GAW)";
        platforms = [
          "x86_64-linux"
        ];
      };
    };

  in inputs.flake-parts.lib.mkFlake { inherit inputs; } {

    systems = [
      "x86_64-linux"
    ];

    flake = {
      lib = import ./lib;
      overlays = {
        default = final_ : prev_ : {
          git-agent-workflow = (mkProject_ final_ self.lib).package;
        };
      };
    };

    perSystem = { pkgs, ... } : let

      project_ = mkProject_ pkgs self.lib;

    in {

      packages = {
        default = project_.package;
        git-agent-workflow = project_.package;
      };

      checks = {
        git-agent-workflow-check = project_.check;
      };

      devShells = { };

    };

  };

}
