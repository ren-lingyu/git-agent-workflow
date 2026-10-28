# GAW working memory

## Current state and recovery

Use the git-maintenance commit-message workflow for GAW checkpoint messages as
explicitly requested by the user, including Conventional Commit formatting.

The lock refresh is complete as the user commit
`chore(flake): refresh nixpkgs and personal-nixpkgs locks`. After waiting for
HEAD to move, read-only verification confirmed its sole parent is the reviewed
input-override-removal commit, only flake.lock changed, and its committed blob
matches the staged lock reviewed for the message. The ordinary project index
and worktree are clean. nixpkgs and personal-nixpkgs advance together; the lock
also moves flake-parts/treefmt-nix dependency connections under local-nixpkgs
and adjusts treefmt-nix's nixpkgs follows path. No source staging or ordinary
commit remains pending. The user requests a GAW checkpoint for this completion;
its project association grounds the inspected committed lock update.

The successful project checks described below used this commit's immediate
parent, before the latest lock refresh. They are not validation of the refreshed
lock. No check/build of the new lock or project-local .#nix shell was performed
in this commit-message/checkpoint phase. This distinction is a validation limit,
not an instruction to force a rebuild or reopen completed earlier checks.

The nested path-input override removal is committed as
`build(flake): remove local-nixpkgs Git input override`. On 2026-10-29,
read-only inspection found a clean ordinary project worktree/index and confirmed
that flake.nix no longer overrides personal-nixpkgs/local-nixpkgs with a Git URL.
The lock now represents that input as ./pkgs relative to personal-nixpkgs.
The user explains that a Nix patch in personal-nixpkgs enables this change;
the patch's stability was previously uncertain. Keep this motivation out of
the ordinary commit message, as explicitly requested.

The user authorized Nix checks/builds and explicitly accepts cache hits as
evidence of prior successful execution; do not force rebuilds merely to avoid
cached results. Agent-run `timeout 120s nix flake check --no-write-lock-file`
passed: the package resolved to the previously recorded k17cpbr8 package
derivation, and one treefmt check was actually built and passed. The check
omitted aarch64-linux and aarch64-darwin. Agent-run
`timeout 120s nix build --no-link --no-write-lock-file .#default` also exited 0
without rebuilding. Its first sandboxed attempt failed opening the Nix fetcher
cache SQLite database; the approved identical rerun outside the sandbox passed.
No lock update, result link or ordinary project modification was made.

Authorized source inspection of the user's personal-nixpkgs checkout found the
committed nix-flake-patched package, with a circular-import patch and a fetched
nested-relative-path fix restricted to src/libflake/flake.cc. Its source comment
targets Nix 2.35.3. The initial checks used the terminal's Nix 2.34.9; the user
then identified the upstream development shell as the patched-Nix entry point.
Source inspection confirmed devShells.<system>.nix in the upstream
pkgs/flake.nix, containing nix-flake-patched. The project's pre-refresh locked
upstream did not expose .#nix, so validation used the local upstream shell
without overriding or updating project inputs:
`nix develop --no-write-lock-file path:/home/lingyu/nixpkgs#nix -c nix ...`.
Its version command reported Nix 2.35.3+2. Through that shell, both
`flake check --no-write-lock-file` and
`build --no-link --no-write-lock-file .#default` exited 0 within their 120-second
limits. Flake checks and the package reused successful cached results; the
check omitted aarch64-linux and aarch64-darwin. Sandbox cache/daemon access
failures were resolved by approved runs outside the sandbox. This supersedes
the earlier uncertainty about whether the project was tested with patched Nix:
the nested path configuration now passes with the upstream shell's patched
Nix as well. Broader patch stability is not established by this project alone;
no independent Nix patch regression suite or forced rebuild was run. Both the
ordinary project and personal-nixpkgs checkout remained unmodified during those
checks. That pre-refresh validation is complete; the later lock-refresh
validation boundary is stated above.

