# GAW working memory

## Current state and recovery

The English-first language preference is committed by the user as `f47ba0b`.
Its sole parent is `e283fde`; only
cabal/share/skills/git-agent-workflow/SKILL.md changed, with the reviewed
7-line addition and blob `fe3e6a9e0b78debf1548b673fd4d787df7db7217`.
Main is now `f47ba0b`, with empty index and clean ordinary worktree.
The adopted preference covers newly
authored GAW memory, skills, archive descriptions and checkpoint messages;
it preserves evidence/quotations/technical meaning, explicit user/project language
requirements and historical conventions. It does not set ordinary project
commit or conversation language. The full staged diff was reviewed, cached
diff check passed, and no build/test was run. One commit is appropriate; no
archive is warranted because project history preserves this instruction.
The verified user-created commit subject is
`feat(skill): prefer English for newly authored GAW content`.
Its GAW association grounds the inspected committed instruction, not a build/test
claim. This task is complete; await a new objective. A committed bundled skill
does not prove installed skills or other projects have adopted the change.

The bundled archive workflow refinement is complete as user commit `e283fde`.
The user supplied the
reacquisition-selection paragraph and requested that each acquisition lead to
an actual retention decision and warranted memory/archive work, not just advice.
The ordinary archive reference now reassesses newly obtained items regardless
of past retention decisions, keeps the existing selection threshold, and requires
distillation/capture when warranted without automatic duplicate snapshots or
unnecessary writes. Host authorization still applies; blocked work is reported.
The verified commit has sole parent `db2f013`, changes only
cabal/share/skills/git-agent-workflow/references/archive.md, and preserves the
reviewed 14-line addition with blob `0a4e7a67b2c0f4ba9fad209c4a6aad42fbe80df2`.
At that task's completion main was `e283fde`, with empty index and clean worktree.
The full staged diff was reviewed and diff --cached --check passed before
commit. No build/test was run for this workflow-only change; prior 0.7.0 build
evidence below pertains to `db2f013`, not this later bundled-resource revision.
The user-created commit subject is
`feat(skill): complete retention decisions for each acquisition`.
Its GAW association grounds the inspected committed workflow, not an unexecuted
build/test claim. No pending action remains for this refinement, and no duplicate
archive is needed: project history preserves the skill text, while this memory
records the adopted rule. No project commit or publication was performed by agent.

The 0.7.0 release preparation is committed by the user as `db2f013`:
README.org, cabal/git-agent-workflow.cabal and the bundled references/auxiliary.md.
They set source version 0.7.0, summarize Auxiliary features and explain upgrade
availability, reserved names, diagnostics and interactive/shared-hook executable
compatibility. No feature expansion or lock change. At preparation completion,
ordinary HEAD was `db2f013`,
with verified sole parent `c0c9f01`, exact tested candidate tree
`58f05784023951a6bb7cfc1c8719a5d508f79ac3`, empty index and clean worktree.
The user-created commit subject is
`chore(release): prepare version 0.7.0`; no Issue closure is introduced by this
metadata/documentation commit. Draft release notes are in tmp/release-0.7.0.md.

`timeout 120s nix flake check --no-write-lock-file -L` passed, with observed
fresh compilation and execution of both suites, 13 help and 5 skill resource
sdist/install/exposure checks. Derivation:
`/nix/store/kdf7hljj3k22nhpq2ba1n2h8mxrybdyk-git-agent-workflow-0.7.0.drv`.
Output: `/nix/store/rcf3rkl69pqvfklp62hbrnyi4raiclhh-git-agent-workflow-0.7.0`.
That output printed `git-gaw 0.7.0` and its `help aux` succeeded. Non-host
aarch64 Linux/Darwin systems were omitted; existing Cabal warnings are nonfatal.
The planned `timeout 120s nix build --rebuild --no-link --no-write-lock-file -L
.#checks.x86_64-linux.git-agent-workflow` was launched in parallel and exited 1
before building: --rebuild requires existing valid outputs, absent at that point.
Do not report it as passing or as a failed source test. No automatic retry was
made; the successful first build above actually ran the required validation.

