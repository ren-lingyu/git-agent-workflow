# Consolidate knowledge across sources

Apply the main skill's snapshot, provenance, checkpoint and authorization rules.
Use consolidation to compare and integrate different knowledge scopes into
substantive formal memory. One or several external sources may be involved;
ordinary updates within the current scope remain [memory maintenance](memory.md).
When formal knowledge is absent or insufficient, combine this comparison with
[establishment](establishment.md) to build the initial baseline.

Sources may be Auxiliary histories, other knowledge records, project documents,
or directly available conversations and tool evidence. They need not first
become Auxiliaries or archives. Access to another repository or agent's material
still requires its applicable authorization; no implicit import or fetch is added.
The ordinary outcome is knowledge integration, not preservation of source
materials. Do not start archival assessment for each source encountered;
follow the archive workflow only for an explicit preservation request or a
concrete independent original-evidence need.

## Inventory the relevant knowledge

Recover formal current memory and identify the integration objective. Bound
each source's work scope and evidence horizon, distinguishing overlap, forks,
known ordering and gaps. Locate adopted conclusions, retired proposals,
unfinished decisions and what verification actually covered. Identify material
unsuitable for long-term retention before choosing how to preserve a source.
Use useful source context, not a new source-ID registry or a mandatory manifest.

Compare relevant content with formal understanding: what supplements it,
duplicates it, conflicts with it, is obsolete, or remains unresolved? Check
supporting evidence for consequential disagreements. Neither recency nor several
agreeing summaries proves a claim. Revalidate a potentially stale project fact
when necessary and authorized, distinguishing that present result from original
historical validation. If validation is unavailable, preserve the uncertainty.

Adopt only knowledge with continuing value, explaining important motivations,
corrections and evidence limits. Distinguish what the source knew at the time,
later corrections, and judgments made during this integration. An unresolved
material disagreement can remain an explicit open question rather than a
manufactured consensus. Do not copy full traces into formal memory by default.

## Coordinate the work and recover interruptions

One integrator can examine sources centrally. In distributed work, authorized
agents establish bounded source knowledge separately and a designated integrator
updates formal memory. Hybrid work combines delegated sources with direct
inspection. All modes use the same establishment, evidence and checkpoint rules;
agent count or session count does not determine source or checkpoint count.
Delegation itself remains subject to host authorization and available tools.
Auxiliary is optional: agents may continue the same scope in turn, and one
agent may handle several scopes without a dedicated history for each agent.

Coordinate formal writes rather than silently creating competing writers.
Before each checkpoint, re-read current formal state and review the complete
candidate; reconcile intervening work without overwriting it or rewriting history.
Organize stages by meaningful topics, knowledge dependencies or recoverable
results, not one formal commit per source.

Integrate useful stages of ongoing discovery lines, not only their final tips.
The same Auxiliary can contribute intermediate checkpoints to several formal
states; different lines can be interleaved, and one formal checkpoint can select
several source states. Source work can continue or correct an earlier conclusion
after integration. Formal first-parent history records checkpoint evolution;
its external parents supply historical context without merging trees or
establishing a total ordering of independent source histories. If a source advances
during review, keep the exact state actually examined or inspect the new state
before selecting it.

Maintain enough current state to resume: what knowledge was adopted, which
source scopes were examined or remain, unresolved disputes, evidence and
validation limits, and the next action. Recover historical associations from
Git rather than maintaining a parallel index. Retain explanations that Git
cannot supply and that affect continuation, without a command-by-command log.

## Decide integration, archival and historical dependencies separately

- **Knowledge integration:** what continuing conclusions, reasons, limitations
  and questions belong in formal memory?
- **Evidence archival, when triggered:** which raw material independently merits
  preservation under [the archive workflow](archive.md)?
- **Historical dependency selection:** which exact source states merit association
  with this formal knowledge state, with evidence for each selected state and
  acceptable ancestor-retention consequences?

These judgments are related but not interchangeable; they are not a mandatory
three-part procedure for every source. In ordinary consolidation, maintain useful
knowledge without initiating an archive operation. When an archival need arises,
evaluate it separately; declining capture does not leave consolidation incomplete.
Source inspection, knowledge integration and archival capture do not by themselves
imply a parent. Selected
parents express the historical dependencies described by the main skill; their
ancestor closure remains reachable as a consequence. Before choosing an
association, confirm relevance, evidence of the exact state used, the value of
recording that context, and acceptable retention/sanitization boundaries.
Explanation, discovery-line relationships, audit/provenance review or recovery
can justify an association; an extra long-term recovery purpose is not required.
Reachability or branch deletion alone does not justify a parent. A clean-looking
tip does not establish an acceptable ancestor boundary. Apply the main skill's
screening before persistence or association, without importing all raw material
just to inspect its suitability.

For selected Auxiliary associations, follow [the integration and lifecycle
rules](auxiliary.md#integrate-selected-knowledge-into-formal-gaw). Keep existing
exact-snapshot project-parent rules; external trees are not merged and parent
positions have no fixed business roles. Do not invent parents to make provenance
look complete, or use checkpoint OIDs as durable semantic identities.

When a stage-specific association is chosen, a later association to a newer
source state cannot replace recording the exact state used at that stage.
Ancestor reachability alone does not identify the exact context needed by an
earlier formal stage. This does not require source parents at every stage or
retrospective parent insertion into committed formal checkpoints; preserve
relevant gaps in current knowledge instead.

If the relevant source history is not retained, formal memory must still explain
the useful knowledge and its evidentiary limits without depending on that history
remaining available. Distill essential explanations and preserve selected
evidence independently when warranted. If existing history cannot be retained
safely, stop its affected association; do not turn history replacement or object
cleanup into a routine integration step.

## Accept the integrated state

Review current formal knowledge for correctness, coordination and completeness
relative to the agreed objective. Account for examined source scopes and missing
evidence, important recoverable evolution, conflicts and corrections, and the
methods, scope and limitations of any validation performed. Check the accuracy
of chosen stage-specific dependencies and their actual retained
ancestry; without source retention, check that no essential explanation relies on material
that may disappear. Ongoing source work must remain resumable after integration.

The resulting workspace and next action must support a future agent without
the original conversations. Use normal candidate review, check and selective
checkpointing. Completion does not mean every historical assertion was rerun,
every source was retained, or any source must now be deleted. Source retirement
is a separate knowledge-retention, worktree and lifecycle decision.
