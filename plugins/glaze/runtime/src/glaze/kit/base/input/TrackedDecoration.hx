// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/decorations.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;

/**
 * Both text styles and geometric decorations share normalization and edit affinity.
 */
interface TrackedDecoration {

    function getRange():Range;

    function setRange(range:Range):Void;

}
