{
  description = "Repository maintenance automation";

  inputs = {
    nixpkgs = {
      url = "git+https://github.com/NixOS/nixpkgs.git?ref=refs/heads/nixpkgs-unstable&shallow=1";
    };
    personal-nixpkgs = {
      url = "git+https://github.com/ren-lingyu/nixpkgs.git?ref=refs/heads/main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    inputs.personal-nixpkgs.lib.mkFlake inputs.nixpkgs
      ({ lib }: rec {
        inherit inputs;
        moduleLocation = __curPos.file;
        llib = { inherit (inputs.personal-nixpkgs.lib) packages; };
        lpkgs = import ./pkgs { inherit llib; };
      })
      (
        { lpkgs, ... }: {
          config = {
            systems = [ "x86_64-linux" ];

            perSystem = { pkgs, lib, ... }: {
              nixpkgs.overlays = [ lpkgs.overlays.legacy ];

              apps = {
                release-notes = {
                  type = "app";
                  program = lib.getExe pkgs.release-notes;
                  meta.description = "Publish GitHub release notes from a signed release command commit";
                };
              };

              checks = pkgs.release-notes.tests;

              treefmt = {
                flakeCheck = true;
                settings.excludes = [ "flake.lock" ];
              };
            };
          };
        }
      );
}