The actual user commit matches the tested candidate, so its GAW association
grounds the recorded 0.7.0 validation in `db2f013`, not the old 0.6.0 baseline.
Release preparation is complete. Await explicit publishing/installation work;
do not create tags, push or publish merely because preparation is committed.
Local main is one commit ahead of the locally recorded origin/main; no fresh
remote query was made in this confirmation. No tag, push, Release or installation
was performed by this agent.
Existing PLAN snapshots suffice; no duplicate archive was created. Last release
review observed published v0.6.0 and no v0.7.0 tag/Release; recheck before publishing.

The Auxiliary GAW implementation and its N1–N5 user-managed commit sequence
are complete against v0.6.0 baseline `801fe3b`. At implementation completion,
main was `c0c9f01` with empty index and clean worktree. Each node was independently checked
before staging; its sole parent and complete committed tree matched its tested
cumulative snapshot. Final source bytes were preserved throughout partial
staging. Native project commits were made by the user, not the agent.

| Node | Verified project commit | Scope |
| --- | --- | --- |
| N1 | `130dfe0` | Shared layout/UUID validation, physical parent conflicts, committed-only check --branch. |
| N2 | `396c7ed` | Shared hook/name protection and formal lifecycle boundaries. |
| N3 | `d7958f5` | Independent source roots, exact config inheritance, init/deploy/commit/check. |
| N4 | `5079274` | Structured aux check, branch -d/-D and ref/worktree race handling. |
| N5 | `c0c9f01` | Status/undeploy, bundled integration workflow, docs and complete lifecycle tests. |

All five isolated x86_64-linux Nix checks passed both protocol and Git-adapter
suites and source-distribution/install resource checks. N1/N2 had 12 help and
4 skill files, N3/N4 had 13 help and 4 skill files, N5 had 13 help and 5 skill
files. Outputs by node:

- N1: `/nix/store/qkmqk3gz65a1wckirqhd4wxw09542kpw-git-agent-workflow-0.6.0`.
- N2: `/nix/store/2rpr0xqjq4vcixkrxkpkqrfz11nk894w-git-agent-workflow-0.6.0`.
- N3: `/nix/store/9hzgrryf3qixf1w54j70im2nwi3j4vfx-git-agent-workflow-0.6.0`.
- N4: `/nix/store/7d1m2ll5j77jbs85iyf8a4wm97xdg2jc-git-agent-workflow-0.6.0`.
- N5: `/nix/store/ndgpjm7ymfj7za4859l3lvda2a1njrlw-git-agent-workflow-0.6.0`.

Exact command pattern used: `timeout 120s nix build --no-link
--no-write-lock-file -L
path:/home/lingyu/Projects/git-agent-workflow/tmp/auxiliary-commit-split-20261015/Nn#checks.x86_64-linux.git-agent-workflow`,
with Nn replaced by N1 through N5. Temporary snapshots, approved patches and
pure tree/source verification helpers remain under that ignored tmp directory;
they are expendable review scaffolding, not a durable registry or pending work.
The accepted N5 full tree is `66194eb691982dd120d1613120f10e1eb1bc47b2`.
Per-node GAW associations record actually tested snapshots. No pending staging,
commit, polling, archive migration or automatic cross-project update remains.
Existing PLAN input/completion snapshots already preserve the raw evidence;
this phase warrants distilled memory, not duplicate archives.

The user requests `Closes: #5` only for a commit that directly resolves it,
otherwise `Refs: #5`. The GitHub read-only connector returned the actual #5
body: support cross-session/agent consolidation with evidence, provenance,
uncertainty, superseded decisions and deduplication; automatic ingestion and
migration of all projects are not required. N5's bundled reconstruction,
integration and recovery workflow plus N1–N4 capabilities satisfies that scope.
N1–N4 use Refs; N5 uses Closes, verified in the committed body. This is not a
claim that GitHub is already closed; the last read before N5 showed open.
No release, tag, installation, external issue write or other-project action
was performed. The installed mapped CLI remains 0.6.0; source capability does
not establish installed/released Auxiliary availability.