The following sections describe earlier completed states; their clean-state and
validation observations belong to their respective reviews.

Formatting and treefmt-check enablement are now committed by the user:
`style: format Haskell, Cabal, Nix and Markdown files`, followed by
`build(nix): enable treefmt flake check`. Read-only inspection of the latter
confirmed it changes only treefmt.flakeCheck from false to true. The formatting
review covered 43 staged files: Haskell source/tests, Cabal configuration, Nix
package definitions and a bundled-skill Markdown table. Inspection found
formatting/import ordering and merging; no runtime feature change was intended.
The current setting is flakeCheck=true, superseding the migration-era false below.

The user supplied a successful `nix flake check` after formatting (exit 0,
30.4146 seconds): it ran one flake check and built the package derivation
`/nix/store/k17cpbr8l14xdf9g97z778p6saq2c2rk-git-agent-workflow-0.7.2.drv`.
After enabling treefmt.flakeCheck, another supplied successful run (exit 0,
1.5679 seconds) also resolved checks.x86_64-linux.treefmt to
`/nix/store/z5ag5hgl3qmycldsrxz4c2yhrjjrcqnc-treefmt-check.drv`, with cached
results and 0 checks executed in that displayed run. Both omitted aarch64-linux
and aarch64-darwin. These are user-run checks; no agent test rerun occurred.

The previously pending lock update is now committed by the user as
`chore(flake): refresh nixpkgs lock`, directly after the treefmt-check enablement
commit. Read-only review confirms only flake.lock changed: nixpkgs advances from
55ba7f49ef2962b42cbd126522b7df5f95037679 to
674a2028661e550a97400c1cc992b9cca9a668a1 with matching lastModified/narHash;
the input URL and nixpkgs-unstable ref remain unchanged. Ordinary project index
and worktree are clean. No pending lock update, source staging or commit remains.

Both supplied checks used this newer lock revision before its commit. The final
successful treefmt-enabled working tree is now represented by committed source
and lockfile together; no additional test rerun was performed or is required by
this completion review. The prior checkpoint's project association remains the
inspected formatting/check configuration and is not rewritten. Current memory
records the subsequent lock completion. The user explicitly requests a new
checkpoint; its project parent grounds the inspected committed lock update and
completed source/configuration state. Await the user's next task.

The following migration/release sections describe earlier completed states.

The Nix packaging migration is complete as the user commit
`build(nix): migrate packaging to github:ren-lingyu/nixpkgs`. Read-only inspection
confirmed the seven intended files, the valid restored
`packages.default = pkgs.git-agent-workflow`, and a clean ordinary project index
and worktree. The user reset and recommitted main, and reverted the prior GAW checkpoint.
Public GAW status/check confirmed a healthy deployment at the preceding
release-preparation checkpoint with this migration memory retained in the index.
The user explicitly requested rebuilding the checkpoint. Its project parent
identifies the newly inspected replacement commit, not the superseded project
snapshot or an agent-executed runtime validation. No source staging or commit
remains pending.

The flake now uses the `lib.mkFlake` provided by `github:ren-lingyu/nixpkgs`
through its local input alias `personal-nixpkgs`. Keep repository identity and
input alias distinct in prose and commit messages. Package discovery lives in
`pkgs/default.nix`; `pkgs/git-agent-workflow/overlay.nix` selects GHC 9.12 and
passes the explicit Cabal source into the moved package.nix. The flake constructs
that source from a fileset rooted at cabal/. The moved package changes only its
source argument and source expression. The three existing systems, default and
named packages, default overlay and package-backed check remain; legacyPackages
is additionally exported through the legacy overlay. The .gitignore whitelist
admits pkgs directories/Nix files, and README reflects the moved definition.
The replacement project commit updates the locked github:ren-lingyu/nixpkgs
revision to 6c339e0d535f093b6934d8e9ff598f165bcee50b, adds *.txt to treefmt
exclusions, and adjusts flake expression layout. These are the only tree
differences from the previously inspected migration commit. Treefmt remains
integrated with flakeCheck=false. No CLI, protocol or Cabal runtime source changed.

