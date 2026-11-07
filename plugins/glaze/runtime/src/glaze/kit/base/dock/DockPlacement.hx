// Ported from gpui-kit 0.8.1: crates/base/src/dock/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.Axis;

/**
 * Placement of a `Dock` relative to the center area.
 *
 * This mirrors a persisted, on-disk schema shipped to end users: the serde
 * tags (`serdeName`) are frozen and must not change.
 */
enum abstract DockPlacement(Int) to Int {
    var Center;
    var Left;
    var Bottom;
    var Right;

    public function axis():Axis {
        return switch (cast this : DockPlacement) {
            case Left | Right | Center: Axis.Horizontal;
            case Bottom: Axis.Vertical;
        }
    }

    public inline function isLeft():Bool {
        return (cast this : DockPlacement) == Left;
    }

    public inline function isBottom():Bool {
        return (cast this : DockPlacement) == Bottom;
    }

    public inline function isRight():Bool {
        return (cast this : DockPlacement) == Right;
    }

    /**
     * The `#[serde(rename = ...)]` tag.
     */
    public function serdeName():String {
        return switch (cast this : DockPlacement) {
            case Center: 'center';
            case Left: 'left';
            case Bottom: 'bottom';
            case Right: 'right';
        }
    }

    /**
     * Reads a serde tag; `null` for an unknown one.
     */
    public static function fromSerdeName(name:String):Null<DockPlacement> {
        return switch name {
            case 'center': Center;
            case 'left': Left;
            case 'bottom': Bottom;
            case 'right': Right;
            case _: null;
        }
    }

    /**
     * Rust `{:?}`.
     */
    public function toString():String {
        return switch (cast this : DockPlacement) {
            case Center: 'Center';
            case Left: 'Left';
            case Bottom: 'Bottom';
            case Right: 'Right';
        }
    }
}
