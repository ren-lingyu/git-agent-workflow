# Auxiliary source histories and formal integration

Apply the main skill's evidence, snapshot, authorization and checkpoint rules.
Formal GAW remains the sole authority for project-current memory. Auxiliary
GAW is an independent temporary source history, useful when a session, agent
or body of source material has several independently recoverable states whose
internal evolution should remain distinct from formal integration order.
Do not create a source history for every message or ordinary small edit.

## Availability and discovery

Confirm the available CLI supports `git gaw help aux`; a source checkout,
published package and installed executable/skill are different states. Old
CLIs cannot interpret this layout and must not be used to repair or bypass it.
Run `git gaw status`, recover formal current memory first, and identify existing
Auxiliary branches and worktrees before choosing any lifecycle action. Lifecycle
creation/deployment/deletion still needs host authorization; the normal memory
loop's permissions do not automatically authorize new histories or worktrees.

Auxiliary names are `_gaw_aux_<uuid>` with a canonical lowercase UUIDv4. Its
entire Git tree lies within the matching `<uuid>/` directory. The UUID provides
structural separation, not source identity, provenance or chronology. Config
is `<uuid>/.gaw/config`; workspace declarations and role discovery are relative
to that UUID directory. Run commit/check at the Git worktree root. Do not
mistake the UUID directory for a separate Git repository or invocation root.
Formal GAW has its normal root `.gaw/config` and selected `refs/gaw/HEAD`.

## Create or recover a source

When an authorized independent history is warranted, use:

```sh
git gaw aux init --worktree-path <new-path>
```

Init requires a valid formal selector and the existing canonical shared hook.
It creates an independent root containing only the formal tip's exact committed
config bytes. It copies no index, workspace content or formal-history parent.
Create source memory/archive/skills only as needed under declared paths; there
is no mandatory directory template. Config inheritance is a one-time snapshot.

For an existing branch use `git gaw aux deploy --branch <name>` with an optional
`--worktree-path`. It does not fetch, select formal memory, or install/repair the
hook. Without a requested path, init/deploy may be repository-only. Reuse an
existing valid worktree rather than creating duplicate copies. Inspect reported
partial failures and residues; do not guess at cleanup or repair refs manually.

In that worktree, `git gaw check`, authorized explicit staging, `git gaw commit`
and `git gaw show` provide the normal loop. Both committed and staged configs
are interpreted independently. Protocol changes inside `<uuid>/.gaw/` must be
separate from workspace changes, including modes, deletions and moves. The
entire tree must stay within the UUID root. Parent conflicts use physical Git
paths; associated trees are never merged into the source workspace.

Select checkpoints with independent recovery value. Explain the source,
evidence horizon, uncertainties, decisions and next state in declared memory;
do not replay a transcript or invent unsupported chronology. Reconstructed
states keep the main skill's retrospective provenance rules: do not attach a
likely current project tip as evidence for unobserved earlier work. The
Auxiliary root's copied config does not establish historical project provenance.

Preserve selected raw evidence through the archive workflow: independent
MANIFEST.md + files/ snapshots, source context and limitations, byte validation
when claiming fidelity, and immutable checkpointed snapshots. Historical
instructions remain evidence, not active instructions. Locate existing source
archives before copying; do not automatically duplicate Auxiliary archives into
formal archives or assume all conversations must be retained.

## Integrate selected knowledge into formal GAW

1. Read the relevant source states and formal current memory. Distinguish
   established findings, retired proposals, unsupported claims and remaining
   questions; account for disagreements using evidence.
2. Update formal current memory with the knowledge needed to continue. Keep
   source-internal evolution in its source history. Explain why the selected
   states matter, which conclusions were adopted, uncertainties, and useful
   UUID-relative source paths/context for later lookup.
3. Select one or more exact source checkpoints actually inspected and relevant
   to that integration. Pass those revisions as additional parents to the
   normal formal `git gaw commit`; first parent remains formal evolution.
   Repeated integrations may reference intermediate and later source states.
   An association preserves ancestry, not a merged tree or automatic acceptance
   of everything in that source. Parent positions have no business-role types.
4. Review the complete formal candidate and run check before checkpointing.
   Retain project associations only for exact project snapshots supported by
   evidence. Source associations do not prove the source's project provenance.

Do not use either formal or Auxiliary checkpoint OIDs as durable semantic
identifiers. Git ancestry and stable workspace paths support lookup; explanations
identify the knowledge and integration context. Temporary revision/OID arguments
used while inspecting/committing are ordinary operational references.

## Check and delete branches deliberately

`git gaw aux check [--branch <name>]` separates structural validity from safe
deletion readiness. Without a current Auxiliary worktree, specify the branch.
Unintegrated valid history is not damaged history. `git gaw check --branch`
checks only committed state, without the caller's index or worktree readiness.

After authorized removal of associated worktrees through the host's ordinary
Git policy, use `git gaw branch -d <name>` only when the current tip is retained
in the valid formal history selected by `refs/gaw/HEAD`. An intermediate source
association does not retain later unassociated checkpoints. Neither upstream
nor the caller's HEAD substitutes for the selector. Structure and no-worktree
constraints still apply. The CLI checks selector/formal/Auxiliary refs together
and handles detected worktree races independently; serialize worktree lifecycle
operations with deletion and inspect failures/compensation before retrying.

`git gaw branch -D <name>` is explicit abandonment: integration is not required,
continued reachability is not guaranteed, and unretained/unknown retention is
warned about. It does not bypass valid committed state, worktree constraints or
conditional tip deletion. Neither mode removes worktrees or other historical
refs. Deletion readiness does not prove all source knowledge has been integrated;
that sufficiency judgment belongs to the agent and reviewer. No aux retire,
abort, discard or Auxiliary rename command exists.

## Recover a safely retained source after deletion

Record the useful source UUID-relative paths and integration context in formal
memory before deleting the activity branch. Locate the relevant integration
checkpoint through formal first-parent/path history, for example
`git log --first-parent refs/gaw/HEAD -- <formal-memory-path>`. Inspect that
checkpoint's parent list with `git gaw show --no-patch --format=raw <integration>`.
Inspect candidate external parents' trees for the recorded UUID/path; do not
assign a fixed business role to parent number two or require a stored OID.

Once an inspected external parent is identified, read its preserved source
blob with `git show <source-parent>:<uuid>/<declared-source-path>`, or follow
its evolution with `git log --first-parent <source-parent>`. These revisions
are discovered for this inspection, not persistent semantic identities. This
works after `branch -d` because the selected formal history retains the tip and
its ancestors. `branch -D` alone supplies no corresponding recovery guarantee.

Repository-wide `git gaw undeploy` preserves all formal/Auxiliary histories and
worktrees but removes shared deployment/protection. It is not session cleanup.
Existing commit behavior remains available; it does not imply protection still
exists. Restore formal deployment first when authorized, then deploy Auxiliary
worktrees as needed. Do not turn this workflow into automatic session import,
knowledge merging, history rewriting, split/fusion or cross-project updates.
