// Ported from gpui-kit 0.8.1: crates/base/src/text/stream_fade.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Range;

/** Rust `(TextLeafKey, FadeRanges)`. */
class LeafFades {
    public final key:TextLeafKey;
    public final fades:Array<RangedFade>;

    public inline function new(key:TextLeafKey, fades:Array<RangedFade>) {
        this.key = key;
        this.fades = fades;
    }
}

/**
 * One frame's fade factors, resolved once per render so node rendering only
 * looks up its leaf. Each range paints with its `fadeOut` factor this frame:
 * `1.0` transparent, `0.0` opaque (Rust `FadeRanges`).
 */
class StreamFadeFrame {

    final leaves:Array<LeafFades>;

    public function new(?leaves:Array<LeafFades>) {
        this.leaves = leaves != null ? leaves : [];
    }

    public function fades(key:TextLeafKey):Null<Array<RangedFade>> {
        for (leaf in leaves) {
            if (leaf.key.equals(key)) return leaf.fades;
        }
        return null;
    }

}
