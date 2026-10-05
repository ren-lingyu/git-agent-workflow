# GAW working memory

## Objective

The v0.1.0 runtime is tagged. It supports an already provisioned GAW worktree; the next major objective is to create and maintain that local state through GAW itself.

## Established state

- GAW uses an independent commit tree for its declared workspace. First parent is the preceding GAW checkpoint; optional additional project parents provide exact snapshot association and reachability, never merged content. The bootstrap `.gaw/config` remains unversioned, strictly parsed from a fixed immutable commit and exact UTF-8 blob bytes.
- The v0.1 registration model uses `refs/gaw/heads/<name> -> refs/heads/<name>` and `refs/gaw/HEAD` as local GAW selection. A configured `reference-transaction` hook protects registered branches against ordinary Git ref updates. This is a local mistake guard, not an authorization boundary.
- `git gaw commit` uses the complete current index, not unstaged or untracked files. Normal commits and merge-shaped checkpoints retain only the GAW first-parent tree; project parents are checked for path conflict but their trees are not merged. Git invocation ignores inherited user/system identity and signing settings and records `Git Agent Workflow <gaw@invalid>`.
- `git gaw show` exposes first-parent history and first-parent patches while retaining ordinary `git show` formatting options. `git gaw check` reports current-worktree readiness; independent UTF-8 help files are embedded at build time. Native `git status`, `git diff`, and explicit `git add` remain part of the daily loop.
- The implementation keeps `api → runtime → core` layering and injects the Git executable at the API boundary. Runtime tests cover Git process bytes, config parsing, workspace/index boundaries, hook protection, and the public commands.

## Next step

Design and implement `git gaw init`, `deploy`, and branch lifecycle. Distinguish portable GAW history from clone-local selector, registration, hook, and linked worktree state; do not equate a fresh clone with a need to initialize new history.
