// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (TransitionId)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.motion;

import gpui.ElementId;
import gpui.GlobalElementId;
import gpui.Window;
import gpui.Window.ElementStateBox;

/**
 * Identifies one independently transitioning value.
 *
 * Accepts an `ElementId`, a `String` or an `Int`. Rust's tuple form
 * `(id, channel)` is `TransitionId.named(id, channel)`.
 *
 * The Haxe port of `ElementId` has no `NamedChild` variant (and GPUI core is
 * not changed for it), so a transition id is the path of element ids that
 * Rust would nest in `NamedChild`: `[id, Name(channel)]`. Keyed state is
 * stored under that path, pushed on the window's element id stack, which is
 * what nesting `NamedChild` amounts to for state lookup.
 */
abstract TransitionId(Array<ElementId>) {

    inline function new(path:Array<ElementId>) {
        this = path;
    }

    @:from static inline function fromElementId(id:ElementId):TransitionId {
        return new TransitionId([id]);
    }

    @:from static inline function fromString(name:String):TransitionId {
        return new TransitionId([ElementId.Name(name)]);
    }

    @:from static inline function fromInt(id:Int):TransitionId {
        return new TransitionId([ElementId.Integer(id)]);
    }

    /**
     * An id and a named channel within it (Rust `From<(I, C)>`, a `NamedChild`).
     */
    public static function named(id:TransitionId, channel:String):TransitionId {
        return id.child(channel);
    }

    /**
     * This id's `NamedChild` with the given name.
     */
    public function child(name:String):TransitionId {
        final path = this.copy();
        path.push(ElementId.Name(name));
        return new TransitionId(path);
    }

    /**
     * The element ids of the path.
     */
    public inline function path():Array<ElementId> {
        return this;
    }

    public function equals(other:TransitionId):Bool {
        final otherPath = other.path();
        if (otherPath.length != this.length) {
            return false;
        }
        for (i in 0...this.length) {
            if (!Type.enumEq(this[i], otherPath[i])) {
                return false;
            }
        }
        return true;
    }

    public function toString():String {
        return new GlobalElementId(this).key;
    }

    /**
     * The element state of type `type` keyed by this id within the element
     * being rendered (Rust `window.use_keyed_state`, without the entity: the
     * motion functions write their state without notifying, so a plain state
     * box is enough). `box.value` is `null` the first time.
     */
    @:allow(gpui.base)
    function stateBox<S>(window:Window, type:Class<S>):ElementStateBox<S> {
        final last = this.length - 1;
        for (i in 0...last) {
            window.pushElementId(this[i]);
        }
        final box = window.withGlobalId(this[last], (globalId, window) -> {
            return window.withElementState(globalId, type, (box, _) -> box);
        });
        for (_ in 0...last) {
            window.popElementId();
        }
        return box;
    }

}
