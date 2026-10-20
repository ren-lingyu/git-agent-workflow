---
name: git-agent-workflow
description: Use Git Agent Workflow (GAW) to establish, recover, maintain, ground, checkpoint, and hand off persistent agent memory across sessions. Use for GAW lifecycle discovery and memory work; not for general Git or project-history maintenance.
---

# Git Agent Workflow

GAW is persistent agent memory, not an ordinary project branch workflow.
Each workspace tree represents a durable knowledge state. GAW commit parents
encode the historical dependencies needed to interpret that state. For non-root
checkpoints, the first parent supplies inherited knowledge history; initialization
roots have no first parent. Additional parents supply other necessary context
through exact Git commits, without merging their trees. Parent edges are not
citations, knowledge-adoption records, approval markers or validation results.
Formal GAW remains the authority for project-current memory; Auxiliary histories
can preserve independent discovery lines. Workspace content explains goals,
evidence, causes, decisions and results.

## Establish state and resume

When lifecycle state is unknown, run `git gaw status` and read the whole report
before choosing a branch, worktree or lifecycle action. Exit zero means a
report was produced, not that every finding is healthy. Reserve
`status --diagnose` for a relevant repository-wide investigation.

Enter the reported formal GAW worktree, run `git gaw check`, read `.gaw/config` and
recover current goals, established conclusions, unresolved questions,
provenance and the next action from its declared workspace first. Check also
native Git status and unstaged/untracked changes: check examines HEAD and the
staged candidate. If current memory is insufficient, inspect relevant recent
`git gaw show` checkpoints, then older first-parent history or an explicitly
relevant project snapshot as needed; do not scan all history by default.

Use v1 role metadata to discover organization, including mixed direct entries
and repeated groups. V0 and ungrouped entries declare no role: follow project
guidance and existing organization without inventing a declared role from a
directory name. Custom roles are valid and need project guidance to explain
them. Roles do not add Git protection, inheritance or precedence. Unknown-field
warnings are non-blocking metadata diagnostics; an unsupported version needs
a compatible CLI, not a protection bypass. Do not change config as routine
memory maintenance or require a version upgrade to resume.

When formal GAW declares workspace entries under the `:skills` role, prefer
maintaining a project-level skill as an entry point for reading and interpreting
the project's GAW memory. Follow [the project-skill workflow](references/skills.md)
for this special case.

## Shared content and snapshot constraints

- **Memory** holds current project knowledge, goals, decisions, verified facts,
  evidence, unresolved issues and next actions.
- **Archive** holds selected historical or raw evidence. Its contents do not
  automatically become current memory or agent instructions.
- **Skills** hold stable reusable procedures, constraints, routing and needed
  resources; current progress and temporary project facts belong in memory.
- **First-parent history** preserves evolution and superseded durable states.

Prefer English for newly authored GAW memory, skills, archive descriptions
and checkpoint messages, regardless of the language of source materials
or conversations. Preserve original wording where evidence fidelity,
quotations, identifiers or technical meaning require it. Respect explicit
user or project language requirements; do not rewrite existing history
merely to enforce this preference.

These are workflow roles, not required directory names or a closed CLI role
set. Maintain current memory promptly when a substantive finding, decision,
blocker or next action changes recovery; checkpoint selectively. Ordinary
source inspection and memory maintenance do not start archival assessment by
default. Consider preserving original evidence separately only when explicitly
requested or when a concrete independent preservation need emerges.

Persist knowledge that supports continued work. Screen and, where needed,
sanitize content before writing GAW target files, staging
(which already writes Git objects), saving checkpoint messages or associating
external history. This applies equally to formal and Auxiliary memory, archives
and project skills. Preserve useful technical facts without copying unnecessary
credentials, tokens, sensitive personal information, unapproved private content
or machine-environment details merely because they occur in a source.

Review the material actually being persisted and the relevant ancestor closure
of proposed additional parents, especially newly introduced history; do not
default to reading every raw log or reauditing the entire repository. Removing
a sensitive file in a later tree does not remove earlier Git objects, and a
clean source tip alone does not establish a safe history. If retention cannot
be made safe within the applicable permissions, stop the affected write or
association and report the limitation. Supported knowledge can still be distilled
without linking unsafe history. Later deletion, reconstruction or GC is not a
normal sanitization strategy; do not automatically rewrite or clean history.

