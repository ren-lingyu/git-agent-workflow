# Skill improvement backlog

## Status and scope

These are recoverable development proposals, not implemented GAW requirements
or authorization to implement them. The entry-trigger and entry-content
improvements are favored for implementation; native initialization support is
an optional, nonblocking research candidate that may be abandoned. Their
priorities describe this plan, not a new universal
priority protocol, identity system or fixed milestone schedule. Existing B0-B3
examples in current memory retain their original note-local meaning.

This file owns the three remaining proposals from the original four-item plan.
Checkpoint message defaults are committed and summarized in
[current.md](current.md), which also owns current progress and verification.
Earlier follow-ups and issue boundaries already
recorded there are not duplicated here. Implementation should preserve the
installed Skill's existing baseline and distinguish enhancements from completed
work. Registering this backlog did not itself implement any proposal.

## Entry-point trigger coverage

Priority: medium. Status: favored for implementation, not yet implemented.

The existing Skill already recommends a project Memory entry point when
Formal explicitly declares the `:skills` role. It already supports navigation
and interpretation without a fixed name/layout, and does not independently
require another entry point for an Auxiliary. Preserve that implemented
baseline; the enhancement is better trigger design.

An entry point should be readily applicable to substantive project work such
as implementation, review, debugging, planning and recovery, even when the
request does not explicitly mention GAW or Memory. Its description should name
the project boundary and actual tasks, avoiding unrelated-task activation.
Activation should select the knowledge relevant to the task, not require
loading the entire Memory. Entry responsibilities may be supplied by a
dedicated navigation Skill or appropriate task Skills; do not mandate another
Skill merely to conform to a name or shape.

