let
  locked = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
  source = builtins.fetchTree locked;
  pkgs = import source.outPath {
    system = "x86_64-linux";
  };
in {
  inherit pkgs;
  python = pkgs.python3.withPackages (p: [ p.frictionless p.jsonschema ]);
  r = pkgs.rWrapper.override {
    packages = [ pkgs.rPackages.frictionless pkgs.rPackages.rocrateR ];
  };
}
