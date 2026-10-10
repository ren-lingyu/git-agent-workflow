# Locked-nixpkgs archive candidate comparison

## Outcome

For the user's constraint of existing locked-nixpkgs tools only, **Data Package
2.0 is the viable implementation candidate**, using Python frictionless for
metadata models/read/file access and nixpkgs jsonschema for actual 2.0 structure
validation. It requires a small export adapter and a separate safe local capture
policy. This is a tested capability recommendation, not adoption of a published
default or a claim that Frictionless natively implements all of 2.0.

RO-Crate cannot meet the intended validation/independent-implementation gate in
this locked tool set: rocrateR can create/edit graph metadata, but its validator
misses required-field, local-file and reference errors, and the lock has no
independent RO-Crate validator or other full creator. Keep the interim archive
workflow until the formal integration is reviewed. Do not introduce new
upstream packages or change locks to evade the user's restriction.

## Reproduction and versions

- System: x86_64-linux; locked nixpkgs `55ba7f49ef2962b42cbd126522b7df5f95037679`.
- Python 3.14.7: frictionless 5.19.0, jsonschema 4.26.0.
- R 4.6.1: frictionless 1.2.1, rocrateR 0.1.0.
- Environment definitions are `environment.nix` and `tests.nix` beside this
  report; `flake.lock` supplies the same fixed source without a checkout path.
- Run: `timeout 120s nix build --no-link --json --option sandbox true --option sandbox-fallback false -f tests.nix` from this run's directory. Both environment builds and final comparison exited zero. Runtime probes each have 30-second limits.
- Final tested derivation: `/nix/store/q2049xh09xrflsi49rjxabhq3ic6x784-gaw-archive-nixpkgs-comparison.drv`.
  Result: `/nix/store/41pjcgr18nlhgmnarcc1cjilvlfiki46-gaw-archive-nixpkgs-comparison`.
  These paths identify raw experimental evidence, not durable semantic locators.
  Changing the environment definition to use captured lock inputs was checked
  offline to produce this exact same derivation; no new test execution is implied.
- Ordinary Nix build sandbox enabled, fallback disabled. The probe's UDP connect
  to a documentation-range address returned ENETUNREACH before candidate tests.
  Local creation/read/edit/validation succeeded without network. This is actual
  network denial, not an inference from proxy settings or warmed tool caches.
- Dependency closure sizes from `nix path-info -S`: Python 330,137,104 bytes;
  R wrapper 2,235,450,664 bytes. These are full transitive closure sizes, with
  sharing possible, not incremental download sizes.

All executed candidate libraries came from locked nixpkgs. Preliminary public
PyPI metadata queries occurred before the user narrowed the scope; no package
from those queries was installed or used. The one external normative input is
the official Data Package 2.0 schema, captured from
`https://datapackage.org/profiles/2.0/datapackage.json`, SHA-256
`a9ef0fc168b3402ae7aa7d22bbcb798e0db6b639e7ee15ff4aa177463cea7112`.
It is a pinned standards resource, not an extra tool. Runtime validation uses
its local copy and nixpkgs jsonschema; remote retrieval is unnecessary.

## Samples and observed behavior

Input bytes are copied from org-texmacs's existing File URL probe archive
`archive/2026-10-06T14-50-30Z--b09b451/files/tmp/` (617-byte runner,
1177-byte native query and 1040-byte output). They were not executed as probes
against org-texmacs. The single-file historical planning fixture is PLAN.md
from this project's preparation snapshot, 45,358 bytes. Originals remain
untouched. Generated snapshots preserve source-relative paths beneath files/.

| Behavior | Python frictionless + jsonschema | R frictionless | rocrateR |
| --- | --- | --- | --- |
| Single/multi metadata creation | Both pass official 2.0 schema after adaptation | Can create/copy an ordinary file, but writer flattens paths | Both created through normal graph API with explicit 1.3 context |
| Native standard version | Native export adds legacy file/text types invalid in DP2 | `$schema` retained, not version-aware validation | Default context is 1.2; parameter allows 1.3 declaration, not proof of 1.3 conformance |
| Metadata/file reads | Resources/roles/extensions and original bytes recovered | Resources/paths/extensions readable; non-tabular content API refused script | File entities, descriptions, custom values and links readable |
| Edits | Fields/resource add-remove/relation edits round trip; adapter needed on every export | Python → R → Python works but changes paths and custom value types | Description/link/custom values survive own write/read |
| Validation | Official schema detects missing resources, wrong title, `$schema` and contributor-roles types; loader detects missing files | `check_package` accepts missing resources, wrong title/schema types and nonexistent files | `strict=TRUE` accepts missing date/name, numeric date, missing local file, dangling reference and unknown context |
| Capture fidelity | All selected original bytes preserved | Copied bytes preserved despite path flattening | Copied single/multi bytes preserved |
| Local offline operations | Demonstrated in denied-network build | Demonstrated metadata read/write | Demonstrated create/read/edit/own validation |

