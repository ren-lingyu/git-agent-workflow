# Fixed v0.4.0 oracle

`v0.4.0.tar.gz` is a `gzip -n` archive of Git tree
`df2d1d36c2aa690bbcb01baa191fdfcbbc58316c`. Its SHA-256 is
`fed2f16650ac286ab794fdb09b0ac0a1b185dbf95a4ce1fa59832784339d3620`.

The oracle derivation checks this hash before building the Common Lisp
executable. Differential tests receive its executable path explicitly; they
do not build an oracle from the changing project worktree.
