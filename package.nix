{
  lib,
  haskell,
  haskellPackages,
  installAgentSkills,
  git,
  python3,
  writeText,
} : assert
(lib.assertMsg
  (lib.versionAtLeast git.version "2.54")
  "GAW requires Git >= 2.54, but got ${git.version}"
);
let

  checkSkill_ = writeText "gaw-check-skill-resources.py" ''
    import pathlib
    import re
    import sys
    import tarfile
    import tempfile

    source = pathlib.Path(sys.argv[1])
    source_root = source.parent.resolve()

    def contents(path, root):
        if root not in path.resolve().parents:
            raise ValueError(f"Skill resource escapes its root: {path}")
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Missing or nonregular skill resource: {path}")
        if path.stat().st_size > 1048576:
            raise ValueError(f"Unexpectedly large skill resource: {path}")
        return path.read_bytes()

    files = {"SKILL.md": contents(source, source_root)}
    links = re.findall(r"\[[^\]]+\]\((references/[^)\s]+)\)", files["SKILL.md"].decode("utf-8"))
    if not links:
        raise ValueError("The bundled workflow has no reference routes")
    for link in links:
        files[link] = contents(source_root / link, source_root)

    def check_tree(root):
        root = root.resolve()
        for name, expected in files.items():
            if contents(root / name, root) != expected:
                raise ValueError(f"Skill resource differs from source: {name}")

    mode = sys.argv[2]
    if mode == "sdist":
        archives = sorted(pathlib.Path("dist").glob("*.tar.gz"))
        if len(archives) != 1:
            raise ValueError("Expected one freshly generated Cabal source distribution")
        with tarfile.open(archives[0], "r:gz") as archive:
            roots = {pathlib.PurePosixPath(member.name).parts[0]
                     for member in archive.getmembers() if member.name}
            if len(roots) != 1:
                raise ValueError("Invalid Cabal source distribution layout")
            prefix = roots.pop()
            for name, expected in files.items():
                member = archive.getmember(f"{prefix}/{source.parent.as_posix()}/{name}")
                if not member.isfile():
                    raise ValueError(f"Nonregular source-distribution resource: {name}")
                with archive.extractfile(member) as stream:
                    if stream.read(1048577) != expected:
                        raise ValueError(f"Source-distribution resource differs: {name}")
    elif mode == "installed":
        check_tree(pathlib.Path(sys.argv[3]))
    elif mode == "self-test":
        with tempfile.TemporaryDirectory(prefix="gaw-skill-resource-test-") as temporary:
            root = pathlib.Path(temporary)
            for name, body in files.items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(body)
            check_tree(root)
            name = next(name for name in files if name != "SKILL.md")
            target = root / name
            target.unlink()
            try:
                check_tree(root)
            except ValueError:
                pass
            else:
                raise AssertionError("Missing reference was accepted")
            target.write_bytes(files[name] + b"changed")
            try:
                check_tree(root)
            except ValueError:
                pass
            else:
                raise AssertionError("Changed reference was accepted")
            target.unlink()
            target.symlink_to(source_root / name)
            try:
                check_tree(root)
            except ValueError:
                pass
            else:
                raise AssertionError("External reference target was accepted")
    else:
        raise ValueError(f"Unknown skill-resource check: {mode}")
    print(f"Verified skill resources ({mode}): {len(files)} files")
  '';

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
      python3
    ]
  ];

  GIT = lib.getExe git;

  dontInstallAgentSkills = 1;

  postCheck = builtins.concatStringsSep "\n" [
    (old_.postCheck or "")
    ''
      ./Setup sdist
      sourceSkill="$(find share/skills -type f -name SKILL.md -print -quit)"
      python3 ${checkSkill_} "$sourceSkill" self-test
      python3 ${checkSkill_} "$sourceSkill" sdist
    ''
  ];

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
    ''
      sourceSkill="$(find share/skills -type f -name SKILL.md -print -quit)"
      python3 ${checkSkill_} "$sourceSkill" installed "$(dirname "$skill")"
      exposedSkill="$(find "$out/share/skills" -type f -name SKILL.md -print -quit)"
      if [ -z "$exposedSkill" ]; then
        echo "No Nix-exposed agent skill found" >&2
        exit 1
      fi
      python3 ${checkSkill_} "$sourceSkill" installed "$(dirname "$exposedSkill")"
    ''
  ];

  meta = lib.mergeAttrsList [
    (old_.meta or { })
    {
      platforms = lib.platforms.unix;
    }
  ];

})
