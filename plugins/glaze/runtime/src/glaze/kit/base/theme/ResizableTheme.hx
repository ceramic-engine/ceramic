// Ported from gpui-kit 0.8.1: crates/base/src/theme.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.theme;

import gpui.Hsla;

/**
 * Global visual defaults used by resizable panel handles.
 *
 * `null` means *unset*, not invisible: a handle with nothing projected onto
 * it resolves from the active `SemanticThemeTokens` (`border` at rest,
 * `ring` while dragging).
 */
class ResizableTheme {

    public var handle:Null<Hsla> = null;

    public var activeHandle:Null<Hsla> = null;

    public function new() {}

}