Reference layouts were the user's nixpkgs, emarccs, nixos and org-texmacs
projects; `~/nixpks` was interpreted as the existing `~/nixpkgs`. No reference
project was modified. The user explicitly confirmed manually rerunning the tests
successfully before showing the subsequent cached `nix flake check` run. Record
this as user-executed validation of the replacement state; the earlier pending
validation interpretation is superseded. Exact fresh test commands/logs were not
provided, and the agent did not rerun tests. No repeat or forced rebuild is pending.
The displayed `nix flake check` exited 0 in 1.3572 seconds, resolving the
x86_64-linux default/named package and check to
`/nix/store/j1xbg503wy1rfw8zdsvyk817x0v3caki-git-agent-workflow-0.7.2.drv`
and evaluating the formatter. Its 0 flake checks reflect the cache hit after the
user's prior manual testing, not missing validation. The displayed run omitted
aarch64-darwin and aarch64-linux; do not infer validation of those platforms.
The restored default alias is verified in the committed source. Read-only
diff/whitespace review passed. No Nix fmt, evaluation, build or runtime test was run by the
agent during this task. Do not infer new platform validation or release/tag/
installed adoption from this packaging commit. No further implementation is
pending; await the next objective.

The release-preparation state below describes the earlier completed release
review and does not imply this packaging migration was included in its tag.

Version 0.7.2 release preparation is complete. Read-only review confirmed the
user's committed release-preparation patch changes only README.org and the Cabal
version declaration, with the expected prior README-alignment parent. The ordinary
project index and worktree are clean. The local v0.7.2 tag resolves to this exact
release-preparation commit. No staging or source commit remains pending.

Cabal and README now state 0.7.2. README summarizes parent interpretation without
changing selection eligibility, structural Auxiliary UUIDs and DAG-based recovery,
the explicit-Formal-skills memory entry recommendation, and conditional archival
assessment. Upgrade guidance covers 0.7.0/0.7.1 without history migration and calls
for refreshing the installed bundled skill. Cabal remains the version source for
CLI and Nix metadata; no runtime, CLI, configuration or protocol change was needed.

The user explicitly confirmed rerunning the checks with all checks passing before
staging and committing. Record this as user-executed validation; the agent did not
rerun Nix checks or builds. This later confirmation supersedes the earlier pending
validation wording and the narrower interpretation of the supplied cached-check
output. No repeat run is pending. GitHub Release publication, remote tag state and
installed-version adoption have not been verified by this review. Release
preparation and local tagging are complete; await the next user objective.

The README documentation alignment is complete as user commit
`3f75809ab13e69d46402628baf17669cb1e0ac04`, subject
`docs(readme): restate parent edges as historical dependencies`. Verified sole
parent `397f46b`, only README.org changed (42 insertions, 30 deletions), and the
committed patch equals the reviewed staged diff; the commit message matches the
drafted tmp/commit.md text. Ordinary project worktree and index are clean.

README.org now restates GAW parent edges as historical dependencies needed to
interpret each checkpoint's durable knowledge state: non-root checkpoints
inherit GAW knowledge history through the first parent (initialization roots
have no first parent), additional parents supply other historical context via
exact Git commits without merging their trees, and parent edges are not
citations, knowledge-adoption records, approval markers or validation results.
Archival assessment is now conditional on explicit preservation requests or
concrete independent evidence needs, not routine source inspection or memory
maintenance. This is documentation-only and aligns the README with the two
prior committed skill revisions; no CLI, protocol, config or Git-history
semantics changed. No build/test was run. Await the next user objective.