The raw cases are in `results/python-results.json` and `results/r-results.json`.
Tool messages are preserved in the accompanying R stdout/stderr files. The
expected broken-JSON case is recorded as an error; this is rejection evidence,
not a failed overall test run.

### Required adaptation and coverage boundaries

Frictionless's normal API exports `type: file` (and on re-read, `type: text`).
The official DP2 schema allows `type: table` when type is present, so ordinary
file resources must omit those legacy values. A small adapter removes only
file/text type fields at export, then validates the complete descriptor using
the local official schema. It must run after every edit/export. This does not
declare scripts/logs as tables or reimplement a schema parser. Frictionless's
own validation misses invalid DP2 `$schema` and contributor `roles` types;
the separate validator is necessary. Merely setting `$schema` is insufficient.

R writing changes `files/tmp/...` into basenames. It also turns custom
`limits: ["not a new experiment"]` into a string. Thus R supplies independent
metadata-read evidence, but its writer is unsuitable for preserving this
workflow's structure and all extension types. Content APIs demand tabular
profiles; no script was mislabeled as a table. An independent write round trip
was performed and its failures retained, rather than claimed successful.

Absolute/parent-traversal paths are rejected by Frictionless and the DP2 schema.
A symlink to a disposable canary outside the snapshot is followed by default.
The proposed project capture guard rejects both traversal/absolute selections
and symlink ancestors, and accepts a safe relative file. A remote-resource
descriptor makes the Frictionless HTTPS loader attempt DNS/network access,
which fails in the sandbox; a local-only workflow must reject it before loading.
Do not describe Frictionless as inherently confined to a snapshot root.

File names containing spaces, Unicode and percent characters round trip byte
for byte through the Python file API, including nested same basenames and a
payload named datapackage.json. Snapshot read/validation produced no writes
in the measured Python snapshot tree. Normal copy, truncation, target edits
and a controlled source mutation were detected by transient byte comparisons.
These are capture-policy experiments, not guarantees supplied by metadata
validators or a production capture helper.

Custom Data Package relation references are not validated by either schema or
Frictionless. Use descriptive roles when sufficient; do not invent a universal
relationship protocol. RO-Crate's graph API is useful, but an explicit 1.3
context alone plus the observed same-library checker does not establish
standard validity. No JSON-LD expansion, independent 1.3 validation or resolved
datePublished policy was demonstrated. The fixed date in these fixtures is
test metadata, not an invented historical/public publication claim.

Single/multi DP metadata size was 706/1534 bytes (the second independent single
snapshot 713 bytes). These include test extension fields and are not normative
minimal-schema requirements. No HTML, ZIP or binary container was generated.

## Decision and proposed implementation boundary

1. Advance DP2 with Python frictionless + jsonschema and a local pinned official
   schema as the preferred combination. R remains an independent reader for
   comparison, not a production dependency. Keep role descriptions simple.
2. A small proposed export adapter removes the proven legacy file/text fields
   and performs real DP2 validation after all writes. A safe local capture
   boundary must reject remote/traversing/symlink selections, compare pre/post
   source bytes, avoid overwriting snapshots and prevent partial publication.
3. Before adopting this as a published default, validate a reviewed production
   workflow/helper rather than equating the experimental guards with an
   implementation. Distribution must include the pinned schema and needed
   resources; tools remain optional archive dependencies outside git-gaw's
   unconditional runtime closure.
4. No candidate meets every original comparison item under the available
   tools: independent RO1.3 validation/interoperation is unavailable. Therefore
   the interim MANIFEST.md/files default remains in effect during this task.

Unverified: cold runtime behavior beyond ordinary fresh Nix sandbox builds,
read/validation side effects for all R operations, RO-Crate special-path/IRI
expansion behavior, tool-interrupted creation recovery and production staging
integration. These omissions do not erase the observed validator/path/type
failures and must not be reported as passed. No bundled skill, protocol,
ordinary project commit, lockfile or source-project archive was modified.

Two earlier experimental runs stopped: native DP2 mismatch at positive
creation, then R report serialization of S3 validation objects. The final
caller strips S3 wrappers only when reporting results; candidate library
behavior is unchanged. Final derivation success demonstrates the completed
probes, not success of every candidate capability.
