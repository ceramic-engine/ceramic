// Ported from gpui-pre 0.3.10: src/view.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The cache state of a view element, kept across frames as element state
 * (Rust `ViewElementState` and `ViewElementCacheKey`): the prepaint and
 * paint ranges recorded during the last frame, and the context they were
 * recorded in.
 */
class ViewElementState {

    public final prepaintStart:PrepaintStateIndex = new PrepaintStateIndex();
    public final prepaintEnd:PrepaintStateIndex = new PrepaintStateIndex();
    public final paintStart:PaintIndex = new PaintIndex();
    public final paintEnd:PaintIndex = new PaintIndex();

    /** Cache key (GPUI): bounds, content mask and text style at prepaint */
    public var bounds:Null<Bounds> = null;
    public var contentMask:Null<ContentMask> = null;
    public var textStyle:Null<TextStyle> = null;

    /** Cache key (default caching): the rest of the context of the view's prepaint and paint */
    public var layoutTextStyle:Null<TextStyle> = null;
    public var remSize:Float = 0;
    public var prepaintOpacity:Float = 1;
    public var paintOpacity:Float = 1;
    public var groupHitboxes:Null<Array<Int>> = null;
    public var imageCache:Null<AnyImageCache> = null;

    /** The layout subtree of the view (default caching), and the layout frame it was recorded in */
    public var layoutId:Int = -1;

    /**
     * The layout nodes the view requested when it last rendered, in request
     * order (nested views excluded): adopted when it renders again while
     * its layout is retained (see `TaffyLayoutEngine.beginViewNodes`)
     */
    public var layoutNodes:Null<Array<Int>> = null;
    public var layoutFrame:Int = -1;

    /**
     * Element states accessed while the view rendered and requested its
     * layout (default caching: before its prepaint range)
     */
    public var layoutAccessedStart:Int = 0;
    public var layoutAccessedEnd:Int = 0;

    /** Layout frames in which the prepaint and paint ranges were recorded */
    public var prepaintFrame:Int = -1;
    public var paintFrame:Int = -1;

    public function new() {}

    public function groupHitboxesEqual(current:Array<Int>):Bool {
        final recorded = groupHitboxes;
        if (recorded == null) {
            return current.length == 0;
        }
        if (recorded.length != current.length) {
            return false;
        }
        for (i in 0...current.length) {
            if (recorded[i] != current[i]) {
                return false;
            }
        }
        return true;
    }

    public function recordGroupHitboxes(current:Array<Int>):Void {
        if (current.length == 0) {
            groupHitboxes = null;
        }
        else {
            if (groupHitboxes == null) {
                groupHitboxes = [];
            }
            groupHitboxes.resize(0);
            for (id in current) {
                groupHitboxes.push(id);
            }
        }
    }

}

/**
 * The element of a view (an entity rendering through `Render`) or of a
 * component (`RenderOnce`).
 *
 * A view is a reactive boundary: its render and the layout, prepaint and
 * paint of the elements it returns run inside the view's tracker capture
 * (see `Window.withRenderedView`), so observable fields read there
 * subscribe the view. Components are rendered within the current view.
 *
 * View caching, three modes for entity views:
 *
 * - `.cached(style)` (GPUI's `Entity::cached` / `AnyView::cached`): the view
 *   is laid out from `style` without rendering it; in prepaint, if it is not
 *   dirty and its bounds, content mask and text style didn't change, the
 *   prepaint and paint of the previous frame are reused, otherwise it renders
 *   and lays out its content as a root in its bounds. Exactly GPUI's logic,
 *   including the forced render of nested cached views while a cached view
 *   renders its content.
 * - default caching (specific to the port, `Window.viewCaching`): no style is
 *   needed. A view that is not dirty retains the layout subtree it built
 *   during the previous frame (so it is laid out exactly as if it had
 *   rendered, mostly from taffy's cache), then reuses its prepaint and paint
 *   when its context didn't change (bounds, content mask, text styles, rem
 *   size, opacity, group hitboxes, image cache). If the context changed (it
 *   moved), it renders in prepaint: its layout requests adopt the retained
 *   nodes (same layout, nothing laid out again), or if they don't match,
 *   its new layout subtree replaces the retained one.
 *   Nested views are reused independently of their parent: a dirty view
 *   renders again, its clean descendants are reused.
 * - `.uncached()`: the view renders every frame.
 *
 * A view is dirty when it was notified since the last frame (`cx.notify()`,
 * or a tracker reaction to an observed field it read), when one of its
 * descendant views is, and during a frame following `window.refresh()`.
 * A reused view keeps its tracker bindings, its element states and its line
 * layouts.
 */
