{
  emacs,
  pkgs,
  source,
}:
pkgs.runCommand "release-notes-regressions" { nativeBuildInputs = [ emacs ]; } ''
  cp ${source} release-notes.el
  emacs --batch -Q -f batch-byte-compile release-notes.el
  touch "$out"
''
