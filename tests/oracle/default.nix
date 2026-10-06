{ pkgs } : let

  archive = ./v0.4.0.tar.gz;
  expectedHash = "fed2f16650ac286ab794fdb09b0ac0a1b185dbf95a4ce1fa59832784339d3620";
  closure = builtins.genericClosure {
    startSet = [ {
      key = toString pkgs.sbcl.pkgs.babel;
      dependency = pkgs.sbcl.pkgs.babel;
    } ];
    operator = entry : map (dependency : {
      key = toString dependency;
      inherit dependency;
    }) (entry.dependency.propagatedBuildInputs or [ ]);
  };
  lispRegistry = builtins.concatStringsSep ":"
    (map (entry : "${entry.dependency}//") closure);

in
assert builtins.hashFile "sha256" archive == expectedHash;
pkgs.stdenvNoCC.mkDerivation {
  pname = "git-agent-workflow-oracle";
  version = "0.4.0";
  src = archive;
  sourceRoot = ".";
  nativeBuildInputs = [ pkgs.sbcl pkgs.git ];
  dontConfigure = true;
  dontStrip = true;
  buildPhase = builtins.concatStringsSep "\n" [
    "runHook preBuild"
    "export CL_SOURCE_REGISTRY=\"$PWD/asdf:${lispRegistry}\""
    "export ASDF_OUTPUT_TRANSLATIONS=\"/:/\""
    "export GIT=${pkgs.lib.getExe pkgs.git}"
    "cd asdf"
    "${pkgs.lib.getExe pkgs.sbcl} --noinform --non-interactive --eval '(require :asdf)' --eval '(asdf:load-asd (truename \"git-agent-workflow.asd\"))' --eval '(asdf:operate (quote asdf:program-op) \"git-agent-workflow\")'"
    "cd .."
    "runHook postBuild"
  ];
  installPhase = builtins.concatStringsSep "\n" [
    "runHook preInstall"
    "mkdir -p \"$out/bin\""
    "install -m755 asdf/git-gaw \"$out/bin/git-gaw\""
    "runHook postInstall"
  ];
  meta.mainProgram = "git-gaw";
}
