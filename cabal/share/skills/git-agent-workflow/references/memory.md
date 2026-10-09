# Current memory and supported reconstruction

Apply the main skill's snapshot, reference, provenance and authorization
constraints. Follow the existing declared workspace organization; no fixed
set of memory files is required.

## Maintain the current state

Distill work into information that could help a later agent act: the current objective and state, important decisions and reasons, difficult findings, unresolved issues, and useful handoff instructions. Respect an existing repository convention for raw evidence, but do not default to archiving every message or tool result. Do not impose a fixed set of memory files; create a new file only when the declared workspace lacks a suitable place.

Maintain current memory as substantive work evolves, not only during retrospective consolidation or session handoff. When a verified finding, adopted decision, blocker, objective, current state, or next action materially changes what a future agent should resume from, update the declared workspace promptly. This does not require a checkpoint for every update; create one only when the resulting state has independent recovery value.

Before reconstructing a session that predates usable GAW memory history, establish its full evidence horizon, honoring any start or end boundary the user gives. Do not silently replace that horizon with the currently visible conversation tail, the current workspace, or the beginning of existing GAW history. Survey the whole horizon coarsely before choosing checkpoints. Account for each substantive interval as already represented in GAW history, examined for durable states, or lacking recoverable evidence; existing GAW history can establish what was persisted, but does not redefine where the session began.

When substantive work predates usable GAW memory history, treat the session as evidence for both current memory and distinct earlier durable states. Recover consequential findings, adopted or revised decisions, validation results, and phase transitions as separate checkpoints only when each state has independent recovery value and its content and relative order are supported by the evidence. For each checkpoint, make the declared workspace represent the full durable state recoverable at that point, then create GAW commits in the supported first-parent order. Leave the final workspace expressing the current state, correcting stale content when newer evidence supersedes it. These commits are created at consolidation time; do not backdate them to the original session.

Do not replay the conversation or tool transcript, checkpoint minor steps, or invent intermediate states or ordering. Before the first reconstructed checkpoint, pause to seek further evidence if a substantive gap within the requested horizon might hide earlier durable states or affect their order. If the gap is confirmed unrecoverable, proceed only with supported evolution; identify the gap in the current memory when creating checkpoints and report it explicitly rather than claiming full coverage. If no checkpoint is warranted, report the gap without writing memory. Where evolution is uncertain, keep only the smallest checkpoint set whose states and order can be supported; if only the final state is supported, consolidate that state alone, and if nothing durable is new, leave the workspace unchanged. Before declaring reconstruction complete, account for the whole original horizon, including persisted intervals and unrecoverable gaps. Continue from existing valid GAW history rather than rewriting it as part of routine consolidation; correcting an already-collapsed historical checkpoint is separate recovery work.

Treat remembered project facts as a useful prior, not proof of current behavior. Recheck a potentially stale claim against the current project state when it matters, then update or remove obsolete current-memory text. Keep current memory current; let GAW history preserve earlier plans, assumptions, and conclusions instead of growing an append-only progress log by default.

## Make the next action recoverable

Separate a current conclusion from a retired proposal. Keep a proposal as
current only when its adoption, uncertainty or next decision still affects
work. Update stale goals, references and validation claims when newer evidence
supersedes them; leave the former durable state in first-parent history.
Remove content that no longer helps recovery rather than retaining it merely
because it appeared in the conversation. Read relevant earlier snapshots when
an evolution or rationale matters, using their own conventions.

A useful handoff identifies the objective, verified state, adopted decisions
and reasons, open questions or blockers, the next actionable step, and the
scope and limits of validation. Check that this state agrees with the rest of
the candidate workspace before checkpointing. Handoff is a consistency check
on memory maintained during the work, not the normal first update.

Persist the necessary content of temporary inputs instead of relying on their
filenames. An incidental filename may remain as source context when the
content needed to resume has actually been incorporated into the snapshot;
that mention alone does not justify rewriting history. Conversation or tool
traces are evidence to distill, not a transcript to import by default. Use the
archive workflow when selected raw material has independent retention value.

Checkpoint only supported states with independent recovery value, following
the main skill's index review and exact project-parent rules. A session end,
a project commit or a wording edit alone is not a reason for a checkpoint.
