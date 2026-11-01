// Ported from gpui-kit 0.8.1: crates/component/src/diff/parser.rs (`DiffParseOptions`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

/**
 * Relaxations for `DiffFile.parseWith`. Every relaxation is off by default,
 * which parses exactly as `DiffFile.parse` does.
 */
class DiffParseOptions {

    final _truncatedHunks:Bool;

    public function new(truncatedHunks:Bool = false) {
        _truncatedHunks = truncatedHunks;
    }

    /**
     * Accept hunks that end before their declared line counts, as in a patch
     * cut at a size limit, and count each from the lines present. Declared
     * counts still bound a hunk, so a line beyond them remains an error.
     */
    public function truncatedHunks(truncatedHunks:Bool):DiffParseOptions {
        return new DiffParseOptions(truncatedHunks);
    }

    public function hasTruncatedHunks():Bool {
        return _truncatedHunks;
    }

}
