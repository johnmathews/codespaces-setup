# Gate-file fixtures — the barrier predicate

Cases for the `/done` gate barrier (`commands/done.md` §`8a` item 1), exercised by
`check_board.py --selftest`. The barrier is the branch's only enforcement of its
headline rule and it has broken three times, twice fail-open, so it gets committed
cases rather than a manual demonstration.

Naming is the expectation: `clear_*` must clear the barrier, `block_*` must block
it. Every file is a plausible gate file — the failures this guards against all look
like ordinary, honestly-written ones.
