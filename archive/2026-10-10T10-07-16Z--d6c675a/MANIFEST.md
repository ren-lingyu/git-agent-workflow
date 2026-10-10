# Manifest snapshot archive semantics decision

Historical evidence; not authoritative current instructions or proof of a released implementation.

- Capture time: 2026-10-10T10:07:16Z.
- Project: git-agent-workflow; source paths are relative to its ordinary worktree root.
- Project commit: d6c675a (full object ID: d6c675a58d6a2eb2fcf815dacb743c325e607d35).
- Capture context: HEAD at capture. The bundled archive reference has uncommitted documentation changes; those candidate bytes are not included in this snapshot. PLAN.md is ignored and untracked, not a tracked blob from HEAD.
- Purpose/selection: preserve only the user-updated development guidance that formally adopts MANIFEST.md plus files/ and retires the previous external-tool integration goal.
- Original provenance: user-maintained decision document after comparison/discussion. This capture does not assert its original creation date or authorship from the associated project commit.
- Limits: this is the adopted design input, not a release/build test. Older experiment reports and their conditional recommendations remain unchanged in prior snapshots.
- Verification: source type/size, stable pre/post source state, exact bytes, size/SHA-256 and unchanged captured HEAD.
- The GAW checkpoint is the commit containing this manifest; its sole additional project parent records the checked capture context.

## Selected artifacts

| Source | Archived path | Source state | Bytes | SHA-256 | Role |
| --- | --- | --- | ---: | --- | --- |
| PLAN.md | files/PLAN.md | untracked, ignored | 19658 | 193c5f956de6d2f4f11f9799773f257c9eebda41640bc02be7662234a7017847 | User-adopted archive semantics and bounded implementation/acceptance guidance. |