Practice references include the [nixos Memory entry](https://github.com/ren-lingyu/nixos/blob/_agents/skills/nixos-gaw-memory/SKILL.md)
and the [org-roam-include entry](https://github.com/ren-lingyu/org-roam-include/blob/_agents/skills/org-roam-include-memory/SKILL.md).
The reviewed nixos practice is the primary organization reference, but its
description still emphasizes recovery, architectural knowledge and history;
it is not evidence that all proposed task triggers are already covered.
The org-roam-include description explicitly includes ordinary code, behavior,
bug, test, documentation and design work without requiring a Memory request.

Expected implementation area: references/skills.md. Do not add host discovery
mechanisms, installation checks, mandatory host integration or runtime
dependencies. Assess trigger wording by task relevance, not by claims of
guaranteed activation in every agent host.

## Entry-point content boundaries

Priority: medium. Status: favored for implementation, not yet implemented.

An entry point can accumulate duplicate project state, architecture and
historical explanation. Keep it useful as routing and interpretation guidance
instead of a second Memory store. The existing Skill already separates
reusable procedure from current knowledge, recommends referencing Memory
without duplication, and ties entry-point maintenance to organization or
interpretation changes. This proposal sharpens that boundary rather than
registering those completed rules as new work.

Retain trigger descriptions, reading navigation, tool/workflow references and
necessary stable interpretation conventions. Put concrete project knowledge,
architecture facts, design motivations, historical investigation results,
verification limitations and current work state in Memory. Prefer references
for generic GAW procedures instead of reproducing them in full. Route
specialized tasks to separate project Skills when useful; a substantive task
Skill may legitimately contain reusable procedures, so length alone does not
show an entry-boundary violation. Do not impose a word limit or fixed Skill
count, require retirement solely for overlap, or discard independently useful
project procedures in the name of deduplication.

Maintain the entry when Memory organization or interpretation conventions
materially change, not for every routine Memory edit. Keep this design goal
distinct from trigger coverage even if both are implemented together.

Practice references: the [nixos entry](https://github.com/ren-lingyu/nixos/blob/_agents/skills/nixos-gaw-memory/SKILL.md)
routes architecture and pending work to Memory and checkpoint selection to a
specialized Skill; the [nixpkgs entry](https://github.com/ren-lingyu/nixpkgs/blob/_agents/skills/nixpkgs-memory/SKILL.md)
shows a particularly small navigation surface. The
[emarccs entry](https://github.com/ren-lingyu/emarccs/blob/_agents/skills/emarccs-gaw-memory/SKILL.md)
contains more generic historical/workflow guidance and is a comparison case for
reference reuse, not an authorized cleanup target.
[org-roam-blog](https://github.com/ren-lingyu/org-roam-blog/blob/_agents/skills/org-roam-blog-memory/SKILL.md)
and [org-roam-organize](https://github.com/ren-lingyu/org-roam-organize/blob/_agents/skills/org-roam-organize-memory/SKILL.md)
combine categorized navigation with external workflow references.
[org-texmacs development](https://github.com/ren-lingyu/org-texmacs/blob/_agents/skills/org-texmacs-development/SKILL.md)
illustrates Memory recovery within a specialized task Skill, alongside separate
governance responsibilities.

Expected implementation area: references/skills.md. These practice locators
identify configured remote repositories/branches for material reviewed in
their project checkouts; their remote copies were not independently fetched
in this review. Recheck the relevant source state when implementing, rather
than treating mutable branch links as immutable evidence or universal rules.

## Optional native initialization support for Establishment

Priority: nonblocking, long-term exploration. Status: undecided; may be abandoned.
This is not a release gate or prerequisite for the other improvements.

When introducing GAW into a repository with existing development history,
an agent's native /init or similar workflow may already survey source,
configuration and documentation and generate a project description. Explore
whether optionally reusing that survey reduces the cost of initial knowledge
establishment enough to justify the complexity.

Possible boundaries, not adopted implementation requirements:

- Treat native initialization as an optional investigation technique, not a
  GAW dependency, required command or universal host mechanism.
- Generated or regenerated project descriptions may inform Establishment;
  generation alone supplies neither authoritative Memory nor independent
  verification. Check important facts against necessary original materials.
- Distinguish surveying the present project from reconstructing historical
  knowledge and provenance; a new summary cannot establish old observations.
- Generated results may remain temporary. Consider an Archive snapshot only
  for independent preservation value under the existing Archive workflow;
  do not mandate capture or mappings between repeated generations.

Investigate collisions with existing governance before any execution:
native initialization must not overwrite normative guidance or derived files
without authorization. GAW-derived AGENTS.md content must not loop back as
independent evidence for GAW. Preserve the distinction between canonical
templates, generated project-worktree artifacts and actual project evidence.
Do not introduce an agent-specific command or host dependency into the general
workflow. No /init command was invoked for this backlog task.

Concrete precedent: [org-texmacs governance](https://github.com/ren-lingyu/org-texmacs/blob/_agents/skills/org-texmacs-governance/SKILL.md)
owns an AGENTS.md template and a sync-agents helper deriving the ordinary
worktree artifact. This is project-specific one-way template authority, not a
generic bidirectional synchronization mechanism or permission to overwrite
files in another project.

If later adopted, first consider references/establishment.md; do not expand
this automatically into daily Memory Maintenance. Abandoning the candidate
is valid if reuse adds little value, conflicts with governance or introduces
unnecessary complexity.

## Related issue review

On 2026-10-29, a repository-scoped GitHub issue search returned issues #1-#10.
No issue directly tracked checkpoint type/scope defaults, entry-trigger coverage,
entry-content boundaries or native /init reuse. No issue was created or changed.

- [#10: optional bidirectional AGENTS.md maintenance](https://github.com/ren-lingyu/git-agent-workflow/issues/10)
  was fetched and is open. It overlaps the fourth candidate's governance,
  authority, overwrite and portability risks, and references the same
  org-texmacs precedent. It remains a distinct investigation: this candidate
  does not adopt bidirectional synchronization, implement #10, or depend on
  its completion.
- [#5: cross-session/cross-agent knowledge consolidation](https://github.com/ren-lingyu/git-agent-workflow/issues/5)
  was fetched and is closed as completed. It supplies broader knowledge-workflow
  context; its historical association with implemented entry guidance does not
  make the new enhancements unfinished #5 work. Do not reopen or attach closure
  claims to it for this backlog registration.

Retain these relationships without copying issue bodies or making new tracking
mandatory. Planning creates no requirement for a project-parent association,
raw-discussion archive, new Auxiliary history or history rewrite.
