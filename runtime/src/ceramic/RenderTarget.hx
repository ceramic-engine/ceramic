package ceramic;

/**
 * A destination a `Visual` can be rendered into: the `screen`, or a `RenderTexture`.
 *
 * A visual without parent is **mounted** (updated, rendered, hit-tested) only when
 * its `renderTarget` is set to one of these. A visual with a parent follows its
 * parent instead, its own `renderTarget` then only redirecting where it is drawn.
 *
 * ```haxe
 * screen.add(visual);           // same as: visual.renderTarget = screen
 * renderTexture.add(visual);    // same as: visual.renderTarget = renderTexture
 * ```
 */
interface RenderTarget {

    /**
     * Visuals added directly to this render target (via `add()` or `visual.renderTarget = target`).
     * Like a visual's `children`, this lists direct additions only, not their descendants.
     */
    var visuals(get, never):ReadOnlyArray<Visual>;

    /**
     * Add a visual to this render target so that it gets mounted and rendered into it.
     * If the visual has a parent, it is removed from it first.
     */
    function add(visual:Visual):Void;

    /**
     * Remove a visual previously added to this render target (unmounts it).
     */
    function remove(visual:Visual):Void;

}