The conditional archival-assessment correction is complete as user commit
`fix(skill): make archival assessment conditional`. Direct read-only review
confirmed the expected prior parent-semantics commit, exactly five bundled Skill
files changed, and a clean ordinary project index/worktree. The message now uses
fix/conditional, matching the behavioral change and both trigger paths.

Routine reading, reconstruction, establishment, consolidation and Auxiliary
maintenance do not trigger archival assessment by default. Explicit requests to
preserve original evidence or a concrete independent preservation need trigger
selection, not automatic capture. Repeated-acquisition reassessment now explicitly
applies within an active archival evaluation. No per-acquisition no-archive record
is required; declining capture is complete. Citations do not transfer archival
value or recursively expand capture. Knowledge distillation remains timely;
selected, justified capture remains prompt and subject to authorization.
This supersedes older per-acquisition archival-assessment/recording guidance.

The three prior review issues are resolved: correct semantic commit type, accurate
conditional title, and explicit scoping of reassessment. Complete committed diff
and whitespace review passed. Capture/sanitization and manifest/verification/
checkpoint-immutability/authorization sections were compared with the prior source
and remain unchanged; snapshot layout applies after selection. No new build or
runtime test was executed or reported. This GAW association grounds the inspected
committed instruction, not installed adoption or runtime results. No archive was
triggered by this source review; substantive conclusions suffice in memory.
The task is complete, with no pending staging/commit or speculative follow-up.

The parent-semantics revision is complete as user commit
`fix(skill): define parents as historical dependencies`. Read-only verification
confirmed the expected prior entry-point-guidance parent, exactly bundled
SKILL.md/consolidation.md/auxiliary.md changed, and a committed patch identical
to the reviewed final diff. The user removed the Refs trailer; its absence was
verified. Ordinary project worktree and index are clean, with no pending staging
or ordinary commit. The user's follow-up explicitly
supersedes the part of PLAN.md that would impose an additional dependency-
necessity selection threshold. Keep the new introductory meaning, including
non-root first-parent inheritance, root exception and one concise distinction
from citation/adoption/approval/validation records. This is an interpretation
clarification, not a redesign of parent eligibility.

The primary checkpoint-selection paragraph is restored verbatim from committed
source. Source choices retain established relevance, exact-state evidence, real
historical-context value and acceptable authorized retention boundaries.
Explanation, discovery-line relationships, audit/provenance review and recovery
remain valid reasons without an extra indispensability proof. Retention or branch
deletion alone is still insufficient. No separate explanatory material is needed
for every existing parent; keep useful substantive explanations and recover Git
relationships from the DAG. Consolidation retains distinct knowledge integration,
evidence archival and historical dependency selection, without a new threshold.
Its self-explanation condition now refers to relevant source history actually not
being retained, rather than no new source dependency being selected. History may
already be retained through earlier Formal ancestry; a new parent is not required
at the current checkpoint. The user explicitly adopted this final correction.

Final diff was reviewed specifically for selection-behavior changes. Existing
primary selection, exact retrospective provenance/checkpoint suffix and Auxiliary
lifecycle/recovery suffix match the pre-revision source verbatim. Four other references remain
unchanged and 22 local links/anchors resolve; whitespace review passed. A–I were
revisited as tabletop scenarios, with positive checks for meaningful audit context
without necessity proof and existing parents without new justification cards.
This replaces the earlier stricter candidate/acceptance, not a new runtime test.
No new Nix build, package self-test or installation was performed or reported.
The GAW project parent identifies the directly inspected committed semantics,
not a new runtime-test result.

Temporary full diff and updated review remain under
`tmp/dependency-skill-review-20261020T121127Z/changes.patch` and `review.md`.
No raw plan/request archive is warranted; decisions are distilled here and in
source. No CLI/protocol/lifecycle/archival/security/authorization rule or Git
ancestry was changed. The prior suggestion to reassess project archive rules
under an added necessity threshold does not establish a follow-up task. The
semantic-only revision is complete; await the next user objective. Source
commit does not establish tag, Release or installed-skill adoption status.
Issue references should follow a concrete relationship, not be inherited merely
from nearby commits; drafting commit messages generally does not require GAW
memory updates, as the user has explicitly instructed.

