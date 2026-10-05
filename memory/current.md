# GAW working memory

## Objective

The v0.2.0 lifecycle runtime is tagged. An ordinary local source branch and its GAW history are portable; registration, selection, hook configuration, and a linked worktree are clone-local deployment state. The next design pressure is simplifying how branch identity and local refs relate.

## Established state

- GAW uses an independent commit tree for its declared workspace. First parent is the preceding GAW checkpoint; optional additional project parents provide exact snapshot association and reachability, never merged content. The bootstrap `.gaw/config` remains unversioned, strictly parsed from a fixed immutable commit and exact UTF-8 blob bytes.
- Ordinary Git source-branch history, `.gaw/config`, and workspace state are portable. The v0.2 runtime materializes local `refs/gaw/heads/<name> -> refs/heads/<name>` registrations and a `refs/gaw/HEAD` selector; neither needs remote transport. The configured hook blocks ordinary updates of registered branches and protocol refs. Protection is a local mistake guard, not an authorization boundary.
- `git gaw commit` uses the complete current index, not unstaged or untracked files. Normal commits and merge-shaped checkpoints retain only the GAW first-parent tree; project parents are checked for path conflict but their trees are not merged. Git invocation ignores inherited user/system identity and signing settings and records `Git Agent Workflow <gaw@invalid>`.
- `git gaw show` exposes first-parent history and first-parent patches while retaining ordinary `git show` formatting options. `git gaw check` reports current-worktree readiness; independent UTF-8 help files are embedded at build time. Native `git status`, `git diff`, and explicit `git add` remain part of the daily loop.
- The implementation keeps `api → runtime → core` layering and injects the Git executable at the API boundary. Runtime tests cover Git process bytes, config parsing, workspace/index boundaries, hook protection, and the public commands.

## Lifecycle now implemented

- `init` rejects valid or ambiguous GAW-like history, preflights local conflicts, writes initial objects, then creates source branch, registration, and selector in one expected-state ref transaction. `deploy` validates existing local branch history, discovers candidates with `.gaw/config` only as a prefilter, and reconciles selector, optional worktree, and canonical hook; it never fetches or silently repairs damaged metadata.
- `branch` rename and safe deletion reuse native `git branch` semantics, with GAW preflight, ordered metadata changes, final verification, and explicit partial-failure reporting if compensation cannot restore an invariant.
- `git gaw status` inventories repository-wide GAW branches, local refs, selector, hook, and worktrees. A successful default report is not a Boolean assertion of health. Discovery uses Git-native ref enumeration plus exact probes for known names; it does not scan files-backend storage for otherwise hidden broken refs. `--diagnose` appends unparsed repository-wide `git fsck` output and combines its result with GAW health.
- The implementation was reorganized around `api → runtime → core` for mutation, commit, hook, and CLI responsibilities before tagging v0.2.0.

## Next step

Reassess whether symbolic registrations should continue to define a branch as GAW-managed. Any replacement must preserve portable branch history, explicit local deployment errors, and hook protection without making `refs/gaw/*` irreplaceable state.
