# Locked-nixpkgs archive comparison evidence

Non-authoritative historical evidence, not active instructions or adoption of a published default.

- Capture time: 2026-10-10T07:07:01Z.
- Project: git-agent-workflow; source-relative paths are rooted in the ordinary project worktree.
- Project commit: d6c675a (full object ID: d6c675a58d6a2eb2fcf815dacb743c325e607d35).
- Project state: HEAD at capture. Selected experiment files are ignored/untracked, not blobs from HEAD. Project tracked sources and index were unchanged.
- Selection: only reproducibility definitions, callers, official schema, four exact test fixtures, reviewed report and selected final raw results. Excludes Nix caches/store closures and generated candidate trees.
- Original sources: callers/report authored in this task; flake.lock copied byte-exact from project root; schema captured from the official DP2 endpoint; PLAN.md copied from the existing preparation snapshot; three probe fixtures copied from org-texmacs archive/2026-10-06T14-50-30Z--b09b451/files/tmp/. Source probes were not executed or changed.
- Test context: locked nixpkgs 55ba7f49ef2962b42cbd126522b7df5f95037679, existing packages only, x86_64-linux. Final ordinary Nix derivation verified ENETUNREACH and completed probes. Report separates adapted capability, tool failures, unverified cases and final implementation work.
- Fidelity: pre/post source state and byte checks, per-file size/SHA-256, unchanged captured HEAD. The GAW checkpoint is the commit containing this manifest, with captured HEAD as its sole additional project parent; this records inspected capture context, not original authorship or tracked test blobs.

## Selected artifacts

| Source path | Archive path | Source state | Bytes | SHA-256 | Evidence role |
| --- | --- | --- | ---: | --- | --- |
| tmp/archive-comparison/run-20261010/report.md | files/tmp/archive-comparison/run-20261010/report.md | untracked, ignored | 10409 | d52c3dfd4789054707b4ce6eefb39c2149277b184b0a3f8b079d3636bb9dfb0e | Reviewed test-based recommendation, limitations and implementation boundary. |
| tmp/archive-comparison/run-20261010/environment.nix | files/tmp/archive-comparison/run-20261010/environment.nix | untracked, ignored | 401 | 0d8d880a88b948b9948faf5791066b0e7b9ff3103f127f599e35c64edde46365 | Existing-nixpkgs tool environments, fixed by captured lock input. |
| tmp/archive-comparison/run-20261010/tests.nix | files/tmp/archive-comparison/run-20261010/tests.nix | untracked, ignored | 426 | f1ebc37c1b990617b11b72ae6a1567bbdb917afe56944786d0e383aee9274159 | Ordinary Nix sandbox runner with network-denial assertion and timeouts. |
| tmp/archive-comparison/run-20261010/flake.lock | files/tmp/archive-comparison/run-20261010/flake.lock | untracked, ignored | 1752 | 4cc938f94116ca90ae2b887bdd71cdc0298a13a18e82b333d24623c75a65c6a5 | Byte-exact copy of project dependency lock used by the portable test environment. |
| tmp/archive-comparison/run-20261010/probe.py | files/tmp/archive-comparison/run-20261010/probe.py | untracked, ignored | 13241 | a63c5b93e08df0146d9e3aa8b73748ca63d75972accbd8fb1c20acaf6abaa656 | Python API caller, DP2 export adaptation and capture/boundary experiments. |
| tmp/archive-comparison/run-20261010/probe.R | files/tmp/archive-comparison/run-20261010/probe.R | untracked, ignored | 5679 | 2b80f2f400d7e2ebfb6b853287a775763a578c12c6a4d54fcd0a6a1e01a159f7 | Independent R metadata calls and observed RO-Crate validation coverage. |
| tmp/archive-comparison/run-20261010/datapackage-2.0.schema.json | files/tmp/archive-comparison/run-20261010/datapackage-2.0.schema.json | untracked, ignored | 158696 | a9ef0fc168b3402ae7aa7d22bbcb798e0db6b639e7ee15ff4aa177463cea7112 | Captured official DP2 schema with independently recorded SHA-256. |
| tmp/archive-comparison/run-20261010/results/python-results.json | files/tmp/archive-comparison/run-20261010/results/python-results.json | untracked, ignored | 11000 | 24a0a79758090ea52709906087171e2bfb2fedc5e160bbd566c3b3d26f89c077 | Raw complete final Python outcomes, including expected negative cases. |
| tmp/archive-comparison/run-20261010/results/r-results.json | files/tmp/archive-comparison/run-20261010/results/r-results.json | untracked, ignored | 4301 | 57c71bf8920caa64ed718026ae5de29cf18e1e3688fc0fd52f15ff5f3a0ba5c9 | Raw complete final R outcomes, including validator false negatives. |
| tmp/archive-comparison/run-20261010/results/r-stdout.txt | files/tmp/archive-comparison/run-20261010/results/r-stdout.txt | untracked, ignored | 3694 | 08d83c956f241b7deef1369a1a2c6c80edd66a77b51af86d2022f47c5bf4a378 | Selected final R operation output. |
| tmp/archive-comparison/run-20261010/results/r-stderr.txt | files/tmp/archive-comparison/run-20261010/results/r-stderr.txt | untracked, ignored | 757 | a61bddeaa41a1b654bee0ef2f34399db169f0aa5f7dfa7f9d3823aad83bbdbc5 | Selected final R tool diagnostics. |
| tmp/archive-comparison/run-20261010/inputs/PLAN.md | files/tmp/archive-comparison/run-20261010/inputs/PLAN.md | untracked, ignored | 45358 | 2ec52a1e64ca26c4dce7f209b014944e121d571530a7a5d8ea923f3e42a24ec6 | Historical planning-document test input copied from preparation archive. |
| tmp/archive-comparison/run-20261010/inputs/tmp/doc-01-file-url-probe.el | files/tmp/archive-comparison/run-20261010/inputs/tmp/doc-01-file-url-probe.el | untracked, ignored | 617 | 1e393407888126af3450ecb5dfd1bd56f5c3742e3324a1a0c52b86688e2f2807 | Runner bytes copied from authorized org-texmacs archive; not executed. |
| tmp/archive-comparison/run-20261010/inputs/tmp/doc-01-file-url-probe.scm | files/tmp/archive-comparison/run-20261010/inputs/tmp/doc-01-file-url-probe.scm | untracked, ignored | 1177 | f6ff41abf891bec94d6af12f5014f93658a728928f5be877ad79b2b8f201a058 | Native query bytes copied from authorized org-texmacs archive; not executed. |
| tmp/archive-comparison/run-20261010/inputs/tmp/doc-01-file-url-probe.txt | files/tmp/archive-comparison/run-20261010/inputs/tmp/doc-01-file-url-probe.txt | untracked, ignored | 1040 | 96210febfa64288b90128f3db1813096094b7eb1e6a748cd4eb58431a1d2bfe0 | Observed output bytes copied from authorized org-texmacs archive. |
