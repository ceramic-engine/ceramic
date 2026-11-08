// New code for the Haxe port of gpui-kit (no gpui-kit origin): the content of
// a `Root`. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyView;
import glaze.Component;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;

/**
 * What a `Root` hosts, given with `Root.component().child(...)` (Rust's
 * `Root::new(view: impl Into<AnyView>, ...)`): a `Component` placed with
 * `X.component()...`, a `Render` entity, an `Entity<T>` of one, or any
 * `AnyView`. Not an element: the root renders its content again at each of
 * its renders (an element is drawn once), so it keeps the view or the
 * component and makes the element then.
 */
abstract RootContent(Dynamic) {

    inline function new(content:Dynamic) {
        this = content;
    }

    @:from static inline function fromComponent(component:Component):RootContent {
        return component != null ? new RootContent(component) : null;
    }

    @:from static inline function fromAnyView(view:AnyView):RootContent {
        return view != null ? new RootContent((view : Model)) : null;
    }

    @:from static inline function fromRender(view:Render):RootContent {
        return view != null ? new RootContent(view) : null;
    }

    @:from static inline function fromEntity<T:Model & Render>(entity:Entity<T>):RootContent {
        return entity != null ? new RootContent((entity : T)) : null;
    }

    /**
     * The element drawing this content in the current render of the root.
     */
    public function intoElement():IntoElement {
        final content:Dynamic = this;
        if (Std.isOfType(content, Component)) {
            final component:Component = content;
            return component.__intoAnyElement();
        }
        final view:Render = content;
        return view;
    }

    /**
     * This content as a view, `null` for a component.
     */
    public function view():Null<AnyView> {
        final content:Dynamic = this;
        if (Std.isOfType(content, Component))
            return null;
        final view:Render = content;
        return view;
    }

}