The complete workspace snapshot must explain the durable state at that point.
Its references, terms and conventions must agree with each other, without
requiring a later checkpoint's layout or explanation. Individual files need
not repeat all context. Explicit external dependencies are allowed and need
not be copied, but their identity, reference roots and prerequisites must be
clear. Interpret earlier snapshots using their own conventions; do not apply
new standards retroactively or rewrite history to make it look current.

Review coordination across the whole candidate snapshot, not only new
paragraphs. Use relevant summaries, manifests and targeted reads while
respecting file-size, sensitive-data and workspace permissions. This semantic
review belongs to the skill; the CLI does not validate natural language.

Use workspace content to explain goals, evidence, causal relationships and results;
the Git graph supplies checkpoint evolution and historical dependencies on exact
external states. Preserve substantive historical explanations when useful,
without requiring separate explanatory material for every existing parent or a
parallel parent inventory. Do not use GAW checkpoint OIDs as durable semantic identifiers, either for the checkpoint itself or for other checkpoints expected to remain identifiable across history rewriting. Prefer Git relationships and stable workspace paths. Usually omit project OIDs already supplied by project-parent edges; retain them when independent historical lookup or reproducibility needs justify them, without treating object identity as stable semantic identity across rewriting. Historical evidence, diagnostic output, and other hashes are not automatically semantic dependencies merely because they contain hash strings.

Recover checkpoint ancestry, external-parent relationships and retained-history
reachability from Git. Do not maintain parallel static indexes of Git-derived
relationships or metadata in GAW memory. Persist substantive knowledge and
explanations not supplied by the Git graph and committed trees. Temporary
queries, calculations and displays are useful; necessary source/path references
and external locators with an independent purpose remain valid. This is not a
blanket prohibition on UUIDs, OIDs or paths.

## Load workflow details when needed

- For ordinary current-memory maintenance, single-source historical reconstruction
  or handoff, read [the memory workflow](references/memory.md).
- For an absent or materially insufficient knowledge baseline, in formal GAW or
  Auxiliary, read [establishment](references/establishment.md); it reuses the
  memory workflow's reconstruction rules.
- For comparing and integrating different knowledge scopes into formal memory,
  read [consolidation](references/consolidation.md). With no substantive formal
  baseline, combine it with establishment; Auxiliary is not a required step.
- When original-evidence preservation is explicitly requested or independently
  warranted, read [the archive workflow](references/archive.md) for selection,
  faithful capture and verification. Ordinary source use does not trigger it.
- For independent Auxiliary source histories, their layout/lifecycle, optional
  source-history associations or retained-source recovery,
  read [the Auxiliary workflow](references/auxiliary.md).
- For creating, modifying, referencing, renaming or retiring project skills,
  read [the project-skill workflow](references/skills.md).

Read only the references relevant to the task. They inherit these shared
constraints and do not create additional execution permissions.

## Ground and checkpoint selectively

Checkpoint a state that a future agent may need to restore and explain: a consequential finding, decision, phase transition, or handoff. A session boundary, small edit, or each new project commit does not by itself require a GAW commit. If no new durable information emerged, make no checkpoint.

Choose additional external parents for the exact project or Auxiliary source snapshots the relevant work, observation, test, or comparison was actually performed against. Zero parents are normal for planning, cleanup, or handoff unrelated to a specific code snapshot. Use one or several only when each has a real provenance role; do not attach the latest branch tip, a future goal commit, or every intermediate commit by habit. An unchanged GAW tree can still acquire a meaningful project-parent association.