The exact ignored root PLAN.md implementation input was byte-verified and
archived at `archive/2026-10-14T18-18-51Z--801fe3b/` (MANIFEST.md + files/PLAN.md).
Its archive-only checkpoint associates the inspected baseline as capture
context, not as the ignored document's original provenance. Preserve that
snapshot unchanged. The completed plan and N1–N5 acceptance record are separately
byte-verified at `archive/2026-10-14T18-44-09Z--801fe3b/`; root PLAN.md is retained
as the completed working record. Both manifests distinguish capture HEAD from
ignored document provenance and from the uncommitted implementation.

The deployed branch is `_agents` at the publicly reported GAW worktree
`.agents`. The selector and canonical protection hook are valid. Config is
explicit v1, declaring `archive/`, `skills/` and `memory/` under their
matching roles. Recovery/check and the native GAW status were clean before
this edit. Keep the deployment/config/history unchanged.

Use the current host's command mapping rather than copied old Nix paths.
The user-specified executable actually printed `git-gaw 0.6.0` in this
review. That verifies the named CLI only, not PATH discovery in every caller
or default installation selection.

## Auxiliary GAW implementation and adopted deletion semantics

The source plan is root PLAN.md, associated with Issues #5 and #9. Its design
is distinct from historical split/fusion proposals: formal GAW stays the sole
project-current-memory authority. Auxiliary histories are independent roots
with UUIDv4 branches `refs/heads/_gaw_aux_<uuid>` and a single matching UUID
subtree containing `.gaw/config` and declared workspace paths. Init copies
only the selected formal GAW's committed config, without workspace content
or a formal-history parent. Logical workspace paths are UUID-relative;
actual Git tree paths govern snapshot/parent conflicts. Shared checks/commit
and hook logic should be reused, not duplicated. No extra selector, registry,
executable or automatic knowledge integration is planned.

The user replaced the earlier dedicated-retire proposal:

- New Auxiliary commands are only `aux init`, `aux deploy`, `aux check`.
  Delete formal and Auxiliary branches through existing `branch -d/-D`;
  do not add `aux retire`, `aux abort`, `aux discard` or another deletion CLI.
- Formal GAW `-d/-D` keeps existing behavior and constraints. Auxiliary `-d`
  requires its current tip to be an ancestor of the valid formal tip selected
  by `refs/gaw/HEAD`, the sole integration target. Do not use native Git's
  upstream/caller-HEAD merge test as a substitute.
- Auxiliary `-D` is explicit abandonment and skips integration reachability,
  not committed-state validity or the no-associated-worktree requirement.
  Warn when discarding a source not retained in formal history; continued
  reachability is not guaranteed. Neither mode removes worktrees or cleans
  other historical references.
- `aux check` and Auxiliary `branch -d` share structured safe-deletion checks.
  Report structural validity separately from deletion readiness; unintegrated
  history is not damaged history. Reports include observed target/tip and
  selector/formal-tip observations needed by deletion.
- Safe deletion must verify selector target, formal tip and Auxiliary tip
  within the same Git ref transaction. Forced Auxiliary deletion still needs
  expected-old-OID conditional deletion. Worktree associations require their
  own checks/race handling; ref transactions alone do not stabilize them.
- `branch -m` remains limited to the currently selected formal branch and
  cannot rename into the Auxiliary reserved naming range. No Auxiliary
  rename mode is added; shared hook protection must coexist with these
  controlled branch operations.
- N2 covers naming/rename bounds and shared protection. N4 is now Auxiliary
  safe-deletion checks plus generic branch lifecycle extension. N5 updates
  branch/aux help and skill guidance and tests formal/Auxiliary `-d/-D`,
  integrated/unintegrated tips, invalid structure, associated worktrees,
  selector/formal/Auxiliary ref races and invalid type renames. All references
  in the plan's goals/CLI/lifecycle/nodes/acceptance were adjusted consistently.

