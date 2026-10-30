{
  callPackage,
  lib,
  emacs-nox,
  emacsPackagesFor,
  git,
  writeShellApplication,
}:
let
  emacs = (emacsPackagesFor emacs-nox).emacsWithPackages (epkgs: [ epkgs.ox-gfm ]);
in
writeShellApplication {
  name = "release-notes";
  text = ''
    export GIT=${lib.getExe git}
    exec ${lib.getExe emacs} --batch --load ${./release-notes.el} --funcall release-notes-main
  '';
  passthru.tests.regressions = callPackage ./tests/check.nix {
    inherit emacs;
    source = ./release-notes.el;
  };
}
