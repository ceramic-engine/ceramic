// Ported from gpui-pre 0.3.10: src/view.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A dynamically-typed handle to a view: an entity whose model implements
 * `Render`. A zero cost abstract over the model.
 */
abstract AnyView(Model) to Model {

    inline function new(model:Model) {
        this = model;
    }

    @:from static inline function fromRender(view:Render):AnyView {
        return new AnyView(cast view);
    }

    @:from static inline function fromEntity<T:Model & Render>(entity:Entity<T>):AnyView {
        return new AnyView((entity : T));
    }

    /**
     * A `glaze.Component` as a root view: `new Glaze((window, cx) -> AppView.component())`.
     * The component lives as long as the window.
     */
    @:from static inline function fromGlazeComponent(component:Component):AnyView {
        return component != null ? ComponentBuilder.rootView(component) : null;
    }

    /**
     * The entity id of this view.
     */
    public inline function entityId():Int {
        return this.entityId;
    }

    /**
     * The view as a `Render`.
     */
    public inline function render():Render {
        return cast this;
    }

    /**
     * Embed this view as a cached `ViewElement` laid out at `style` (GPUI's
     * `AnyView::cached`): the rendered subtree is recycled from the previous
     * frame unless the view was notified since it was rendered (or
     * `window.refresh()` was called), or its bounds, content mask or text
     * style changed. A cached view is laid out from `style`, not measured
     * from its contents.
     */
    public inline function cached(style:StyleRefinement):ViewElement {
        return ViewElement.forView(this).cached(style);
    }

    /**
     * Embed this view without the default view caching: it renders every frame.
     */
    public inline function uncached():ViewElement {
        return ViewElement.forView(this).uncached();
    }

    /**
     * Converts into an element rendering the view.
     */
    public inline function intoAnyElement():AnyElement {
        return ViewElement.forView(this).intoAnyElement();
    }

}
