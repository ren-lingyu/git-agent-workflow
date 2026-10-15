# GAW working memory

## Current state and recovery

The v0.6.0 release preparation and earlier implementation nodes are complete.
The user authorized Auxiliary GAW implementation against the v0.6.0 baseline
`801fe3b`, including the adopted generic branch-deletion semantics. N1–N5 are
implemented and verified, including the final review additions. The user committed
N1 as `130dfe0`; its tree/parent/empty index match the independently tested N1
snapshot. N2 is now committed as `396c7ed`, with its exact tested tree and sole
parent `130dfe0` verified. N3 is committed as `d7958f5`, with its exact tested
tree, sole parent `396c7ed` and empty index verified. N4 validation is running;
N4–N5 remain outside the index. No release, installation, external issue update
or other-project action is part of this task.

The user now requests organizing N1–N5 into sequential project commits:
prepare reviewable partial-staging boundaries, request staging authorization,
draft each message from the actual staged diff, then poll for at most three
minutes per item until timeout or a verified expected HEAD move. Native project
commits remain user-managed. Verify parent, committed tree, branch and index,
not merely a changed HEAD; only then update GAW and proceed to the next item.
Current main HEAD is `d7958f5`, and its index is empty after N3. Shared CLI,
manifest and test files need partial staging. UUID parsing must accompany N1's
layout/branch inspection; N2 adds protection/lifecycle policy. Existing PLAN
input/completion snapshots already retain the needed raw evidence, so this
commit-organization phase needs distilled current memory, not duplicate archives.

Five cumulative snapshots/patches are prepared under ordinary-worktree-relative
`tmp/auxiliary-commit-split-20261015/`; REVIEW.md lists exact paths, commands,
patch digests and expected full project trees, and sequence.json is operational
verification data. These are temporary review inputs, not a durable workflow
registry. If absent/changed, regenerate and obtain fresh staging approval rather
than guessing at a previously approved patch. N1's isolated Nix snapshot passed
both test suites and resource/distribution checks, output
`/nix/store/qkmqk3gz65a1wckirqhd4wxw09542kpw-git-agent-workflow-0.6.0`.
Its 12-path staged diff and full index tree match the reviewed N1 patch and
tested snapshot; final working source bytes remain unchanged. The user-created
N1 commit has the expected sole parent `801fe3b` and exact tested tree. Its GAW
project association records this verified snapshot, not the remaining worktree.
N2's isolated check passed both suites and resource/distribution checks, output
`/nix/store/2rpr0xqjq4vcixkrxkpkqrfz11nk894w-git-agent-workflow-0.6.0`.
Its approved 12-path patch, full staged tree and unchanged final source bytes
were verified. N3 passed both suites, 13 help and 4 skill resource/distribution
checks, output `/nix/store/9hzgrryf3qixf1w54j70im2nwi3j4vfx-git-agent-workflow-0.6.0`.
Its approved 16-path patch and full staged tree match the tested snapshot;
final worktree source bytes are unchanged. N4–N5 split snapshots are not tested yet.
N5 equals the accepted final source bytes.

Proposed commit boundaries (each carries its available tests/help):

1. N1: HistoryLayout/UUID parser, subtree config and physical parent conflicts,
   committed-only check --branch, pure and real-repository layout tests. A
   temporary formal-only lifecycle validator prevents generic deletion from
   treating newly recognized Auxiliary state as formal history before N4.
2. N2: shared hook/name protection, malformed reserved-name committed-state
   rejection, formal selector/init/deploy/rename bounds and native-ref tests.
3. N3: secure UUID creation and collision handling, independent roots/config
   blob inheritance, shared init/deploy/commit/index readiness and v0/v1/multi-
   Auxiliary tests. The temporary lifecycle guard remains until N4.
4. N4: structured aux check, generic branch -d/-D dispatch, expected-state
   transactions and independent worktree race handling, deletion/race/source
   recovery tests. This replaces the temporary formal-only lifecycle guard;
   strict worktree-list parsing accompanies the deletion checks that need it.
5. N5: status classification, undeploy inventory/protection reporting, complete
   lifecycle/failure-compensation tests, README/help and bundled skill/resources.

The user explicitly authorized items 1–6: all five index-only patch commands
and repeated use of the five exact 120-second isolated Nix build/check commands
listed in REVIEW.md. This authorization persists for the current sequence;
do not ask again for an unchanged approved item. Validate each cumulative node before staging it; do not treat the
earlier final-tree test as proof that every split snapshot builds. After actual
staged review write tmp/commit.md, then poll main HEAD every 10 seconds for at
most 180 seconds. Accept only a single-parent child of the prior HEAD with the
expected tree and an empty index. N1's expected full tree
`80f55437fdbb43468d25cd93a3608725b8422b12` is now verified in `130dfe0`.
N2's earlier 180-second window expired, then the user committed it and requested
continuation. Verified `396c7ed` is a sole-parent child of `130dfe0` with exact
tested tree `99f6452065c46f72890e7c770bfb3932036c19a7` and empty index.
N3 was observed within its polling window as `d7958f5`, with tested tree
`9b313801c1682eb9f1a10e1e92a2bfdc291779c7` and sole parent `396c7ed`.
Next: validate/stage N4, draft its actual staged message, then poll for a
sole-parent child of `d7958f5` with full tree
`bda85acbd995a1813c5dc9d9290e8f4bd9dac9b1`. Items 1–6 remain authorized.
On unexpected movement or timeout stop, preserve the candidate, and record the
pending node. On a verified commit associate only its actually tested/inspected
snapshot with the GAW update, then proceed within the granted staging scope.

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

Implementation is in the ordinary working tree, not a new project commit:

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

Next: hand off the unstaged source diff for user review/commit. PLAN archival
and the final recovery-state check are complete. Keep the existing real GAW
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
memory; live GitHub open/closed state was not queried. Use stable issue links
for detailed requirements rather than copying complete issue text here.

| Issue | Position and current boundary |
| --- | --- |
| [#3](https://github.com/ren-lingyu/git-agent-workflow/issues/3) | Restricted GAW-aware rebase, later design/implementation; not routine memory maintenance. |
| [#4](https://github.com/ren-lingyu/git-agent-workflow/issues/4) | Exploratory interactive DAG visualization, no current release gate. |
| [#5](https://github.com/ren-lingyu/git-agent-workflow/issues/5) | Cross-session/agent knowledge integration; Auxiliary implementation and workflow are now in the uncommitted working tree, with isolated tests. This does not establish issue closure or release availability. |
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

Next action is review the unstaged Auxiliary source diff for a user-managed
project commit. PLAN implementation input and completion record are preserved
in separate immutable snapshots. Existing follow-up
labels remain note-local examples, not mandatory priorities. Release/tag,
installed version and GitHub issue state need separate fresh checks when that
work is requested. This task does not mutate ordinary project history, GitHub
state, the real deployment/config or other projects.
