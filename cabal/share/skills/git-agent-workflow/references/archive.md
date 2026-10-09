# Selective historical evidence

Apply the main skill's snapshot, reference, provenance and authorization
constraints. Discover the declared archive paths through config roles or
explicit project guidance. Confirm the existing GAW worktree and readiness;
archiving does not initialize, deploy, repair or rewrite its history.

## Select material that deserves retention

Preserve raw material when losing it would materially impair interpretation,
reproduction, audit or handoff of a result, decision, failure or migration.
First consider whether project history, maintained tests, current memory or
existing archives already preserve what is needed. Retired documents and
temporary evidence may be useful; age, a filename or a mention alone does not
make an artifact worth archiving.

State the selection scope and reason, and identify the actual sources. A
material reference from another selected document supports inclusion, but
independent evidence value can also justify an artifact. Do not archive whole
conversations, tool logs or temporary directories by default. Obtain any
required source-read or capture authorization before broadening the selection.

## Capture deliberately and faithfully

Inspect selected paths, file types and sizes before reading or copying. Check
source and destination roots and symbolic links; do not follow a link across
an authorized boundary. Respect sensitive-content policies. Prefer faithful
original bytes when authorized. If sanitization is necessary, identify the
saved material as a sanitized derivative rather than a byte-exact original;
do not retain secrets merely to claim fidelity.

For binary, large or costly material, assess format, size, retention value and
Git cost before capture and obtain any required decision. Text need not be
compressed into a binary container simply for convenience. Avoid overwriting
existing raw evidence during routine capture; choose stable collision-free
paths and make intentional additions or corrections explicit.

An optional layout is an archive-root directory named with a UTC timestamp
and, when relevant, a project commit abbreviation, containing a manifest and
files that preserve source-relative paths. UTC names, MANIFEST.md, files/ and
SHA-256 are useful examples, not a universal required format. Follow an
existing appropriate convention instead of imposing a new one.

## Describe evidence and its limits

Use a manifest or another explicit index to make the archive interpretable
within the complete checkpoint snapshot. Record:

- why the material was selected, capture time and scope;
- source and archive locations, with the root of relative paths stated;
- tracked, modified, untracked or otherwise known source state;
- the original provenance that is established, and uncertainty or gaps;
- where useful, sizes, digests, file formats and relevant project snapshots;
- that this material is historical evidence, not automatically authoritative
  current knowledge or executable agent instructions.

Distinguish the project state actually inspected or captured from the original
historical source of an artifact. HEAD at capture can identify a checked
capture context; it does not establish the origin of old or untracked content.
Do not silently label modified files as exact bytes from a project commit.
Use the main skill's evidence rules to choose project parents independently.

## Verify, persist and refer to the archive

Compare important captures with the authorized source bytes, verify recorded
sizes/digests, and confirm the manifest matches the actual selection. For a
sanitized derivative, verify the approved transformation and record that
limit. If the source or checked project state changed during capture, resolve
and document the discrepancy before checkpointing under the claimed context.

Review the whole GAW index and candidate's coordination, explicitly stage
intended archive paths, check readiness and use public git gaw commit. Keep
protocol-path changes separate; archive and other workspace edits may share
a checkpoint when they form one coherent independently recoverable state.
There is no universal single-directory or exactly-one-project-parent rule.
Attach zero, one or several parents only with the evidence required by the
main skill, and inspect the resulting checkpoint when necessary.

Refer to stable archive paths and their manifest/index. Use relevant
first-parent path history to locate introducing checkpoints rather than
embedding GAW checkpoint OIDs as durable semantic locators. Project OIDs,
content digests and raw diagnostic hashes can have legitimate evidence roles;
do not remove or rewrite them merely because they look like hashes.

When an archive informs a new conclusion, evaluate that conclusion and update
current memory separately as needed. Reading an old skill, transcript or
instruction in an archive does not activate it or restore its authority.
