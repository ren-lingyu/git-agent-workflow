# GAW working memory

## Objective

The v0.3.0 runtime is available, and agent-skill packaging infrastructure is in place. The next objective is to write the bundled skill as a usable persistent-memory workflow rather than a CLI reference.

## Established state

- GAW uses an independent commit tree for its declared workspace. First parent is the preceding GAW checkpoint; optional additional project parents provide exact snapshot association and reachability, never merged content. The bootstrap `.gaw/config` remains unversioned, strictly parsed from a fixed immutable commit and exact UTF-8 blob bytes.
- Ordinary branch history, `.gaw/config`, and workspace state are portable. The only canonical `refs/gaw/*` ref is clone-local `refs/gaw/HEAD -> refs/heads/<name>`; it selects a valid local GAW branch but does not define identity or choose the branch for `git gaw commit`. Old `refs/gaw/heads/*` registrations are no longer used. Malformed local metadata is reported, not silently rebuilt.
- `git gaw commit` uses the complete current index, not unstaged or untracked files. Normal commits and merge-shaped checkpoints retain only the GAW first-parent tree; project parents are checked for path conflict but their trees are not merged. Git invocation ignores inherited user/system identity and signing settings and records `Git Agent Workflow <gaw@invalid>`.
- `git gaw show` exposes first-parent history and first-parent patches while retaining ordinary `git show` formatting options. `git gaw check` reports current-worktree readiness; independent UTF-8 help files are embedded at build time. Native `git status`, `git diff`, and explicit `git add` remain part of the daily loop.
- The implementation keeps `api → runtime → core` layering and injects the Git executable at the API boundary. Runtime tests cover Git process bytes, config parsing, workspace/index boundaries, hook protection, and the public commands.

## Lifecycle and protection

- `init` writes initial objects before atomically creating source branch and selector; it fails on existing valid or ambiguous GAW-like history. `deploy` validates an existing local source branch, uses `.gaw/config` only as discovery prefilter, and reconciles selector, optional worktree, and hook without fetching or repairing corruption. `undeploy` removes local selector and GAW hook keys, retaining branch, history, marker, and worktree contents; recognizable exact legacy registrations may be cleaned, with residual damage reported.
- `branch -m`, `-d`, and `-D` preserve native Git rename and deletion constraints. `-D` skips only mergedness/safe-delete, not GAW validation or worktree constraints. A selected branch cannot be deleted until local deployment changes.
- The configured hook guards `refs/gaw/*`. It rejects movement/deletion of a branch whose current tip is valid GAW state. If a tip is invalid but has a `.gaw/config` marker, it preserves that marker entry unchanged while other content may move. First introduction of the marker is allowed. The hook is a local accident guard, not a security boundary.
- `git gaw status` inventories branch classification, selector, hook, and worktrees through Git-native ref commands. Its default zero exit means a report was produced, not that all findings are healthy. `--diagnose` additionally forwards repository-wide `git fsck` output and fails if either GAW status or fsck fails. `git gaw check` is current-worktree readiness and permits a missing selector as a warning.

## Skill packaging now implemented

- The ASDF system declaration is the authority for bundled skill membership and static files. Packaging installs only explicitly declared files; an undeclared sibling file or skill must not leak into the package.
- `lib.asdfFunctions.mkProject` exposes `installAgentSkills` as a default-enabled, opt-out capability rather than embedding skill policy in generic ASDF build/install phases. Disabling it omits the dependency, manifest, staging, and installation; a system without a skill subtree is a no-op.
- The enabled path stages ASDF-declared files and delegates final layout to nixpkgs `installAgentSkills`. Fixture checks cover declared-only installation, the disabled option, and the no-skill case. The skill's source files remain separate from its build-time embedding/installation mechanics.

## Next step

Write and bundle a skill centered on recovery, maintenance of current memory, verification, exact project grounding, selective checkpoints, and handoff. Avoid fixed memory-file templates, full transcript archives, and forcing a checkpoint at each session boundary.
