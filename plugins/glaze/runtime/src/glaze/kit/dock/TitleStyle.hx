// Ported from gpui-kit 0.8.1: crates/component/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dock;

import glaze.Hsla;

/**
 * Colors for a panel's title.
 */
class TitleStyle {

    public final background:Hsla;

    public final foreground:Hsla;

    public function new(background:Hsla, foreground:Hsla) {
        this.background = background;
        this.foreground = foreground;
    }

    public function equals(other:TitleStyle):Bool {
        return other != null && background.equals(other.background) && foreground.equals(other.foreground);
    }

}
