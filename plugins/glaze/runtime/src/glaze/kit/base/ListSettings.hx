// Ported from gpui-kit 0.8.1: crates/base/src/list_settings.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

/**
 * Global settings for list presentation behavior.
 */
class ListSettings {

    /** Whether list items use the active highlight style by default. */
    public var activeHighlight:Bool = true;

    public function new() {}

    public function copy():ListSettings {
        final settings = new ListSettings();
        settings.activeHighlight = activeHighlight;
        return settings;
    }

}
