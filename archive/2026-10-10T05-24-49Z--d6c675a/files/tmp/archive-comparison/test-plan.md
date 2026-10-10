# Archive metadata comparison: isolated test design

Status: design only. Candidate tools have not been run, built or selected.
Basis: root PLAN.md, including revised section 3's uniform snapshot model.

## Goal and scope

Choose one metadata standard for all future snapshots, from one historical
text document to related experiment files. Compare Data Package 2.0 and
RO-Crate 1.3 before changing bundled archive guidance. Choose standard,
creator/editor, reader, validator and capture mechanism separately. Do not
add a GAW archive CLI, private metadata parser, mandatory checksums or
historical migration. Preserve selected bytes and source-relative paths.
The interim MANIFEST.md/files workflow supplies durable evidence independently
of candidate selection.

## Isolation and fixtures

Create a fresh run under ignored root `tmp/archive-comparison/`. Verify ignore,
absence of tracked files and resolved path boundaries. Never reuse another
run's output or modify source archives.

```text
run-<UTC>/
├── inputs/                 captured test inputs, treated read-only
├── datapackage/<tool>/     separate copies for each tool/case
├── rocrate/<tool>/         separate copies for each tool/case
├── capture/                controlled copy/mutation fixtures
├── boundary/               disposable outside-root canaries
├── environment/            fixed Nix definitions/version inventory
└── results/                commands, exit codes, observations, matrix
```

Primary multi-file source: org-texmacs GAW snapshot
`archive/2026-10-06T14-50-30Z--b09b451/`, files from its MANIFEST.md:
`tmp/doc-01-file-url-probe.el`, `.scm`, `.txt` (runner/query/output).
Copy archived bytes; do not claim they come from the current ordinary worktree.
Record archive root and path mapping. The 16-59-25Z footnote and 17-35-50Z
bibliography snapshots are directed references, not mandatory execution inputs.

Single-file source: root PLAN.md captured in this preparation's immutable GAW
snapshot. Treat it as a historical planning document, retaining `PLAN.md` as
its original path. Do not fabricate experiment roles/relations. For each
standard, use the same model/tool chain as the multi-file case. Measure
metadata bytes, entity/resource count, steps and adapter code.

Generate disposable cases for nested duplicate basenames, spaces, Unicode,
literal percent signs and source files named MANIFEST.md or the candidate's
metadata filename. Symlink/traversal targets are only disposable canaries
inside the authorized run directory, never actual external user data.

## Tool and environment gate

Inventory exact packages/versions against this project's locked nixpkgs
(`55ba7f49ef2962b42cbd126522b7df5f95037679` at design time). Record standard
version separately from implementation version. Do not update project locks
or treat upstream claims as verified compatibility.

- Data Package baseline: Python frictionless. Non-Python candidate order:
  frictionless-ts, then datapackage-go if the first cannot provide required
  local non-tabular operations. Inspect datapackage-js/R frictionless only
  to close a demonstrated 2.0/interoperability gap.
- RO-Crate baseline: ro-crate-py and independent rocrate-validator. Compare
  ro-crate-ruby for non-Python read/write interoperability; inspect ro-crate-rs
  if Ruby cannot complete that workflow. Validator interoperability does not
  prove editing ability.

Verify attributes and fixed source availability before building. Package missing
tools declaratively inside the isolated environment, fixing source hashes and
dependencies. No runtime pip/npm/cargo install. Record failures, closure sizes,
bundled schemas/contexts and maintenance cost. Do not reject a standard solely
because one implementation is incomplete. Short library callers are test
adapters, not GAW tools or replacement parsers/validators.

Before execution, prepare concrete commands with network/source scope, possible
cache/store writes and 120-second build timeouts; runtime probes use 30 seconds.
Stop/report timeouts rather than silently retrying. No builds or downloads
occur in this design phase.

## Test matrix

Run positive cases first; mutate independent copies one condition at a time.
Record command/API, tool/standard versions, exit status, observed behavior,
evidence path and whether each guarantee comes from the standard, tool or
project policy.

