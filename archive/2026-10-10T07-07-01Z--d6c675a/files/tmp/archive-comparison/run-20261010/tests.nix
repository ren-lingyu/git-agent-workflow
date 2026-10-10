let
  environment = import ./environment.nix;
  pkgs = environment.pkgs;
in pkgs.runCommand "gaw-archive-nixpkgs-comparison" {
  nativeBuildInputs = [ environment.python environment.r ];
} ''
  mkdir work
  cd work
  timeout 30s ${environment.python}/bin/python3 -B ${./probe.py} ${./inputs} ${./datapackage-2.0.schema.json} ${environment.r}/bin/Rscript ${./probe.R} > python-stdout.txt
  mkdir -p "$out"
  cp -r . "$out/"
''
