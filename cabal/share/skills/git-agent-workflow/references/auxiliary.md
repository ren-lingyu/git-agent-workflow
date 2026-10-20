# Auxiliary source histories and formal integration

Apply the main skill's evidence, snapshot, authorization and checkpoint rules.
Formal GAW remains the sole authority for project-current memory. Auxiliary
histories preserve independently evolving knowledge discovery lines, including
work that progresses in parallel, alternates between agents, or continues across
sessions. Formal can integrate useful stages while those lines keep developing.
A line can span sessions, and one session or agent can contribute to several
lines; no one-to-one mapping or history for every small edit is required.

Within its bounded source scope, Auxiliary uses the same
[establishment](establishment.md), [memory maintenance and reconstruction](memory.md),
archive, checkpoint and exact-provenance rules as formal GAW. It adds an
independent history, source scope, layout and lifecycle boundary, not a second
knowledge standard. Cross-scope comparison belongs to [consolidation](consolidation.md).

## Availability and discovery

Auxiliary history requires GAW 0.7.0 or newer. Confirm the available CLI supports
`git gaw help aux`; a source checkout,
published package and installed executable/skill are different states. Old
CLIs cannot interpret this layout and must not be used to repair or bypass it.
Upgrade the executable used by the shared hook as well as interactive commands
before creating or importing Auxiliary history; keep the skill compatible.
Run `git gaw status`, recover formal current memory first, and identify existing
Auxiliary branches and worktrees before choosing any lifecycle action. Lifecycle
creation/deployment/deletion still needs host authorization; the normal memory
loop's permissions do not automatically authorize new histories or worktrees.

Auxiliary names are `_gaw_aux_<uuid>` with a canonical lowercase UUIDv4. Its
entire Git tree lies within the matching `<uuid>/` directory. The UUID provides
structural separation, avoids branch/tree path collisions and satisfies Auxiliary
commit layout requirements. It is not a stable semantic identifier for a source
history or its knowledge scope, and does not establish provenance or chronology.
Config is `<uuid>/.gaw/config`; workspace declarations and role discovery are relative
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

Use establishment for an insufficient source baseline and memory maintenance
thereafter, including evidence-backed historical reconstruction when warranted.
The Auxiliary root's copied config does not establish historical project
provenance. Apply [archive selection and capture](archive.md) independently;
locate existing evidence before copying rather than automatically duplicating
source archives into formal archives.

## Integrate selected knowledge into formal GAW

Use consolidation to compare sources, resolve or retain disagreements, adopt
useful knowledge and review the formal candidate. Knowledge integration and raw
evidence archival do not automatically require a source-history dependency.

Choose an exact relevant source checkpoint when recording its historical context
has real value: explaining formal conclusions or discovery-line relationships,
supporting audit/provenance review, or recovering meaningful evolution. A separate
long-term recovery purpose is not required for every parent. Source inspection
does not mandate an association. Confirm the state actually used and its evidence,
and apply the main skill's screening and authorization rules to its complete
ancestor closure, including archives and newly retained history. Do not attach
a parent for reachability or branch deletion alone.

Pass selected revisions as additional parents to normal formal `git gaw commit`;
zero source parents is valid. First-parent history records the evolution of
formal GAW checkpoints. Additional parents supply relevant external historical
context without merging their trees. Parent positions have no fixed business
roles; existing exact-snapshot project associations remain governed by the
main skill.

For example, discovery lines A1 → A2 → A3 and B1 → B2 → B3 may contribute:

| Formal checkpoint | Selected source parents |
| --- | --- |
| F1 | A1 |
| F2 | B1 |
| F3 | A2 |
| F4 | A3 and B2 |

The example illustrates selected parent associations, not a required
source timeline, integration schedule or checkpoint count. Neither parent
positions nor the resulting ancestry establish a total ordering of independent
source histories.
Each source keeps its own supported evolution. Intermediate checkpoints,
repeated associations and several source parents at one stage are normal;
neither the latest tip nor completion of all source work is required.

When choosing a stage-specific dependency, use the exact state actually used
then. Later retaining a newer source checkpoint can make earlier states reachable,
but does not replace an earlier stage's explicit association. Do not retroactively
insert parents into committed formal history or infer that every formal checkpoint
needs a source parent. Record any relevant historical association limits in
current knowledge. Never attach a latest tip merely to make its branch deletable.

Recover source relationships and locations from Git history and committed trees,
without a parallel UUID or checkpoint index. Keep substantive explanations and
evidence limits in memory; cite a source location when it helps explain particular
knowledge. Without retention, formal memory must explain the adopted
knowledge and evidence limits without depending on the source branch, OID or path
remaining available. Review/check the complete formal candidate in either case.

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

Knowledge integration does not require retiring a discovery line; its work may
continue. Retaining an intermediate checkpoint does not retain a later tip or
make it safe to delete. Branch deletion does not prove related objects were
erased. GC is separate authorized repository maintenance, not a routine
integration step or a substitute for screening before persistence.

## Recover a safely retained source after deletion

Locate the relevant formal checkpoint through its first-parent history, for
example `git log --first-parent refs/gaw/HEAD`, optionally narrowing to a relevant
formal memory path with `-- <formal-memory-path>`. Inspect that checkpoint's
actual parent list with `git gaw show --no-patch --format=raw <integration>`.
Inspect relevant external parents' committed trees, for example
`git ls-tree -r --name-only <source-parent>`, to discover the UUID-relative config,
workspace and needed source files. Use the checkpoint's substantive memory
explanations to guide the search; no pre-maintained UUID index or stored OID is
required, and parent number two has no fixed business role.

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