Implementation is complete; per-node commit and validation progress is tracked
above. All planned source changes are committed:

- N1: shared HistoryLayout, exact config reads, UUID-relative workspace checks
  with full-tree boundary validation, physical parent conflicts, committed-only
  `check --branch` without worktree readiness claims.
- N2: canonical UUIDv4/reserved naming, conservative shared hook protection
  independent of config presence, formal rename/init/deploy type bounds.
  Git preparing input can encode unchecked deletion as zero old AND new;
  only a nonzero new value matching observed existing tip is a genuine no-op.
  New branch imports retain normal creation behavior; active ref changes are
  protected. The earlier ref-visibility diagnosis was unsubstantiated.
- N3: secure random UUIDs with collision retries, exact committed v0/v1 config
  blob inheritance into independent config-only roots, unchanged selector,
  shared deploy/worktree compensation, shared commit/check logical boundaries.
  Final review also regenerates a UUID overlapping formal workspace paths.
- N4: shared structured Auxiliary deletion reports; `branch -d` verifies the
  sole formal selector target, formal tip and Auxiliary tip in one conditional
  ref transaction. `-D` is abandonment with conditional deletion, valid state
  and no-worktree constraints, warning for unretained/unknown retention.
  Worktree registrations are not ref-locked: independent pre/post checks and
  create-if-absent restoration handle detected races, reporting partial failure
  if compensation fails. Serialize worktree activity with deletion; do not
  claim an atomic ref transaction freezes registrations.
- N5: separate status groups, pre-cleanup undeploy inventory (unknown inventory
  does not block cleanup), accurate hook-removal warning, updated help/README,
  bundled Auxiliary reference with formal integration and ancestry/path-based
  source recovery after safe deletion. No extra deletion command or executable.

The full isolated Nix x86_64-linux check has passed both protocol/Git adapter
suites, 13 embedded-help source-distribution checks, and 5 bundled skill files
in source distribution/Cabal installation/Nix exposure. Final successful output:
`/nix/store/c8jswrd7gqvmbghxh3mqa4xn7pqir82d-git-agent-workflow-0.6.0`.
Command: `timeout 120s nix build --no-link --no-write-lock-file -L
path:/home/lingyu/Projects/git-agent-workflow#checks.x86_64-linux.git-agent-workflow`.
Tests cover config byte fidelity, multiple Auxiliaries, invalid trees/markers,
wrong invocation root, mixed changes, formal and Auxiliary deletion, wrong
upstream/caller HEAD, selector/formal/Auxiliary ref races, worktree races,
forced abandonment, init compensation and residues, UUID collisions,
undeploy preservation, commit after undeploy, protection restoration, inventory
query failure and bundled resources. The final run passed forced worktree races,
accurate Auxiliary-selector diagnosis and direct byte recovery through formal
first-parent path history after source branch deletion.

The commit sequence is complete; no implementation or staging action remains.
PLAN archival is complete. Keep the existing real GAW
deployment/config/history; no real Auxiliary lifecycle action was performed.
Build warnings about Cabal metadata/bounds and install PATH remain nonfatal.
Non-Linux runtime verification was not performed.

## Handoff's illustrative levels and activation conditions

B0–B3 are illustrative labels internal to the user's handoff note, retained
here to explain its distinctions. They are not a mandatory GAW convention,
memory schema, checkpoint rule or required issue-priority system. Other work
need not adopt them; the actual blocking condition and deferred scope matter.

- **B0 — current blocker:** prevents an already determined task or release.
  None of these follow-up items is presently established as B0.
- **B1 — conditional blocker:** relevant only when a particular workflow is
  entered or an actual failure is triggered; not a current defect by default.
- **B2 — nonblocking follow-up:** useful independently scheduled work, without
  blocking current development/Linux release.
