{
  lib,
  haskell,
  haskellPackages,
  installAgentSkills,
  git,
} : assert
(lib.assertMsg
  (lib.versionAtLeast git.version "2.54")
  "GAW requires Git >= 2.54, but got ${git.version}"
);
let

  package_ = haskell.lib.dontHaddock (haskellPackages.callCabal2nix
    "git-agent-workflow"
    ./cabal
    { }
  );

in package_.overrideAttrs (old_ : {

  nativeBuildInputs = builtins.concatLists [
    (old_.nativeBuildInputs or [ ])
    [
      installAgentSkills
    ]
  ];

  GIT = lib.getExe git;

  dontInstallAgentSkills = 1;

  postInstall = builtins.concatStringsSep "\n" [
    (old_.postInstall or "")
    "skill=\"$(find \"$data\" -type f -name SKILL.md -print -quit)\""
    "if [ -z \"$skill\" ]; then"
    "  echo \"No Cabal-installed agent skill found\" >&2"
    "  exit 1"
    "fi"
    "("
    "  unset dontInstallAgentSkills"
    "  cd \"$data\""
    "  installSkills"
    ")"
  ];

  meta = lib.mergeAttrsList [
    (old_.meta or { })
    {
      platforms = lib.platforms.unix;
    }
  ];

})
