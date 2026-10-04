{ pkgs, llib }:

let

  fixture = llib.asdfFunctions.mkProject {
    inherit pkgs;
    asdFile = ./fixture/skill-install-fixture.asd;
    pname = "skill-install-fixture";
    program = "fixture-program";
  };

  installedSkill = "${fixture.package}/share/skills/skill-install-fixture/sample-skill";

in pkgs.runCommand "lib-asdfFunctions-skills-test" { } ''
  test -x "${fixture.package}/bin/fixture-program"
  test -f "${installedSkill}/SKILL.md"
  test -f "${installedSkill}/references/guide.md"
  cmp ${./fixture/share/skills/sample-skill/SKILL.md} "${installedSkill}/SKILL.md"
  cmp ${./fixture/share/skills/sample-skill/references/guide.md} "${installedSkill}/references/guide.md"

  test ! -e "${installedSkill}/unlisted.md"
  test ! -e "${fixture.package}/share/skills/skill-install-fixture/unlisted-skill"
  test "$(find "${fixture.package}/share/skills/skill-install-fixture" -type f | wc -l)" -eq 2

  mkdir -p "$out"
''
