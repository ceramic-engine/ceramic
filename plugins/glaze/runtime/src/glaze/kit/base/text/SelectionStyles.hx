// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

/**
 * How many styles a selection takes in, which decides whether
 * `SelectionFormat.SourceAcrossStyles` copies the rendered text or the
 * source.
 */
enum abstract SelectionStyles(Int) {

    var None = 0;

    var One = 1;

    var Mixed = 2;

    /**
     * Combine two separately selected parts. They are two styles even when
     * their marks match, because they sit in different blocks or cells.
     */
    public inline function merge(other:SelectionStyles):SelectionStyles {
        return if (abstract == None) other else if (other == None) abstract else Mixed;
    }

}