- **B3 — observation/deferred:** no decided implementation need or explicitly
  postponed; retain only the rationale and activation condition.

| Item | Level | Recovery decision |
| --- | --- | --- |
| Canonical hook executable discovery | B2; B1 for a reproducibly failing supported deployment | Hook command is `git-gaw --reference-transaction`, so its caller needs PATH discovery. No general failure is established. Investigate shell/GUI/noninteractive/Nix boundaries or diagnostics only for a concrete need; portable deployment/installation fixes may suffice. No absolute-path solution or protocol change is adopted. |
| Default init branch/templates | B3 | CLI requires explicit `--branch` and emits `(:version 1 :workspace ())`. This deliberately avoids a universal directory layout or memory template. Reconsider only if repeated project initialization cost establishes a need; not a defect or automatic issue. |
| Non-Linux/platform execution | B2; B1 only when undertaking the relevant platform's formal support/release | Main evidence is x86_64-linux. Declared aarch64-linux/aarch64-darwin outputs do not prove execution. User explicitly chose not to open an issue for non-Linux verification now; keep claimed support separate from actual tested platforms. |
| Bare/native Cabal environment | B3 | Complete-environment development option, not an unconditional Linux RC gate. Historical missing dependencies are not a current release failure. Reevaluate only for an explicit independent-of-Nix build-support goal. |
| Historical packaging warnings | B3 | Distribution metadata, dependency upper bounds and PATH warnings were nonfatal in recorded checks. Investigate for concrete packaging needs; do not reopen completed configuration/help/resource work or infer failure from an old warning. |
| Release/installation status checks | B1 when publishing/installing | Recheck tags, GitHub Release and the intended installed executable at that time. Committed version, RC evidence, tags, publication and installation are distinct states. No release audit is required by this housekeeping task. |

No new issue is required for hook discovery until an actual reproducible
deployment problem justifies one. Do not turn speculative portability risk
into a current blocker or silently broaden this work into environment tests.

## Existing issue references

These identities/positions come from the user's handoff plus established
memory; only #5 was freshly read before N5 and was open at that observation.
Other live GitHub open/closed states were not queried. Use stable issue links
for detailed requirements rather than copying complete issue text here.

