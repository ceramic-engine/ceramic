// Ported from gpui-pre 0.3.10: src/element.rs, src/view.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Haxe counterpart of Rust's `impl IntoElement`: anything that can be
 * converted into an element. Accepts any `Element` (`div()`, `canvas()`...),
 * an `AnyElement`, a string (a `Text` element), a view (an entity whose model implements `Render`) or a
 * component (`RenderOnce`).
 *
 * A null source converts to a null `IntoElement` (no method is called on
 * it), and the `child()` / `children()` methods of every element skip null
 * children: `div().child(cond ? a : null)` is the same as not calling
 * `child()` at all (a convenience beyond Rust, where an `Option` goes through
 * `children` or `when_some`).
 */
@:forward(requestLayout, prepaint, paint, layoutAsRoot, prepaintAt, prepaintAsRoot, element)
abstract IntoElement(AnyElement) to AnyElement {

    inline function new(element:AnyElement) {
        this = element;
    }

    @:from static inline function fromAnyElement(element:AnyElement):IntoElement {
        return new IntoElement(element);
    }

    @:from static inline function fromElement(element:Element):IntoElement {
        return new IntoElement(element != null ? element.intoAnyElement() : null);
    }

    @:from static inline function fromView(view:Render):IntoElement {
        return new IntoElement(view != null ? ViewElement.forView(cast view).intoAnyElement() : null);
    }

    @:from static inline function fromAnyView(view:AnyView):IntoElement {
        return new IntoElement(view != null ? view.intoAnyElement() : null);
    }

    @:from static inline function fromEntity<T:Model & Render>(entity:Entity<T>):IntoElement {
        return new IntoElement(entity != null ? ViewElement.forView((entity : T)).intoAnyElement() : null);
    }

    /** Strings are text elements (Rust `impl IntoElement for &str / String / SharedString`) */
    @:from static inline function fromString(text:String):IntoElement {
        return new IntoElement(text != null ? new Text(null, text).intoAnyElement() : null);
    }

    /**
     * A `glaze.Component` placed with `X.component()` (see `Component`).
     * Declared before `fromComponent`: a `Component` is a `RenderOnce` too,
     * and the first matching conversion is the one used.
     */
    @:from static inline function fromGlazeComponent(component:Component):IntoElement {
        return new IntoElement(component != null ? component.__intoAnyElement() : null);
    }

    @:from static inline function fromComponent(component:RenderOnce):IntoElement {
        return new IntoElement(component != null ? renderOnceElement(component) : null);
    }

    /**
     * The element of a `RenderOnce`. A `glaze.Component` reached through a
     * value typed `RenderOnce` (a `ChildElement`, a `ListDelegateItem`...)
     * is placed as a component: its `.at(key)` is kept, and a persistent one
     * is found by its identity.
     */
    static function renderOnceElement(component:RenderOnce):AnyElement {
        if (Std.isOfType(component, Component)) {
            return (cast component : Component).__intoAnyElement();
        }
        return ViewElement.forComponent(component).intoAnyElement();
    }

    /**
     * Converts into a dynamically-typed `AnyElement`.
     */
    public inline function intoAnyElement():AnyElement {
        return this;
    }

}
