// Ported from gpui-pre 0.3.10: src/element.rs, src/view.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Haxe counterpart of Rust's `impl IntoElement`: anything that can be
 * converted into an element. Accepts any `Element` (`div()`, `canvas()`...),
 * an `AnyElement`, a string (a `Text` element), a view (an entity whose model implements `Render`) or a
 * component (`RenderOnce`).
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
        return new IntoElement(element.intoAnyElement());
    }

    @:from static inline function fromView(view:Render):IntoElement {
        return new IntoElement(ViewElement.forView(cast view).intoAnyElement());
    }

    @:from static inline function fromAnyView(view:AnyView):IntoElement {
        return new IntoElement(view.intoAnyElement());
    }

    @:from static inline function fromEntity<T:Model & Render>(entity:Entity<T>):IntoElement {
        return new IntoElement(ViewElement.forView((entity : T)).intoAnyElement());
    }

    /** Strings are text elements (Rust `impl IntoElement for &str / String / SharedString`) */
    @:from static inline function fromString(text:String):IntoElement {
        return new IntoElement(new Text(null, text).intoAnyElement());
    }

    @:from static inline function fromComponent(component:RenderOnce):IntoElement {
        return new IntoElement(ViewElement.forComponent(component).intoAnyElement());
    }

    /**
     * Converts into a dynamically-typed `AnyElement`.
     */
    public inline function intoAnyElement():AnyElement {
        return this;
    }

}
