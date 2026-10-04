---
name: git-agent-workflow
description: Use Git Agent Workflow (GAW) to establish, recover, maintain, ground, checkpoint, and hand off persistent agent memory across sessions. Use for GAW lifecycle discovery and memory work; not for general Git or project-history maintenance.
---

# Git Agent Workflow

GAW is a persistent agent-memory loop, not an ordinary project branching workflow. The declared GAW workspace holds current working memory; a GAW commit is a memory checkpoint; its first-parent chain preserves temporal memory history. Additional project-commit parents ground a checkpoint in exact project snapshots without merging their trees. Conversation and tool traces are evidence, not automatically durable memory.

## Establish state and resume

When repository lifecycle state is unknown, run `git gaw status` and read the report before choosing a branch, worktree, `init`, or `deploy`. Its default zero exit status means a report was produced, not that every reported branch or selector is valid. Do not run `git gaw status --diagnose` at every session start; it adds repository-wide Git diagnostics when a deeper investigation is warranted.

Enter the actual GAW worktree and run `git gaw check` for current-worktree readiness. `status` is repository-wide discovery; `check` examines the current committed and staged candidate but does not replace native Git inspection of unstaged or untracked changes. `check` may run in a worktree subdirectory; `git gaw commit` must run at its root.

Read the workspace declaration in `.gaw/config` and follow the existing organization of the declared paths. Do not edit `.gaw/config` as routine memory maintenance. Recover current goals, established conclusions, unresolved questions, provenance, and the next actionable step from the current workspace first. If that is insufficient, use `git gaw show` to inspect recent relevant checkpoints, then older first-parent history or an explicitly relevant associated project snapshot only as needed. Do not scan the whole history just to reconstruct a conversation.

## Maintain current memory

Distill work into information that could help a later agent act: the current objective and state, important decisions and reasons, difficult findings, unresolved issues, and useful handoff instructions. Respect an existing repository convention for raw evidence, but do not default to archiving every message or tool result. Do not impose a fixed set of memory files; create a new file only when the declared workspace lacks a suitable place.

Treat remembered project facts as a useful prior, not proof of current behavior. Recheck a potentially stale claim against the current project state when it matters, then update or remove obsolete current-memory text. Keep current memory current; let GAW history preserve earlier plans, assumptions, and conclusions instead of growing an append-only progress log by default.

## Ground and checkpoint selectively

Checkpoint a state that a future agent may need to restore and explain: a consequential finding, decision, phase transition, or handoff. A session boundary, small edit, or each new project commit does not by itself require a GAW commit. If no new durable information emerged, make no checkpoint.

Choose additional project parents for the exact snapshots the relevant work, observation, test, or comparison was actually performed against. Zero parents are normal for planning, cleanup, or handoff unrelated to a specific code snapshot. Use one or several only when each has a real provenance role; do not attach the latest branch tip, a future goal commit, or every intermediate commit by habit. An unchanged GAW tree can still acquire a meaningful project-parent association.

`git gaw commit` takes its complete candidate tree from the current index; it neither stages files nor includes unstaged or untracked changes. Before a checkpoint in the GAW worktree:

1. Inspect `git status`, `git diff`, and `git diff --cached` to understand the entire index, not just files changed in this session.
2. Stage intended memory with `git add <explicit-workspace-paths>`; avoid broad staging unless its full scope has been reviewed.
3. Inspect `git diff --cached` again, run `git gaw check`, and resolve findings that make the candidate invalid.
4. From the GAW worktree root, run `git gaw commit` with an appropriate message and only the selected project commits, then use `git gaw show` when the resulting checkpoint needs inspection.

GAW decides whether and what to checkpoint, not the general commit-message style. Reuse a specialized message skill when its evidence model applies; do not force one that requires a nonempty staged diff onto a checkpoint whose tree is unchanged but whose project-parent association matters.

## Handoff, lifecycle, and boundaries

Before ending substantive work, leave enough current memory for an agent without this conversation to know the goal, verified state, open questions, next action, and necessary provenance. Do not make a meaningless checkpoint solely because the session is ending. Keep the deployment in place for the next session; `git gaw undeploy` is not a session-end command.

Use `git gaw init` only when repository inspection shows no existing GAW history or GAW-like state. If either exists, inspect or recover it rather than reinitializing. Use `git gaw deploy` when an existing valid local GAW branch needs to be selected or materialized as local deployment. Repeating deployment against the same valid state is safe, but deploy does not fetch or repair malformed or conflicting GAW state. `git gaw branch` rename and deletion, and `undeploy`, are explicit lifecycle work, not part of routine memory maintenance. For damage or ambiguity, inspect `git gaw status`, the relevant worktree's `git gaw check`, and `git gaw help recovery` or `git gaw help hooks`; stop before manual ref changes, hook bypass, or speculative repair.

Within a validated GAW worktree, editing declared memory, explicitly staging it, and creating GAW checkpoints are the normal agent-memory loop. This narrow capability remains subject to higher-priority host policy; if the host does not provide it, follow that policy and report the host-integration gap rather than treating manual checkpointing as a GAW workflow requirement. It does not authorize native Git commits or history mutation in an ordinary project worktree, merge/rebase/reset, fetch/push, or GAW lifecycle changes.

Use public `git gaw` commands for GAW lifecycle, validation, checkpoint, and history operations. Native Git may be used for ordinary read-only repository/worktree inspection and for explicit staging inside the validated GAW worktree. Do not use native Git to mutate GAW refs or history. Do not call hidden machine options, internal Lisp APIs, or low-level ref and hook operations. Consult `git gaw help <command>` for exact syntax instead of treating this skill as a CLI reference.