Assess knowledge integration, raw-evidence archival and historical dependency
selection separately. For source-history associations, confirm the exact relevant
source state, the value of recording its association with formal knowledge
evolution, and an acceptable authorized retention boundary. Explanation, audit,
provenance review or recovery can justify an association; an extra long-term
recovery purpose is not required. The historical-dependency definition interprets
these relationships without adding a separate necessity test to the selection rules.
An additional parent retains its complete ancestor closure; apply the existing
screening and authorization rules before persistence. Reachability or branch
deletion alone does not justify an association. Reading a source, integrating
knowledge or archiving material does not by itself require a parent. Follow
[source association guidance](references/auxiliary.md) without mandatory
associations or rewriting earlier checkpoints. Without source history retention,
formal memory must explain the knowledge and limits without depending on that
history remaining available. Existing exact-snapshot
project-parent rules still apply; these judgments add no CLI parent roles or IDs.

Keep project-parent associations within a checkpoint as homogeneous in meaning as practical. Do not interpret additional-parent positions as different business roles such as based-on or resulting state. For associations with project states from different phases, prefer separate checkpoints when each state has independent recovery value; this does not require one project parent per checkpoint or one checkpoint per project commit. Homogeneity guides agent organization, not a new protocol invariant requiring the CLI to interpret natural language. Every selected parent still needs the exact-snapshot evidence described here.

For each retrospective checkpoint, assess additional project parents independently of its first-parent memory position. Attach each parent only when existing evidence unambiguously identifies the exact commit against which that checkpoint's relevant work was performed. Current `HEAD`, nearby history, timestamps, and likely work intervals do not establish provenance; omit uncertain parents rather than guessing or attaching candidate ranges. Missing project provenance does not prevent a memory checkpoint. A later revalidation may ground the revalidated state in the snapshot actually checked, but does not establish the original session's provenance; do not revalidate merely to obtain a parent. If missing original provenance affects interpretation, record that uncertainty briefly in current memory.

`git gaw commit` uses the complete current index, not unstaged or untracked
files, and must run at the GAW worktree root. Before a checkpoint:

1. Inspect native Git status, unstaged diff and the entire staged diff. Confirm
   that the complete candidate snapshot is valid and coherent.
2. Separate changed paths inside `.gaw/` from changed paths outside it,
   including additions, deletions, content, modes and cross-boundary moves.
   The comparison is with the first-parent tree; unchanged index entries do
   not count. Root init and old history are unaffected, and unchanged-tree
   associations retain existing rules. `git gaw check` does not replace this
   commit-transition check. Do not invent extra commit categories or mandated
   migration steps; preserve validity of each intentional intermediate state.
3. Stage intended declared-workspace paths explicitly, review the complete
   index again, run `git gaw check` and resolve invalid-candidate findings.
4. Use public `git gaw commit` with an appropriate message and only justified
   external parents. Inspect the result with `git gaw show` when needed.

GAW determines recovery value, not commit-message style. Reuse a suitable
message workflow when applicable, without forcing a nonempty-diff requirement
onto a meaningful unchanged-tree project association.

## Lifecycle and authority

Before ending work, check that current memory already maintained during the
work is sufficient to resume. Do not checkpoint solely for a session boundary.
Keep deployment in place; undeploy is not a session-end action.

Use `git gaw init` only when repository inspection shows no existing GAW history or GAW-like state. If either exists, inspect or recover it rather than reinitializing. Use `git gaw deploy` when an existing valid local GAW branch needs to be selected or materialized as local deployment. Repeating deployment against the same valid state is safe, but deploy does not fetch or repair malformed or conflicting GAW state. `git gaw branch` rename and deletion, and `undeploy`, are explicit lifecycle work, not part of routine memory maintenance. For damage or ambiguity, inspect `git gaw status`, the relevant worktree's `git gaw check`, and `git gaw help recovery` or `git gaw help hooks`; stop before manual ref changes, hook bypass, or speculative repair.

Within a validated GAW worktree, declared memory edits, explicit staging and
GAW checkpoints form the normal loop, subject to active host authorization.
If the host does not grant that capability, report the integration gap rather
than treating manual checkpoints as a GAW requirement. A skill or plan does
not authorize project writes, builds, networking or external actions.

Use public GAW commands for lifecycle, validation, checkpoint and history
operations. Native Git is for ordinary read-only inspection and authorized
explicit staging. Do not use native commits or direct ref updates to mutate
GAW history, call hidden machine options/internal APIs, bypass hooks, perform
ordinary project history mutations, or silently repair state. Consult public
`git gaw help <command>` for exact syntax.
