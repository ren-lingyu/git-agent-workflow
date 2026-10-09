# Project skills: organization, references and lifecycle

Apply the main skill's snapshot, reference, provenance and authorization
constraints. Skills describe reusable work; memory describes current project
state. Locate declared skill paths using role metadata or explicit guidance,
not assumed directory names or a fixed relation between Git worktrees.

## Decide whether a skill is appropriate

Reuse an existing suitable skill before creating another. A stable recurring
procedure, non-obvious constraint or useful routing/resource boundary can
justify a project skill. A one-time task, current commit, release status,
temporary TODO or conversation chronology normally belongs in memory instead.
Modify a skill when a reusable workflow changes, not merely because the
project's current state changed.

Use the target environment's available skill-creation tools when relevant;
identify required external dependencies rather than assuming every agent has
the same tools. Do not add scripts, templates or automatic self-maintenance
without a concrete authorized need.

## Choose and preserve a namespace

Project-defined skills use a stable project prefix, such as
`<project>-<purpose>`, conforming to the host's naming rules. The repository
name can be a starting point; a repository rename need not change its skill
namespace. Keep the skill directory name and metadata name consistent.

Bundled and third-party skills retain their existing identities; do not
rename them by automatically prepending the current project's prefix. Keep
discovery metadata focused on the actual capability and triggers rather than
unrelated tasks or exhaustive descriptions.

## Make references resolve in the right context

Distinguish these cases explicitly:

- **Bundled resources:** locate within the current skill root and distribute
  them with the skill. A reference must not silently depend on an internal
  resource outside the installed skill directory.
- **Other skills:** refer by explicit skill identity. Do not rely on those
  skills being adjacent directories or installed at the same absolute path.
- **GAW workspace data:** name the relevant workspace root and path so the
  reference can be interpreted in that snapshot, for example a
  workspace-root-relative `memory/project.md`. Such data is not necessarily a
  bundled skill resource.
- **External tools or skills:** identify their identity, prerequisites and
  availability assumptions. Do not claim the current GAW tree includes them
  or that their availability grants execution permission.

A project convention using a relative path such as `../../memory/project.md`
can be valid when its workspace root and layout are explicit. Do not confuse
that data reference with an internal bundled-resource link, or break a valid
convention simply to force all references into one category.

Keep substantial workflow detail in resources routed from the main skill
when that reduces irrelevant context. Verify links after installation or
distribution, not only against the development checkout.

## Evolve the current snapshot coherently

When changing a skill, inspect its callers and references, preserve unrelated
instructions and distinguish required constraints from recommendations and
project-specific examples. Check that it remains reusable and that current
facts have not displaced the workflow.

For a rename, replacement or retirement, update the directory/metadata and
affected references, routing and explanations in the new workspace snapshot.
Retain a skill only while its purpose remains useful; explain a replacement
when that matters to recovery. Do not introduce a separate historical skill
identifier or rewrite old checkpoints: each earlier complete snapshot retains
its own names and conventions.

Validate metadata, resource completeness and relevant behavioral scenarios.
Prefer observable workflow decisions and meaningful resource checks to tests
that merely require a particular sentence or heading. Inspect the full index,
stage explicit authorized paths and checkpoint through the main skill's
normal loop. Changes to ordinary project skill files or external installs
still require their own authorization.
