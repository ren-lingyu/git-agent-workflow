{ pkgs, project, mkAsdfScript }:

let

  installAgentSkillsScript_ = mkAsdfScript {
    inherit pkgs;
    name = "${project.pname}-install-agent-skills.lisp";
    asdName = project.asdName;
    body = builtins.concatStringsSep "\n" [
      (builtins.readFile ./install-agent-skills.lisp)
      "(write-install-agent-skills-manifest system \"install-agent-skills-manifest\")"
    ];
  };

in {

  nativeBuildInputs = [ pkgs.installAgentSkills ];
  derivationAttrs = {
    dontInstallAgentSkills = 1;
  };

  buildCommands = [
    "${pkgs.lib.getExe project.lisp} --script ${installAgentSkillsScript_}"
  ];

  installCommands = [
    "installAgentSkillsStage=\"$(mktemp -d)\""
    "while IFS= read -r -d '' skill && IFS= read -r -d '' relative && IFS= read -r -d '' source; do"
    "  target=\"$installAgentSkillsStage/$skill/$relative\""
    "  mkdir -p \"$(dirname \"$target\")\""
    "  cp -p -- \"$source\" \"$target\""
    "done < install-agent-skills-manifest"
    "for skill in \"$installAgentSkillsStage\"/*; do"
    "  if [ -d \"$skill\" ]; then installSkill \"$skill\"; fi"
    "done"
  ];

}