class ViewElement extends Element {

    static inline final MODE_RENDERED = 0;
    static inline final MODE_CACHED_STYLE = 1;
    static inline final MODE_RETAINED_LAYOUT = 2;

    /**
     * Element state type id of `ViewElementState`.
     */
    static final STATE_TYPE:Int = ElementStateType.of(ViewElementState);

    static final scratchPrepaintStart:PrepaintStateIndex = new PrepaintStateIndex();

    static final scratchPaintStart:PaintIndex = new PaintIndex();

    var view:Null<Model> = null;

    var component:Null<RenderOnce> = null;

    var entityId:Int = -1;

    var componentName:Null<String> = null;

    var rendered:Null<AnyElement> = null;

    var cachedStyle:Null<StyleRefinement> = null;

    var uncachedView:Bool = false;

    var mode:Int = MODE_RENDERED;

    var layoutId:LayoutId = 0;

    var layoutTextStyle:Null<TextStyle> = null;

    var state:Null<ViewElementState> = null;

    /** The path of this view's `ViewElementState`, `null` when it has none */
    var stateId:Null<GlobalElementId> = null;

    var layoutAccessedStart:Int = 0;

    var layoutAccessedEnd:Int = 0;

    /** The layout nodes requested by the last render (see `ViewElementState.layoutNodes`) */
    var layoutNodes:Null<Array<Int>> = null;

    function new() {
        #if gpui_count_allocations gpui.util.AllocationCounters.viewElements++; #end
    }

    /**
     * The element of an entity view (Rust `Entity<V>: IntoElement`).
     */
    public static function forView(view:Model):ViewElement {
        final element = new ViewElement();
        element.view = view;
        element.entityId = view.entityId;
        return element;
    }

    /**
     * The element of a component (Rust `RenderOnce: IntoElement`).
     */
    public static function forComponent(component:RenderOnce):ViewElement {
        final element = new ViewElement();
        element.component = component;
        element.componentName = Type.getClassName(Type.getClass(component));
        return element;
    }

    /**
     * Enable caching of this view's rendered subtree, laid out at `style`
     * (GPUI's caching: the view is not measured from its contents). Only
     * meaningful for entity views.
     */
    public function cached(style:StyleRefinement):ViewElement {
        if (entityId != -1) {
            cachedStyle = style;
        }
        return this;
    }

    /**
     * Opt out of the default view caching: the view renders every frame.
     */
    public function uncached():ViewElement {
        uncachedView = true;
        return this;
    }

    override function elementId():Null<ElementId> {
        return entityId != -1 ? ElementId.View(entityId) : null;
    }

    function renderView(window:Window, cx:App):AnyElement {
        if (view != null) {
            final render:Render = cast view;
            return cx.updateEntity(view, (_, viewCx) -> (render.render(window, cast viewCx) : AnyElement));
        }
        else {
            final component = this.component;
            this.component = null;
            return (component.render(window, cx) : AnyElement);
        }
    }

    inline function defaultCaching(window:Window):Bool {
        #if gpui_inspector
        // Rust disables view caching while the inspector is picking
        return window.viewCaching && !uncachedView && !window.viewCachingDisabled && !window.isInspectorPicking(window.app);
        #else
        return window.viewCaching && !uncachedView && !window.viewCachingDisabled;
        #end
    }

