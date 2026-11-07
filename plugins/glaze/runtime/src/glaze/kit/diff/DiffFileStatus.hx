// Ported from gpui-kit 0.8.1: crates/component/src/diff/document.rs (`DiffFileStatus`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.diff;

/**
 * How a file changed, in Git's status terms.
 */
enum abstract DiffFileStatus(Int) {

    var Added;

    var Deleted;

    var Modified;

    var Renamed;

    var Copied;

    /** A whole file shown for reference, from `DiffFile.unchanged`. */
    var Unchanged;

    /** A working file with conflict markers, from `DiffFile.parseConflicts`. */
    var Conflicted;

}
