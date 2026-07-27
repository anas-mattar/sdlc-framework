# Stub-marker fixture

Fed to both check-stubs implementations' `--scan` / `-Scan` mode, which reports
which LINES of a file count as unimplemented markers. The two must agree.

This file is `.md` and lives under `tests/`, so neither implementation would ever
count it during a normal run -- which is the point: it can carry every awkward
line without changing this repository's own stub count. `--scan` bypasses the
file filter (that half of the rule is covered by `stub-paths.txt`).

Lines that MUST count:

    // TODO: implement the retry window
    /* FIXME */
    # HACK around the driver bug
    // XXX
    throw new NotImplementedException();
    raise NotImplementedError()
    throw UnimplementedError();
    unimplemented!()
    todo!()
    // TODO: everything approved-stub:
    // TODO: later approved-stub:
    // FIXME approved-stub:

Lines that MUST NOT count -- the exemption, used properly:

    // TODO: pagination approved-stub: spec.md 4.2 deferred to phase 3
    // FIXME approved-stub: tracked as issue 114
    # HACK approved-stub: upstream driver bug, see gotchas.md

Lines that MUST NOT count -- lower case is not a marker. `Select-String` and
`-notmatch` are case-insensitive by DEFAULT, so these three counted on Windows
and nowhere else until the two calls were made case-sensitive:

    // todo: rename this
    // fixme
    // hack

A word that merely CONTAINS a marker does count, in both implementations, because
both search for the marker as a substring rather than as a whole word. That is a
deliberate over-count -- it is a ratchet, and a false positive costs one
`approved-stub:` line while a false negative costs the whole control. It is
recorded here so the behaviour is a decision rather than a surprise:

    const TODOS = 3;
