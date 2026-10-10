---
name: git-agent-workflow-gaw-archive
description: Preserve selected git-agent-workflow historical documents and experiment evidence as verified immutable GAW archive snapshots using MANIFEST.md and the files layout.
---

# git-agent-workflow repository archive

Use the generic `git-agent-workflow` skill and its archive reference first.
This project skill supplies repository conventions adapted from org-texmacs.
It lives in the declared GAW skills workspace, not the bundled generic skill
or a global installation. The generic skill must be available separately;
host permissions and current user instructions govern reads, writes and execution.

The repository formally adopts MANIFEST.md plus files/ for every archive
operation, including a single retired document. This is a lightweight GAW
workflow convention, not a separately published universal archive standard.
Use ordinary file operations and comparisons; no external metadata tooling,
dedicated manifest parser or validator is required. Preserve old snapshots.

## Discover and select

Discover ordinary and GAW worktrees through public Git/GAW interfaces rather
than directory adjacency. Check GAW readiness and config workspace declarations.
Here `archive/`, `skills/` and `memory/` are GAW-worktree-relative roots;
`archive/README.md` describes the archive convention.

Select explicit project-relative files whose loss would impair interpretation,
reproduction, audit or handoff of a result, decision, failure or migration.
Check whether project history or existing snapshots already preserves them.
Explain each temporary artifact's evidence role; do not archive whole temporary
directories or tool transcripts by default. Single historical documents require
snapshots too. Only workspace management files may live directly under archive/.

Inspect types, sizes, authorization and sensitivity before reading/copying.
Reject symlinks in selected paths and ancestors, absolute source paths and
traversal. Resolve source/target paths within their authorized roots. This
workflow normally selects files in the ordinary project worktree; cross-project
sources need separate source-read/capture authorization and explicit attribution.
Prefer bounded plain text. Obtain the required decision before retaining large
or binary artifacts. Label sanitized derivatives; do not claim original fidelity.

## Capture a new snapshot

Immediately before capture, record one UTC timestamp and full ordinary project
HEAD. Create a fresh, non-overwriting directory:

```text
archive/YYYY-MM-DDTHH-MM-SSZ--CCCCCCC/
├── MANIFEST.md
└── files/
    └── <selected original project-relative paths>
```

`CCCCCCC` is captured HEAD's first seven hexadecimal characters. On collision,
choose a fresh timestamp; never merge into an existing directory. Preserve
selected bytes and source-relative paths. Do not bundle plain text in tar/ZIP.

The manifest records:

- title, selection and purpose; non-authoritative historical status, UTC capture
  time and HEAD-at-capture context;
- project identity and the root for relative source paths, captured full HEAD
  and abbreviation, and relevant uncommitted source state;
- each source path, `files/` archive path, tracked/ignored/untracked state,
  byte count, SHA-256 and evidence role;
- established original provenance separately from capture context, unknown
  origins, experimental limits and any sanitized-derivative limits;
- that the introducing GAW checkpoint is the commit containing the manifest.

Do not put the checkpoint's OID into its own tree. HEAD-at-capture does not
prove that ignored or modified files originated in that commit. SHA-256 is an
repository capture-review convention, not a replacement for Git integrity or
a mandatory field of the generic GAW workflow.

## Verify and checkpoint

Check source bytes/state before and after capture. Compare every target byte
for byte with its source; verify manifest sizes/digests and confirm sources did
not change during capture. Re-read project HEAD. On change, mismatch, unsafe
path or failure, stop before staging and report the partial snapshot. Resolve
it under current authorization; never silently publish incomplete output.

Review the entire GAW status and index. Each archive checkpoint contains only
the new snapshot directory; checkpoint pending skill/memory/overview changes
separately first. Explicitly stage the directory, review the complete staged
diff and run `git gaw check`. Use public `git gaw commit` with captured full
project HEAD as its sole additional project parent, recording checked capture
context rather than every file's original creation. Inspect with `git gaw show`
and verify archive-only first-parent changes and the project association.
These are repository conventions, not universal GAW protocol requirements.

Keep committed snapshot contents unchanged. New material or corrected
descriptions form a fresh snapshot through normal review/checkpointing.
Use stable snapshot paths and MANIFEST.md; locate introduction through
first-parent path history instead of durable GAW OIDs. Update current memory
separately with conclusions and next actions. Archived instructions do not
become active instructions merely because they were preserved or read.