The project memory entry-point guidance is complete as user commit
`feat(skill): guide project memory entry-point skills`, with Refs: #5.
Direct read-only verification confirmed the expected prior history-semantics
parent, only bundled SKILL.md and references/skills.md changed, and their blobs
match the reviewed staged content. Ordinary project worktree/index are clean;
no staging or ordinary commit remains pending. The associated project parent
identifies the inspected committed guidance, not a new runtime validation.

Formal's explicit :skills role recommends a minimal project-level memory entry
point, preferring an existing suitable skill. Navigation/interpretation is enough;
no separate engineering procedure, fixed name or memory layout is required.
Reference existing memory without copying it or maintaining Git-derived indexes.
Update the entry point when organization/interpretation changes, not after every
memory update/session. V0, ungrouped and custom-role discovery remain unchanged;
an Auxiliary's inherited role does not independently require another entry point.
Other project skills retain their ordinary workflow/constraint criteria.

All six requested cases were consistent in tabletop review. Diff whitespace,
22 local links/anchors and existing section-preservation checks passed. The final
staged reference includes minor line wrapping with unchanged meaning. No Nix
build/test, installed-skill change, AGENTS maintenance or actual project entry-
point creation was performed. The earlier GAW check in the ordinary worktree
failed because of invocation location; the actual GAW worktree check passed.
No independent raw-evidence archive was warranted. This completion checkpoint
records implemented/reviewed guidance, not mere consultation of that guidance.
Await the next user objective; this instruction-only task does not implicitly
authorize creating an entry-point skill in this or another project's workspace.

The Git history/source-record semantics revision is complete as the user commit
`fix(skill): clarify Git history and source recovery semantics`, with Refs: #5.
Read-only verification confirmed the expected release-preparation parent, exactly
the three intended Skill files, and a committed diff identical to the reviewed
patch. Ordinary worktree and index are clean; no staging or commit is pending.

The revised shared guidance recovers Git-derived ancestry/relationships and
reachability from Git rather than maintained static indexes. Necessary references,
external locators and substantive explanations remain allowed. Auxiliary UUIDs
provide collision avoidance and required layout, not knowledge identity. Parents
express checkpoint evolution and relevant external historical context; knowledge
integration, archival and history retention remain independent workflow decisions.
Source recovery discovers the Formal checkpoint, its actual parents and source
tree before reading source content/evolution, without a UUID registry. Exact
stage-specific associations, interleaved intermediate sources, ancestor screening
and existing deletion safety are preserved. No foreign-project memory cleanup,
CLI/config/version or installed-skill change was made.

All eight requested scenarios were reviewed as tabletop reasoning. Diff whitespace,
21 local links/anchors and Cabal resource consistency passed; creation/normal-loop,
branch-deletion constraints, example table and exact project-parent rules were
compared with the prior source. The final wording removes adopting from the
source-inspection/parent-choice sentence. No Nix build, runtime suite, actual
branch deletion or independent-agent test was performed. Temporary review aids
remain in tmp/git-history-semantics-20261019T102005Z; no additional raw archive
was warranted. The GAW association grounds the directly inspected committed
Skill revision, not a new runtime test or release. Await the next objective;
source changes alone do not prove tag, publication or installation state.

Version 0.7.1 source preparation is complete as user commit
`c3d44962cbabf889522c3dcd417321965d6a20bb`, subject
`chore(release): prepare version 0.7.1`. Direct read-only verification confirmed
its sole parent is 77e0993, exactly README.org and cabal/git-agent-workflow.cabal
changed, the committed patch matches the reviewed release preparation, and the
ordinary project worktree/index are clean. No staging or commit remains pending.

