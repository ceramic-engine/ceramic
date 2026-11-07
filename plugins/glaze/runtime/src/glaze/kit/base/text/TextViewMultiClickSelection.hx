// Ported from gpui-kit 0.8.1: crates/base/src/text/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Bounds;
import glaze.Point;

class TextViewMultiClickSelection {

    public final pos:Point;

    public final kind:TextViewMultiClickKind;

    public final lineBounds:Null<Bounds>;

    public inline function new(pos:Point, kind:TextViewMultiClickKind, lineBounds:Null<Bounds>) {
        this.pos = pos;
        this.kind = kind;
        this.lineBounds = lineBounds;
    }

    public function equals(other:Null<TextViewMultiClickSelection>):Bool {
        return other != null
            && pos.equals(other.pos)
            && kind == other.kind
            && (lineBounds == null ? other.lineBounds == null : lineBounds.equals(other.lineBounds));
    }

}
