# GAW working memory

## Objective

Build Git Agent Workflow as an independent Git history for an agent workspace. A GAW commit's first parent carries temporal GAW history; optional additional project-commit parents associate exact project snapshots without merging their trees. The v0.1 runtime is still being assembled.

## Established design

- `.gaw/config` is an intentionally unversioned, structured workspace declaration, for example `(:workspace ((:file "AGENTS.md") (:directory "notes")))`. Do not introduce `:version` until its format and behavior have been decided.
- The config is a `100644` blob in a GAW commit. Resolve the current ref to one immutable commit OID before inspecting its tree and blob; read blob stdout as exact octets without decoding or stripping it in the Git layer.
- Parse exact Git blob bytes with strict UTF-8 decoding, a narrow lexical gate, the restricted Common Lisp reader with read evaluation disabled, and schema validation. Reject unsupported reader syntax and unknown tokens; keep size, depth, entry-count, and path-length limits explicit.
- Workspace paths are literal repository-root-relative Git paths: `/` separators, no silent normalization, no empty, absolute, trailing-slash, `.` or `..` components. Reserve the root `.gaw` namespace and every `.git` component. Config validation checks the declaration, not the current filesystem kind.
- A `:file` declaration can cover a regular file, executable file, or symlink; `:directory` covers a Git tree. Missing paths can represent deletion. Overlapping declared paths form a union, while duplicate canonical paths conflict.
- Preserve the `api → runtime → core` layering. Resolve defaults and external Git at API boundaries, pass them explicitly into runtime, and keep core validation independent of Git I/O or dynamic configuration.

## Next step

Complete the runtime operations that consume this config: controlled GAW commits, first-parent history display, worktree readiness, and the daily edit/stage/checkpoint loop before declaring v0.1 ready.
