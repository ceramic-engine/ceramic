// Ported from gpui-kit 0.8.1: crates/base/src/theme.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.theme;

/**
 * Whether the Base layer paints for a light or a dark theme.
 */
enum abstract ThemeAppearance(Int) {

    var Light = 0;

    var Dark = 1;

}
