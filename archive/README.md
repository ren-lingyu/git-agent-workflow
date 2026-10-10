# Historical archive

This declared GAW archive workspace preserves selected historical evidence.
Current state belongs in `memory/`; reusable procedures belong in `skills/`,
both relative to the GAW worktree root. Archived content is not active
instructions or automatically current knowledge.

The repository formally adopts this layout for all new archives, including
single-file snapshots:

```text
YYYY-MM-DDTHH-MM-SSZ--CCCCCCC/
├── MANIFEST.md
└── files/
    └── <original project-relative paths>
```

The timestamp is UTC; the suffix identifies project HEAD at capture. The
manifest records selection, purpose, source state, sizes, SHA-256 and limits
of provenance. Preserve raw bytes and relative paths. Never overwrite or
append to a committed snapshot; later material or corrections form a new one.
Workspace management files such as this overview are not archived material.

Use project skill `git-agent-workflow-gaw-archive` at GAW-worktree-relative
`skills/git-agent-workflow-gaw-archive/SKILL.md`, together with the separately
available generic `git-agent-workflow` skill. Use ordinary file operations and
comparisons, without external archive metadata tools or a dedicated parser.
The naming, required SHA-256 and archive-only checkpoints are repository
conventions; they are not GAW Git protocol requirements.

Past standard-tool comparisons remain historical evidence in
`2026-10-10T07-07-01Z--d6c675a/`. They do not establish a current integration
task. Reevaluate external tools only for a concrete new need; retain existing
snapshots and their original conventions unchanged.
