# Historical archive

This declared GAW archive workspace preserves selected historical evidence.
Current state belongs in `memory/`; reusable procedures belong in `skills/`,
both relative to the GAW worktree root. Archived content is not active
instructions or automatically current knowledge.

Until formal metadata tooling is adopted, all new archives use the same
org-texmacs-style interim layout, including single-file snapshots:

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
available generic `git-agent-workflow` skill. This is an interim repository
convention; Data Package 2.0 and RO-Crate 1.3 are still unselected candidates.
Existing snapshots retain their conventions after future adoption.