    /**
     * Renders the view and requests the layout of its element, in the view's
     * tracker capture.
     */
    function renderAndRequestLayout(window:Window, cx:App, ?adopt:Array<Int>):LayoutId {
        window.beginRenderedView(view, true);
        window.beginViewLayoutNodes(adopt);
        var layoutId:LayoutId = 0;
        try {
            rendered = renderView(window, cx);
            layoutId = rendered.requestLayout(window, cx);
        }
        catch (e:haxe.Exception) {
            layoutNodes = window.endViewLayoutNodes();
            window.endRenderedView();
            throw e;
        }
        layoutNodes = window.endViewLayoutNodes();
        window.endRenderedView();
        return layoutId;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        if (entityId == -1) {
            // Stateless path: isolate subtree via type name (no entity identity).
            window.pushElementId(ElementId.Name(componentName));
            rendered = renderView(window, cx);
            final layoutId = rendered.requestLayout(window, cx);
            window.popElementId();
            return layoutId;
        }

        // Stateful path: create a reactive boundary.
        #if gpui_inspector
        if (cachedStyle != null && !window.viewCachingDisabled && !window.isInspectorPicking(cx)) {
        #else
        if (cachedStyle != null && !window.viewCachingDisabled) {
        #end
            mode = MODE_CACHED_STYLE;
            final rootStyle = new Style();
            rootStyle.refine(cachedStyle);
            layoutId = window.requestLayout(rootStyle, null, cx);
            return layoutId;
        }

        if (defaultCaching(window)) {
            stateId = id;
            layoutTextStyle = window.sharedCurrentTextStyle();
            if (!window.refreshing && !window.drawingClean && !window.isViewDirty(entityId)) {
                final state:Null<ViewElementState> = window.peekElementState(stateId, STATE_TYPE);
                final previousFrame = window.layoutFrame() - 1;
                if (state != null
                    && state.layoutId != -1
                    && state.layoutFrame == previousFrame
                    && state.prepaintFrame == previousFrame
                    && state.paintFrame == previousFrame
                    && state.remSize == window.remSize()
                    && state.layoutTextStyle != null
                    && state.layoutTextStyle.equals(layoutTextStyle)
                    && window.retainLayout(state.layoutId, state.layoutFrame)) {
                    mode = MODE_RETAINED_LAYOUT;
                    layoutId = state.layoutId;
                    // Keep the element states the view accessed while rendering
                    layoutAccessedStart = window.accessedElementStatesIndex();
                    window.reuseAccessedElementStates(state.layoutAccessedStart, state.layoutAccessedEnd);
                    layoutAccessedEnd = window.accessedElementStatesIndex();
                    return layoutId;
                }
            }
        }

        mode = MODE_RENDERED;
        layoutAccessedStart = window.accessedElementStatesIndex();
        layoutId = renderAndRequestLayout(window, cx);
        layoutAccessedEnd = window.accessedElementStatesIndex();
        return layoutId;
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (entityId == -1) {
            window.pushElementId(ElementId.Name(componentName));
            rendered.prepaint(window, cx);
            window.popElementId();
            return;
        }

        window.setViewId(entityId);

        switch mode {
            case MODE_CACHED_STYLE:
                prepaintCachedStyle(id, bounds, window, cx);
            case MODE_RETAINED_LAYOUT:
                prepaintRetainedLayout(id, bounds, window, cx);
            case _:
                if (stateId != null) {
                    final box = window.elementStateBox(stateId, STATE_TYPE);
                    if (box.value == null) {
                        box.value = new ViewElementState();
                    }
                    final state:ViewElementState = box.value;
                    this.state = state;
                    prepaintRendered(state, window, cx);
                    recordKey(state, bounds, window);
                    state.layoutId = layoutId;
                    state.layoutFrame = window.layoutFrame();
                    state.layoutTextStyle = layoutTextStyle;
                    state.layoutAccessedStart = layoutAccessedStart;
                    state.layoutAccessedEnd = layoutAccessedEnd;
                    state.layoutNodes = layoutNodes;
                }
                else {
                    window.beginRenderedView(view, false);
                    try {
                        rendered.prepaint(window, cx);
                    }
                    catch (e:haxe.Exception) {
                        window.endRenderedView();
                        throw e;
                    }
                    window.endRenderedView();
                }
        }
    }

    /**
     * Prepaints the rendered element, recording its prepaint range in `state`.
     */
    function prepaintRendered(state:ViewElementState, window:Window, cx:App):Void {
        window.prepaintIndexInto(state.prepaintStart);
        window.beginRenderedView(view, false);
        try {
            rendered.prepaint(window, cx);
        }
        catch (e:haxe.Exception) {
            window.endRenderedView();
            throw e;
        }
        window.endRenderedView();
        window.prepaintIndexInto(state.prepaintEnd);
        state.prepaintFrame = window.layoutFrame();
    }

    function recordKey(state:ViewElementState, bounds:Bounds, window:Window):Void {
        state.bounds = bounds;
        state.contentMask = window.contentMask();
        state.textStyle = window.sharedCurrentTextStyle();
        state.remSize = window.remSize();
        state.prepaintOpacity = window.prepaintOpacity;
        state.recordGroupHitboxes(window.prepaintGroupHitboxes);
        state.imageCache = window.currentImageCache();
    }

    /**
     * Reuses the prepaint range recorded in `state` during the last frame.
     */
    function reusePrepaint(state:ViewElementState, window:Window):Void {
        final start = scratchPrepaintStart;
        window.prepaintIndexInto(start);
        window.reusePrepaint(state.prepaintStart, state.prepaintEnd);
        window.prepaintIndexInto(state.prepaintEnd);
        state.prepaintStart.copyFrom(start);
        state.prepaintFrame = window.layoutFrame();
        window.countReusedView();
    }

    function prepaintRetainedLayout(id:GlobalElementId, bounds:Bounds, window:Window, cx:App):Void {
        final box = window.elementStateBox(stateId, STATE_TYPE);
        final state:ViewElementState = box.value;
        this.state = state;
        final textStyle = window.sharedCurrentTextStyle();
        final contentMask = window.contentMask();
        if (state.bounds.equals(bounds)
            && state.contentMask.equals(contentMask)
            && state.textStyle.equals(textStyle)
            && state.prepaintOpacity == window.prepaintOpacity
            && state.groupHitboxesEqual(window.prepaintGroupHitboxes)
            && state.imageCache == window.currentImageCache()) {
            reusePrepaint(state, window);
            state.layoutFrame = window.layoutFrame();
            state.layoutAccessedStart = layoutAccessedStart;
            state.layoutAccessedEnd = layoutAccessedEnd;
            rendered = null;
            return;
        }

        // The context changed (it moved, scrolling): render again. The view
        // is clean, so it requests the same nodes as last time: they adopt
        // the retained ones, already laid out, and nothing is laid out again.
        // Otherwise its new subtree replaces the retained one, laid out again.
        final oldRoot = layoutId;
        final newRoot = renderAndRequestLayout(window, cx, state.layoutNodes);
        final adopted = window.viewLayoutNodesAdopted() && newRoot == oldRoot;
        state.layoutNodes = layoutNodes;
        if (!adopted && !window.replaceRetainedLayout(oldRoot, newRoot)) {
            ceramic.Shortcuts.log.warning('View ${Type.getClassName(Type.getClass(view))} rendered a different layout without being notified: it will render again on the next frame');
            window.invalidateViewForNextFrame(entityId);
        }
        layoutId = newRoot;
        prepaintRendered(state, window, cx);
        recordKey(state, bounds, window);
        state.layoutId = newRoot;
        state.layoutFrame = window.layoutFrame();
        state.layoutTextStyle = layoutTextStyle;
        // The render happened within the prepaint range
        state.layoutAccessedStart = 0;
        state.layoutAccessedEnd = 0;
    }

    /**
     * GPUI's `prepaint_view` for a view cached with a style.
     */
    function prepaintCachedStyle(id:GlobalElementId, bounds:Bounds, window:Window, cx:App):Void {
        stateId = id;
        final box = window.elementStateBox(stateId, STATE_TYPE);
        final contentMask = window.contentMask();
        final textStyle = window.sharedCurrentTextStyle();
        final existing:Null<ViewElementState> = box.value;
        // Difference with GPUI: the key also has the rest of the context
        // (opacity, group hitboxes, image cache, rem size), so that reusing
        // never paints something an uncached view would paint differently.
        // The recorded ranges index the last frame only: when an ancestor
        // reused its own range instead of visiting this view, they are stale.
        if (existing != null
            && existing.prepaintFrame == window.layoutFrame() - 1
            && existing.paintFrame == window.layoutFrame() - 1
            && existing.bounds.equals(bounds)
            && existing.contentMask.equals(contentMask)
            && existing.textStyle.equals(textStyle)
            && existing.remSize == window.remSize()
            && existing.prepaintOpacity == window.prepaintOpacity
            && existing.groupHitboxesEqual(window.prepaintGroupHitboxes)
            && existing.imageCache == window.currentImageCache()
            && !window.isViewDirty(entityId)
            && !window.refreshing) {
            state = existing;
            reusePrepaint(existing, window);
            rendered = null;
            return;
        }

        final state:ViewElementState = existing != null ? existing : new ViewElementState();
        box.value = state;
        this.state = state;
        final refreshing = window.refreshing;
        window.refreshing = true;
        window.prepaintIndexInto(state.prepaintStart);
        window.beginRenderedView(view, true);
        window.viewDependencies.cachedStyleDepth++;
        try {
            rendered = renderView(window, cx);
            rendered.layoutAsRoot(new SizeOf<AvailableSpace>(AvailableSpace.Definite(bounds.size.width), AvailableSpace.Definite(bounds.size.height)), window, cx);
            rendered.prepaintAt(bounds.origin, window, cx);
        }
        catch (e:haxe.Exception) {
            window.viewDependencies.cachedStyleDepth--;
            window.endRenderedView();
            window.refreshing = refreshing;
            throw e;
        }
        window.viewDependencies.cachedStyleDepth--;
        window.endRenderedView();
        window.prepaintIndexInto(state.prepaintEnd);
        window.refreshing = refreshing;
        recordKey(state, bounds, window);
        state.prepaintFrame = window.layoutFrame();
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (entityId == -1) {
            window.pushElementId(ElementId.Name(componentName));
            rendered.paint(window, cx);
            window.popElementId();
            rendered = null;
            return;
        }

        final state = this.state;
        if (state == null) {
            // Not cached
            paintRendered(window, cx);
        }
        else if (rendered != null) {
            window.paintIndexInto(state.paintStart);
            if (mode == MODE_CACHED_STYLE) {
                final refreshing = window.refreshing;
                window.refreshing = true;
                window.viewDependencies.cachedStyleDepth++;
                try {
                    paintRendered(window, cx);
                }
                catch (e:haxe.Exception) {
                    window.viewDependencies.cachedStyleDepth--;
                    window.refreshing = refreshing;
                    throw e;
                }
                window.viewDependencies.cachedStyleDepth--;
                window.refreshing = refreshing;
            }
            else {
                paintRendered(window, cx);
            }
            window.paintIndexInto(state.paintEnd);
            state.paintFrame = window.layoutFrame();
            state.paintOpacity = window.currentElementOpacity();
        }
        else {
            if (state.paintOpacity != window.currentElementOpacity()) {
                // An ancestor painted with an opacity that did not show at
                // prepaint (hover dependent): correct it on the next frame.
                window.invalidateViewForNextFrame(entityId);
            }
            final start = scratchPaintStart;
            window.paintIndexInto(start);
            window.reusePaint(state.paintStart, state.paintEnd);
            window.paintIndexInto(state.paintEnd);
            state.paintStart.copyFrom(start);
            state.paintFrame = window.layoutFrame();
        }

        rendered = null;
        view = null;
        this.state = null;
    }

    function paintRendered(window:Window, cx:App):Void {
        window.beginRenderedView(view, false);
        try {
            rendered.paint(window, cx);
        }
        catch (e:haxe.Exception) {
            window.endRenderedView();
            throw e;
        }
        window.endRenderedView();
    }

}