| Issue | Position and current boundary |
| --- | --- |
| [#3](https://github.com/ren-lingyu/git-agent-workflow/issues/3) | Restricted GAW-aware rebase, later design/implementation; not routine memory maintenance. |
| [#4](https://github.com/ren-lingyu/git-agent-workflow/issues/4) | Exploratory interactive DAG visualization, no current release gate. |
| [#5](https://github.com/ren-lingyu/git-agent-workflow/issues/5) | Cross-session/agent knowledge integration; Auxiliary implementation and workflow are complete with isolated tests, committed through N5 with a Closes footer after checking the requirement. Remote closure and release availability are not inferred. |
| [#6](https://github.com/ren-lingyu/git-agent-workflow/issues/6) | Optional checker deferred; bundled OID semantic guidance is complete. |
| [#9](https://github.com/ren-lingyu/git-agent-workflow/issues/9) | Long-term history-model evaluation, not a decided split/fusion feature. |
| [#10](https://github.com/ren-lingyu/git-agent-workflow/issues/10) | Optional explicit bidirectional AGENTS maintenance research. |

For **#6**, `b81634e` introduced the bundled skill's semantic OID constraint,
and subsequent skill restructuring preserved it; the user reports that the
issue already has the commit association. An optional checker is unimplemented.
If requested, make it an explicitly invoked independent analysis feature,
without changing default commit/check/committed-state/hook protocol semantics.
Distinguish semantic dependencies from raw historical evidence, project OIDs,
abbreviated/unreachable old GAW OIDs and arbitrary hashes; matching hash-shaped
text alone does not prove a violation.

For **#9**, first-parent memory evolution and additional project-snapshot
association are the existing model. Split/fusion is an evaluation case, not
an adopted objective; structural fusion may imply different parent semantics.
Keeping the linear model is a valid final conclusion. A suggested
`[DESIGN]` title prefix is optional external tidying, not pending implementation.

For **#10**, investigate an explicit two-way workflow first, without assuming
background synchronization, a universal template, automatic conflict resolution
or a new CLI. Identify GAW persistence and the active ordinary-worktree target
through public discovery; multiple ordinary worktrees need an explicit target.
Both copies may contain meaningful edits; respect current authority rather
than overwriting mechanically. GAW persistence and ordinary project-file writes
have different permissions. Earlier org-texmacs governance inspection found
a local one-way template/layout mechanism, not an implemented generic two-way
solution. No cross-project write/deployment occurred in that evaluation.

## Completed v0.6.0 implementation and evidence

Completed work, not backlog:

- Versioned v0/v1 workspace configuration, optional role groups and role-aware
  recovery; configuration help `git gaw help config`.
- Conservative protection of unknown leading versions (Issue #7 implementation
  at `a250410`), with compatibility for accepted historical nonleading v0/v1.
  Future versions require a leading envelope. v0.5.0 cannot retroactively gain
  this protection.
- First-parent transition rejection of mixed `.gaw/` and other workspace
  changes, before commit-object/ref writes.
- Routed bundled memory/archive/skills workflows, Cabal/Nix resource inventory
  and byte consistency checks, motivation/tracking separation and bidirectional
  workflow transplantation guidance.
- Independent immutable archive snapshots with `MANIFEST.md + files/`,
  formally adopted in bundled guidance at `b4561ee`.
- v0.6.0 version preparation at `801fe3b`: Cabal version, README and embedded
  config/hook help. Cabal remains the program-version source.

Recorded Linux release-candidate validation ran one package check and both
Cabal suites through `nix flake check -L`; forced Nix rebuild reran both suites
without output mismatch. Checks verified all four skill resources and twelve
help resources in the source distribution and installed/exposed skill bytes.
The built CLI printed 0.6.0. Nonfatal metadata/PATH warnings were recorded.
Other architectures were not executed; a flake evaluation reporting zero checks
is not runtime test evidence.

The user committed a byte-identical reviewed four-file release candidate,
with sole parent `a250410`. Earlier completion memory associates the actual
post-commit inspected snapshot; original tests ran before submission. The
same distinction applies to the prior archive/config/help/skill nodes:
post-commit equality inspections do not retroactively change test provenance.

This housekeeping pass read local HEAD/history, existing guidance, config
and the specified CLI version. It did not rerun builds/tests, inspect live
GitHub issue/release status or audit tag/installation selection. Earlier
absence-of-tag observations are historical, not proof of today's state.
Do not automatically list tagging/publication as still pending or infer them
complete from preparation. Recheck only when the release workflow is active.

## Archive practice and retired directions

The default is a lightweight skill-defined archive convention, not a universal
published metadata standard or CLI format. Every capture, including one file,
creates a new snapshot. Checkpointed files/manifests remain unchanged; later
material or alternative descriptions go into a new snapshot, or corrected
current understanding into memory. Record purpose/selection, source and archive
paths/roots, file roles, context/provenance/limits and historical status.
Preserve source bytes and meaningful relative paths; reject unauthorized
capture, verify byte equality and handle failures before checkpointing.

Generic SHA-256, timestamp naming, exact project-parent count and archive-only
checkpoints are not protocol requirements. This repository deliberately keeps
UTC--captured-HEAD naming, full capture HEAD, statuses/sizes/SHA-256 and separate
archive-only checkpoints in `skills/git-agent-workflow-gaw-archive/SKILL.md`;
`archive/README.md` explains that local convention. Historical archived
instructions do not become active instructions merely by being read.

Stable GAW-worktree-relative historical evidence:

- `archive/2026-10-10T05-24-49Z--d6c675a/`: original comparison preparation.
- `archive/2026-10-10T07-07-01Z--d6c675a/`: complete comparison inputs/results;
  report at `files/tmp/archive-comparison/run-20261010/report.md`.
- `archive/2026-10-10T10-07-16Z--d6c675a/`: final user-adopted semantics plan.

**B3, selection ended:** Data Package/RO-Crate/BagIt integration is not a TODO.
The old conditional DP2 recommendation stays authentic in historical evidence,
not current memory's objective. Reevaluate only for concrete machine-readable
metadata, exchange/indexing or sufficiently complex relationship needs.
Do not migrate old archives or introduce parsers/validators/schema/toolchains.

**B3, no automatic transplantation:** the bundled skill provides adaptation
and release/installed-availability guidance; that does not mean every related
project has been updated. Act only in a named project with concrete need and
authorization, preserving local operational detail instead of mechanical
deduplication. There is no implicit all-project traversal/sync task.

## Durable protocol and recovery boundaries

- Missing config version is v0; explicit v0/v1 work. V1 supports direct entries,
  mixed/repeated role groups in order, and unknown legal roles. Roles follow
  `[a-z][a-z0-9-]*`, reserving file/directory. Flattening preserves duplicate,
  nesting, object-kind and project-parent constraints. V1 unknown top-level
  fields are ignored semantically with check/status field-name warnings; v0
  rejects them. Unsupported versions are indeterminate, not a protection bypass.
- GAW's independent workspace tree is retained through its first-parent chain;
  additional parents associate evidenced exact project snapshots without merging
  their trees. Parent positions do not encode based-on/result business roles.
  Choose zero/one/several only from actual evidence, not current HEAD by habit.
- Clone-local `refs/gaw/HEAD` selects the deployed local branch, not global
  identity or the filesystem target of a project association. Malformed state
  is reported, not silently repaired.
- `git gaw commit` consumes the complete index, not unstaged/untracked files,
  from the GAW root. Explicitly stage only intended declared workspace paths,
  review the full candidate and run check. Keep config/protocol-path changes
  separate from other workspace transitions. Ordinary project writes/commits
  and lifecycle/history work require their own authority.
- A checkpoint needs independent recovery value; a session boundary or new
  project commit alone does not justify it. Maintain current memory promptly;
  check consistency at handoff rather than first writing it then.
- Use stable archive paths and Git relationships, not GAW checkpoint OIDs as
  durable semantic locators. Relevant project OIDs and raw diagnostic hashes
  may have independent evidence value.
- If reconstructing old sessions, establish the complete requested evidence
  horizon, distinguish persisted/examined/unrecoverable intervals, reconstruct
  only supported selective states in order and never guess historical parents.
  Later checks cannot establish original uncertain provenance. Earlier targeted
  clean-history reconstruction is complete; do not restore absent backup refs
  or repeat/rewrite it as routine upkeep.

## Historical implementation lookup and next action

The active implementation is Haskell, separated into Protocol/Application/System
layers, with protocol and Git-adapter suites. The fixed v0.4.0 Lisp differential
oracle/harness is historical and retained through a GAW project-parent
association; its former local branch is absent. Do not merge/reproduce it
as routine maintenance. Earlier detailed rewrite/config/split/reconstruction
stage evidence remains in first-parent memory history, not as pending phases
or expired command allowances in current memory.

The bootstrap config is the historical fixed immutable unversioned input;
the current repository config and new init output are explicit v1. Do not
confuse the bootstrap or old init example with current behavior.

No pending action remains from the Auxiliary implementation/commit sequence.
The 0.7.0 release preparation is committed and verified as described at the top;
continue release work only within its
separate authorization. Do not repeat completed N1–N5 staging or polling.
PLAN implementation input and completion record are preserved
in separate immutable snapshots. Existing follow-up
labels remain note-local examples, not mandatory priorities. Release/tag,
installed version and GitHub issue state need separate fresh checks when that
work is requested. This task does not mutate ordinary project history, GitHub
state, the real deployment/config or other projects.