| ID | Cases | Acceptance / decision evidence |
| --- | --- | --- |
| C1 | Real three-file snapshot, normal creation API | Exact bytes/paths, valid selected-version metadata, no private parser. |
| C2 | One document archived twice | Same standard as C1, independent directories/metadata, first snapshot unchanged. |
| M1 | Title/purpose/time/limits, file path/role/source state | Existing API creates/reads all; report extensions and single-file overhead. |
| M2 | Runner/query/output links and membership | Compare role-only sufficiency and optional machine references without a complex custom protocol. |
| R1 | Enumerate/query snapshot, files, custom fields, links | Use metadata model; distinguish raw JSON from resource/entity API. |
| U1 | Edit description/roles; add/remove files/relations in uncommitted copies | Re-read/validate, unknown fields and untouched bytes survive; report rewrites/extra output. |
| V1 | Valid single/multi metadata; bad JSON, required field/type/version | Appropriate-version validation actually detects errors, beyond parsing. |
| V2 | Missing file, invalid path, dangling reference | Record actual coverage and explicit validation gaps. |
| P1 | Normal copy, truncated/modified target, source changed during capture | Accept only stable exact capture; inject mutation at a controlled boundary, never timing races; no failed output staged. |
| B1 | Absolute/traversal paths, file/ancestor symlinks, collisions | Safe capture rejects escape; observe tool defaults only against disposable canaries. |
| B2 | Spaces/Unicode/percent paths and metadata-name payload | Correct round trip, recovered relative path, no flattening/overwrite/wrong URI decoding. |
| O1 | Create/read/edit/validate with network denied | Verified runtime denial, cold tool caches, fixed local schemas/contexts; proxy variables alone insufficient. |
| O2 | Remote resource/schema/context references | No unintended fetch; show local-only controls without contacting live endpoints. |
| O3 | Read/validate effects, injected creation failure | Before/after tree comparison detects writes/HTML/ZIP; partial output cannot be published. |
| I1 | A create → B read/query/edit → A re-read | Preserve standard/custom semantics, IDs/links, paths and bytes; report read-only coverage when editing unavailable. |
| N1 | Fixed Nix build and installed-path execution | Resources present, valid installed references, no checkout dependence/runtime downloads. |

RO-Crate: explicitly resolve datePublished semantics for an internal snapshot
lifecycle event; do not invent public publication or substitute source mtime,
experiment/commit dates just to pass. Data Package: prove 2.0 schema compatibility
and ordinary file behavior; never declare scripts/logs as tables to fit an API.

Offline probes require an available verified network-denial mechanism and a
controlled network-attempt sentinel or equivalent evidence. If isolation cannot
be established, mark O1/O2 unverified. Build-time fixed downloads differ from
runtime network use. Fresh HOME/cache roots stay within each run; do not inspect
credentials or write global caches. Domain truth and selection completeness
remain agent/human review, outside structural validation.

## Decision and durable evidence

Gate on arbitrary files, uniform single/multi snapshots, required metadata,
existing-tool create/read/basic validation, safe exact capture and fixed Nix
offline operation. Record missing capabilities and remediation costs. If no
combination passes, retain the interim workflow and report shortcomings.

Among passing combinations compare metadata fit, reliable operations and
interoperability, maintenance/Nix/offline cost, then useful relation extensions.
Language is a tie-breaker only. Report standard, creator/editor, reader,
validator and capture mechanism separately. Label tested, upstream-declared,
specification-derived and project-policy claims distinctly.

Maintain current GAW memory as findings/next actions evolve. Archive selected
reproducibility inputs/adapters and consequential results using the interim
skill; preserve original project-relative tmp/ paths. Exclude caches/build
closures/redundant logs. Archive-only checkpoints remain separate from memory;
project parents record actual inspected capture context only.

After comparison, draft formal changes to bundled archive guidance for uniform
snapshots and the proven tools. Add a small helper only for a demonstrated
capture/path gap, not a metadata implementation. Keep optional tools outside
git-gaw runtime dependencies. Added resources require Cabal sdist/installed/Nix
path verification. Org-texmacs transplantation remains separate later work.
