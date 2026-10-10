# Archive workflow preparation and isolated test design snapshot

Non-authoritative historical evidence; not active instructions or proof that candidate tools passed tests.

- Capture time: 2026-10-10T05:24:49Z.
- Project: git-agent-workflow; source root for relative paths: the ordinary project worktree.
- Project commit: d6c675a (full object ID: d6c675a58d6a2eb2fcf815dacb743c325e607d35).
- Project state: HEAD at capture; ordinary tracked worktree/index clean at preparation. Both selected files are untracked and ignored, not blobs from this HEAD.
- Selection: only updated root PLAN.md and the complete isolated test design; preserve requirements and reproducible next steps that ordinary Git history does not retain.
- Original provenance: PLAN.md is user-maintained; the test design was authored by the agent in this task. Their capture context does not establish prior document authorship or a tested implementation.
- Validation: source type/size/path checks; pre/post file identity/state checks; byte-for-byte comparison and SHA-256. No candidate tool, build, dependency download or network probe was executed.
- The GAW checkpoint is the commit containing this manifest; its sole additional project parent records the captured HEAD context.

## Selected artifacts

| Source path | Archive path | Source state | Bytes | SHA-256 | Evidence role |
| --- | --- | --- | ---: | --- | --- |
| PLAN.md | files/PLAN.md | untracked, ignored | 45358 | 2ec52a1e64ca26c4dce7f209b014944e121d571530a7a5d8ea923f3e42a24ec6 | User-updated archive requirements, including uniform single-file and multi-file snapshots; ignored input absent from ordinary project history. |
| tmp/archive-comparison/test-plan.md | files/tmp/archive-comparison/test-plan.md | untracked, ignored | 9106 | 3732230d47142188a93ff58f8d2b5c8912fac7a66dfc0d84fe5a90b2aefebcc0 | Isolated comparison test design covering candidate versions, fixtures, negative tests, boundaries and decision gates; not a test result. |
