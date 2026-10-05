# GAW working memory

## Objective

Extend the tagged v0.1.0 runtime with repository lifecycle operations. The v0.2.0 design now distinguishes portable GAW history from rebuildable local deployment metadata.

## Established state

- GAW uses an independent commit tree for its declared workspace. First parent is the preceding GAW checkpoint; optional additional project parents provide exact snapshot association and reachability, never merged content. The bootstrap `.gaw/config` remains unversioned, strictly parsed from a fixed immutable commit and exact UTF-8 blob bytes.
- Ordinary Git source-branch history, `.gaw/config`, and workspace state are portable. `refs/gaw/heads/<name> -> refs/heads/<name>` and `refs/gaw/HEAD` are local registration/selection metadata, not refs that must be pushed or fetched. The existing configured hook protects registered branches; the v0.2 policy will also guard GAW protocol refs. Protection is a local mistake guard, not an authorization boundary.
- `git gaw commit` uses the complete current index, not unstaged or untracked files. Normal commits and merge-shaped checkpoints retain only the GAW first-parent tree; project parents are checked for path conflict but their trees are not merged. Git invocation ignores inherited user/system identity and signing settings and records `Git Agent Workflow <gaw@invalid>`.
- `git gaw show` exposes first-parent history and first-parent patches while retaining ordinary `git show` formatting options. `git gaw check` reports current-worktree readiness; independent UTF-8 help files are embedded at build time. Native `git status`, `git diff`, and explicit `git add` remain part of the daily loop.
- The implementation keeps `api → runtime → core` layering and injects the Git executable at the API boundary. Runtime tests cover Git process bytes, config parsing, workspace/index boundaries, hook protection, and the public commands.

## Lifecycle design

- `init` must reject existing valid or ambiguous GAW-like history, preflight obvious local conflicts, write initial blob/tree/root-commit objects first, then create source branch, symbolic registration, and selector in one `update-ref --stdin` transaction. A failed ref transaction may leave unreachable objects, not a partial ref graph.
- `deploy` does not fetch or create a missing local source branch. It validates existing history; absent selector uses local branch discovery with `.gaw/config` only as a prefilter. Explicit branch selection is allowed; malformed local metadata must not be silently repaired. Reconcile the local hook and optional linked worktree, then check readiness.
- `branch` rename/deletion are GAW lifecycle operations. Reuse native `git branch` to preserve reflog, config, worktree, and safe-delete behavior where applicable; coordinate protocol refs with strict preflight, ordered updates, and explicit reporting of incomplete compensation.

## Next step

Implement the lifecycle packages and CLI, including partial-failure tests. Do not expose low-level registration and hook maintenance as routine user commands.