Cabal declares 0.7.1; CLI version and Nix package metadata derive from it.
README identifies the new source version, summarizes the bundled skill changes,
and explains skill refresh and upgrading from 0.7.0 without history migration.
The Auxiliary minimum of 0.7.0 and older upgrade guidance remain accurate.
The commit contains no Issue footer because it only prepares version/docs.
No additional raw archive is needed; source history preserves the patch.

No new Nix test/build of this 0.7.1-labeled source has been reported or executed
in this preparation. Earlier user-reported success belongs to the preceding
0.7.0-labeled implementation; do not upgrade that evidence to a verified 0.7.1
build. Tag, GitHub Release and installed-version status have not been checked;
do not infer them from the source commit. Version preparation is complete;
await the next user objective. Any requested release verification has its own
authorization boundary. This GAW association grounds the directly inspected
committed version/docs, not an unobserved runtime test.

The knowledge workflow extension and final textual refinement are complete as
user commit `77e09935e72affb7fd7f1008eeb2fb3128a9e9f6`, subject
`feat(skill): guide knowledge establishment and consolidation`, with Refs: #5.
Read-only verification confirmed its sole parent is f47ba0b and its seven-path
committed binary diff exactly matches the reviewed staged SHA-256
`48c8eccf3bacbbf3962b81c2179143091cbf4b0f92e3c21be226bf1e1b2140eb`.
Committed tree is `879940f6911d0f8438d988f772c7b2c4be62c9ca`.
Ordinary project worktree and index are clean. No staging, commit or phased
polling remains pending. Seven files form one coherent workflow change, including
both new references and their Cabal declarations; no runtime/CLI/config/version
or dependency-lock change was included.

The user reports rerunning Nix tests and build successfully after committing.
Record this as user-reported final validation, distinct from the earlier directly
observed isolated Nix run below. Exact rerun commands, logs, derivations and
platform scope were not supplied; do not invent those details or claim the agent
reran the committed source. Current committed content and parentage were directly
verified. The GAW project parent associates this inspected committed implementation,
not an independently observed new runtime test. No additional raw-evidence archive
is warranted: project history and distilled memory preserve the outcome.
Source commit does not establish global skill installation, cross-project adoption,
tag creation or publication. The task is complete; await the next objective.

Final patch decision: archive.md now prefers original bytes only when their
retention is authorized and appropriate under selection and sensitive-content
screening. Sanitized-derivative labeling, transformation/evidence limits, byte
comparison and immutable snapshots are preserved. Auxiliary retains A1–A3,
B1–B3 and F1–F4, explicitly saying these parent associations prescribe no source
timeline, integration schedule or checkpoint count. Main SKILL.md is unchanged:
its five shared source-association constraints remain clear, and optional
shortening offered insufficient benefit. No new archive/audit protocol or design
work was introduced. The request's durable decisions are distilled here and in
the patch; the complete conversation has no independent archival need.

Current final-patch validation: reviewed the full tracked diff and compared all
66 prior build inputs with the tested isolated snapshot; only archive.md and
auxiliary.md differ, by these small textual changes. The two new references and
main Skill are unchanged. Existing package.nix resource-checker self-test passed
for all 7 skill documents, skill-creator metadata validation passed, all 21 local
Markdown links/anchors resolve, and git diff --check passed. No new tests/tools
were added. The checker was extracted unchanged to a task-owned temporary
folder under ignored tmp/ and its temporary outputs were removed. No network
or build was used in this final patch. Prior Nix success below applies to the
pre-refinement candidate, not a fresh build of current bytes. No substantive
blocker was found. The subsequent user commit and reported final Nix validation
complete this work; the ordinary index is now empty.

Authority: PLAN.md lines 550 onward supersede conflicting earlier N0–N5 guidance
and acceptance. The user adopted three clarifications: screen/sanitize before
target writes or staging (git add already persists objects); treat the revision
as authoritative; and use the exact actually examined state when a stage-specific
source association is selected, without retrospectively inserting parents or
requiring a source parent at every Formal checkpoint.

