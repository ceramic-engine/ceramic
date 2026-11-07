// Ported from gpui-kit 0.8.1: crates/component/src/searchable_list/change.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.searchablelist;

import glaze.kit.base.IndexPath;

/**
 * A single, atomic selection change proposed by the mode-strategy for a user interaction.
 *
 * Passed as an array to `SearchableListDelegate.onWillChange`, giving the delegate
 * a description of what the default strategy intends to do. The delegate may apply all,
 * some, or none of the changes by mutating the `selection` argument directly.
 */
enum SearchableListChange {
    /** Select the item at the given index path. */
    Select(index:IndexPath);
    /** Deselect the item at the given index path. */
    Deselect(index:IndexPath);
}