The revised implementation retains establishment/consolidation and single-source
knowledge rules. N1 adds first-persistence screening across Formal/Auxiliary
memory, archives, skills, checkpoint messages and retained ancestry, and narrows
archives to bounded independent evidence and minimal sufficient capture. N2–N3
support ongoing discovery lines and interleaved intermediate integration;
association/explanation/audit/provenance value need not pass a separate long-term
recovery prerequisite. Knowledge adoption, evidence archival and history retention
remain independent. The dedicated clean-reconstruction section/routes are removed;
GC/retirement stays a separate-authority boundary. N4 limits establishment to an
absent/materially insufficient target baseline; later-found earlier material with
a sufficient baseline uses memory reconstruction. N5 aligns routing, source-parent
criteria and Cabal resources. Original memory reconstruction text is unchanged.
Existing language, repeated-acquisition/prompt execution, fidelity, immutable
snapshot, exact-provenance and lifecycle rules remain in force.

Pre-refinement Nix validation used the uncommitted corrected snapshot under
`tmp/knowledge-workflow-revision-20261019T012804Z/retry-source`.
At that validation, all 66 build inputs matched its recorded SHA-256 values and worktree;
21 local links/anchors resolve, all 7 skill documents match Cabal declarations,
skill-creator quick_validate passed, and diff whitespace review passed.
The 24 revised scenarios, three adopted clarifications and one positive
association-value case are consistent in tabletop reasoning, documented in
acceptance.md in that validation directory. This is not independent-agent,
real Auxiliary lifecycle or another-project execution.

The first revised Nix attempt passed both runtime suites but failed the existing
resource checker because its top-level Markdown link included a fragment that
the checker treated as part of a filename. Only that SKILL.md link was changed
to a file link; no checker/runtime change. The original failed snapshot/inputs
remain separate from the corrected retry. The corrected command passed:
`timeout 120s nix flake check --no-write-lock-file -L
path:/home/lingyu/Projects/git-agent-workflow/tmp/knowledge-workflow-revision-20261019T012804Z/retry-source`.
Observed fresh compilation and both runtime suites passed, along with 13 help
and 7 skill resources through sdist/Cabal install/Nix exposure. Derivation:
`/nix/store/1jvfkrkzb8n62fy8y3g0chksc2ygmskz-git-agent-workflow-0.7.0.drv`.
Output: `/nix/store/q1fk16mpnj9cdxzrv3kql4famdmg1ng7-git-agent-workflow-0.7.0`;
actual skill root is its `share/skills/git-agent-workflow/git-agent-workflow`.
All seven installed documents matched that pre-refinement candidate. Non-host aarch64 Linux/Darwin
checks were omitted; existing Cabal metadata/bounds/PATH warnings are nonfatal.
retry-inputs.json/results.json identify the candidate and checks. These mechanical
reports are temporary review aids; durable conclusions belong here, without an
additional raw-output archive. Baseline HEAD is not the implemented/tested source.

Archive decision: the revised ignored PLAN.md (54,803 bytes, SHA-256
`db9e790e90e1481e88a32250452edbb83f6e2dec0423b66ee676f9b087c2483b`)
is already preserved as exact Chinese evidence at
`archive/2026-10-19T01-21-55Z--f47ba0b/`; its input is unchanged, so no duplicate
archive. It includes old and revised guidance; the three adopted clarifications
are recorded in memory, not inserted into the raw document. The earlier 18,819-byte
PLAN snapshot remains immutable at `archive/2026-10-19T00-40-35Z--f47ba0b/`.
Capture HEAD was context, not original document provenance or revised implementation.
Prior candidate `a3059dd9ad0450bf741aa827758dd664a3b352b7` and its 12-case
acceptance are superseded historical evidence; do not reuse their success as
acceptance of this revision or restore its clean-reconstruction requirement.

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
