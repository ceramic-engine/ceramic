// Ported from gpui-pre 0.3.10: src/view.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

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

    /** When `layoutAccessedStart` and `layoutAccessedEnd` were recorded (see `PrepaintStateIndex.time`) */
    public var layoutAccessedStartTime:Float = 0;
    public var layoutAccessedEndTime:Float = 0;

    /*
     * What rendering the view again alone needs (in place rendering, see
     * `Window`): the view, the path of this state, the node of the view in
     * the dispatch tree and the context of its prepaint and paint that the
     * cache key above does not hold.
     */
    public var model:Null<Model> = null;
    public var stateId:Null<GlobalElementId> = null;
    /** Drawn with `.cached(style)` (never rendered in place) */
    public var cachedStyle:Bool = false;
    public var dispatchNode:Int = -1;
    public var elementOffset:Null<Point> = null;
    public var paintContentMask:Null<ContentMask> = null;
    public var paintTextStyle:Null<TextStyle> = null;
    public var paintImageCache:Null<AnyImageCache> = null;
    public var paintRemSize:Float = 0;

    /** Drawn inside a shared context (see `Window.enterSharedContext`) */
    public var inSharedContext:Bool = false;

    /** The frame whose list of view states holds this one (`Window.registerViewState`) */
    public var registeredSerial:Int = -1;

    /** The in place rendering that recorded this state's ranges last */
    public var amendSerial:Int = -1;

    /** The tracker of the view (cached) */
    public var tracker:Null<ViewTracker> = null;

    /** A refinement making `inPlaceTextStyle` from the default text style (made once per text style) */
    public var inPlaceTextStyle:Null<TextStyle> = null;
    public var inPlaceTextStyleRefinement:Null<TextStyleRefinement> = null;

    /** Layout frames in which the prepaint and paint ranges were recorded */
    public var prepaintFrame:Int = -1;
    public var paintFrame:Int = -1;

    #if glaze_verify_cache
    /** The answers of the hover tests of its last prepaint and paint (`glaze_verify_cache`) */
    public var hoverLog:Null<String> = null;
    #end

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
 *   renders again, its clean descendants are reused. A dirty view adopts
 *   the layout nodes it requested during the previous frame where their
 *   style did not change, so that only what changed is laid out again
 *   (see `TaffyLayoutEngine`, incremental layout).
 * - `.uncached()`: the view renders every frame.
 *
 * A view is dirty when it was notified since the last frame (`cx.notify()`,
 * or a tracker reaction to an observed field it read), when one of its
 * descendant views is, and during a frame following `window.refresh()`.
 * With default caching, it is also dirty when an entity it accessed while
 * drawn (a model it read or updated, not a view) was notified: GPUI renders
 * such a view again in its next frame, as it renders every uncached view.
 * A reused view keeps its tracker bindings, its element states and its line
 * layouts.
 *
 * Define `glaze_verify_cache` (debug): a view that would be reused renders
 * for real instead and its drawing is compared with its cached one (see
 * `Window.verifyCache`).
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

    /** A stateless `glaze.Component` (see `forGlazeComponent`) */
    var glazeComponent:Null<Component> = null;

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

    var layoutAccessedStartTime:Float = 0;

    var layoutAccessedEndTime:Float = 0;

    /** Where `reuseAccessedElementStates` started in the reused list (a retained view, see `prepaintRetainedLayout`) */
    var layoutReusedStart:Int = 0;

    /** The layout nodes requested by the last render (see `ViewElementState.layoutNodes`) */
    var layoutNodes:Null<Array<Int>> = null;

    #if glaze_verify_cache
    /** `glaze_verify_cache`: the reuse this view would have made in this frame */
    var verification:Null<CacheVerification> = null;

    /** The hover tests made by its prepaint (see `Window.hoverLogMark`) */
    var hoverPrepaintStart:Int = 0;
    var hoverPrepaintEnd:Int = 0;

    /** The class of the view, or of the component drawn by a component host */
    function viewName():String {
        final view = this.view;
        if (view == null) {
            return 'view';
        }
        if (Std.isOfType(view, ComponentBuilder.ComponentHost)) {
            return Type.getClassName(Type.getClass((cast view : ComponentBuilder.ComponentHost).instance));
        }
        return Type.getClassName(Type.getClass(view));
    }
    #end

    function new() {
        #if glaze_count_allocations glaze.util.AllocationCounters.viewElements++; #end
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
     * The element of a stateless `glaze.Component`, rendered like a
     * `RenderOnce` under the element id of its class, or under its `.at(key)`.
     */
    public static function forGlazeComponent(component:Component):ViewElement {
        final element = new ViewElement();
        element.glazeComponent = component;
        final key = component.__key;
        element.componentId = key != null ? key : component.__elementId();
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
        if (entityId == -1)
            return null;
        // Made once per element (it is asked in each phase)
        var id = viewElementId;
        if (id == null || viewElementIdEntity != entityId) {
            id = ElementId.View(entityId);
            viewElementId = id;
            viewElementIdEntity = entityId;
        }
        return id;
    }

    /**
     * `ElementId.Name(componentName)`, made once per component class (it is
     * pushed in each phase; element ids are immutable values)
     */
    function componentElementId():ElementId {
        var id = componentId;
        if (componentName == null) {
            // A `glaze.Component`: its id was given by `forGlazeComponent`
            return id;
        }
        if (id == null || componentIdName != componentName) {
            final name = componentName;
            id = name != null ? componentIds.get(name) : null;
            if (id == null) {
                id = ElementId.Name(name);
                if (name != null) componentIds.set(name, id);
            }
            componentId = id;
            componentIdName = name;
        }
        return id;
    }

    /** The ids of `componentElementId()`, by component class name */
    static final componentIds:Map<String, ElementId> = new Map();

    var componentId:Null<ElementId> = null;

    var componentIdName:Null<String> = null;

    var viewElementId:Null<ElementId> = null;

    var viewElementIdEntity:Int = -1;

    function renderView(window:Window, cx:App):AnyElement {
        if (view != null) {
            final render:Render = cast view;
            // `cx.updateEntity(view, (_, viewCx) -> render.render(window, viewCx))`
            // without the closure (the same steps as `App.updateEntity`)
            final viewCx:Context<Dynamic> = cast @:privateAccess view.slot();
            Window.recordAccess(viewCx.id);
            @:privateAccess cx.startUpdate();
            var element:AnyElement;
            try {
                element = (render.render(window, viewCx) : AnyElement);
            }
            catch (e:haxe.Exception) {
                @:privateAccess cx.pendingUpdates--;
                throw glaze.util.Exceptions.rethrow(e);
            }
            @:privateAccess cx.finishUpdate();
            return element;
        }
        else if (component != null) {
            final component = this.component;
            this.component = null;
            return (component.render(window, cx) : AnyElement);
        }
        else {
            final component = this.glazeComponent;
            this.glazeComponent = null;
            // `invalidate()` of a stateless component notifies the view it renders in
            component.__window = window;
            component.__viewId = window.renderedViewId();
            return (component.render(window, cx) : AnyElement);
        }
    }

    inline function defaultCaching(window:Window):Bool {
        #if glaze_inspector
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
    function renderAndRequestLayout(window:Window, cx:App, ?adopt:Array<Int>, checked:Bool = false):LayoutId {
        window.beginRenderedView(view, true);
        window.beginViewLayoutNodes(adopt, checked);
        var layoutId:LayoutId = 0;
        try {
            rendered = renderView(window, cx);
            layoutId = rendered.requestLayout(window, cx);
        }
        catch (e:haxe.Exception) {
            layoutNodes = window.endViewLayoutNodes();
            window.endRenderedView();
            throw glaze.util.Exceptions.rethrow(e);
        }
        layoutNodes = window.endViewLayoutNodes();
        window.endRenderedView();
        return layoutId;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        if (entityId == -1) {
            // Stateless path: isolate subtree via type name (no entity identity).
            window.pushElementId(componentElementId());
            rendered = renderView(window, cx);
            final layoutId = rendered.requestLayout(window, cx);
            window.popElementId();
            return layoutId;
        }

        // Stateful path: create a reactive boundary.
        // A view notified earlier in this frame renders in this frame
        window.promotePendingDirtyView(entityId);

        // Rendered already in this draw by an in place rendering that gave
        // way to a full frame (see `Window`): its render is the one drawn
        if (cachedStyle == null && defaultCaching(window)) {
            final preRendered = window.takePreRenderedView(entityId, id);
            if (preRendered != null) {
                stateId = id;
                mode = MODE_RENDERED;
                rendered = preRendered.rendered;
                layoutId = preRendered.layoutId;
                layoutNodes = preRendered.layoutNodes;
                layoutTextStyle = preRendered.layoutTextStyle;
                takePreRenderedStates(preRendered, window);
                preRendered.rendered = null;
                followAccessedEntities(window, true);
                return layoutId;
            }
        }
        #if glaze_inspector
        if (cachedStyle != null && !window.viewCachingDisabled && !window.isInspectorPicking(cx)) {
        #else
        if (cachedStyle != null && !window.viewCachingDisabled) {
        #end
            mode = MODE_CACHED_STYLE;
            followAccessedEntities(window, false);
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
                final previousFrame = window.reusableFrame();
                var reusable = state != null
                    && state.layoutId != -1
                    && state.layoutFrame == previousFrame
                    && state.prepaintFrame == previousFrame
                    && state.paintFrame == previousFrame
                    && state.remSize == window.remSize()
                    && state.layoutTextStyle != null
                    && state.layoutTextStyle.equals(layoutTextStyle);
                #if glaze_verify_cache
                if (reusable && Window.verifyCache && !window.exemptFromVerification(entityId)) {
                    // Rendered for real instead, compared in paint with
                    // what the reuse would have drawn
                    verification = CacheVerification.of(verification, state);
                    reusable = false;
                }
                #end
                if (reusable && window.retainLayout(state.layoutId, state.layoutFrame)) {
                    mode = MODE_RETAINED_LAYOUT;
                    layoutId = state.layoutId;
                    // Keep the element states the view accessed while rendering
                    layoutAccessedStart = window.accessedElementStatesIndex();
                    layoutAccessedStartTime = window.captureTime();
                    layoutReusedStart = window.reusedElementStatesIndex();
                    window.reuseAccessedElementStates(state.layoutAccessedStart, state.layoutAccessedEnd);
                    layoutAccessedEnd = window.accessedElementStatesIndex();
                    layoutAccessedEndTime = window.captureTime();
                    if (window.amending) {
                        window.amendLayoutElements.push(this);
                    }
                    // Its tracker keeps `defaultCaching` from its last render
                    // (a view retained is drawn with default caching, outside
                    // of any view cached with a style)
                    return layoutId;
                }
            }
        }

        mode = MODE_RENDERED;
        // A view that renders because it changed adopts the layout nodes it
        // requested during the previous frame where they did not change
        // (incremental layout, see `TaffyLayoutEngine.beginViewNodes`)
        var adopt:Null<Array<Int>> = null;
        if (stateId != null && !window.refreshing) {
            final state:Null<ViewElementState> = window.peekElementState(stateId, STATE_TYPE);
            if (state != null && state.layoutId != -1 && state.layoutFrame == window.reusableFrame()) {
                adopt = state.layoutNodes;
            }
        }
        layoutAccessedStart = window.accessedElementStatesIndex();
        layoutAccessedStartTime = window.captureTime();
        layoutId = renderAndRequestLayout(window, cx, adopt, adopt != null);
        layoutAccessedEnd = window.accessedElementStatesIndex();
        layoutAccessedEndTime = window.captureTime();
        if (window.amending) {
            window.amendLayoutElements.push(this);
        }
        followAccessedEntities(window, stateId != null);
        return layoutId;
    }

    /**
     * In place rendering (see `Window`): the element rendering the view of
     * `state` again alone.
     */
    @:allow(glaze)
    static function forInPlace(state:ViewElementState):ViewElement {
        final element = forView(state.model);
        element.stateId = state.stateId;
        element.mode = MODE_RENDERED;
        return element;
    }

    /**
     * In place rendering: renders the view and requests its layout,
     * adopting the nodes it requested last time (like a view that renders
     * because it changed). The element id path and the context are set by
     * the window.
     */
    @:allow(glaze)
    function renderInPlace(state:ViewElementState, window:Window, cx:App):LayoutId {
        layoutTextStyle = window.sharedCurrentTextStyle();
        layoutAccessedStart = window.accessedElementStatesIndex();
        layoutAccessedStartTime = window.captureTime();
        layoutId = renderAndRequestLayout(window, cx, state.layoutNodes, true);
        layoutAccessedEnd = window.accessedElementStatesIndex();
        layoutAccessedEndTime = window.captureTime();
        followAccessedEntities(window, true);
        return layoutId;
    }

    /** In place rendering: prepaints the rendered view in `bounds` (the bounds it had) */
    @:allow(glaze)
    function prepaintInPlace(state:ViewElementState, bounds:Bounds, window:Window, cx:App):Void {
        window.setViewId(entityId);
        prepaintRenderedState(state, bounds, window, cx);
    }

    /** In place rendering: paints the rendered view */
    @:allow(glaze)
    function paintInPlace(state:ViewElementState, window:Window, cx:App):Void {
        paint(stateId, state.bounds, window, cx);
    }

    /**
     * The element states the pre-rendered view accessed (recorded before
     * the other entries of the frame) move here, inside the ranges of its
     * ancestors; the ranges of the views it drew follow (positions and
     * times).
     */
    function takePreRenderedStates(preRendered:PreRenderedView, window:Window):Void {
        layoutAccessedStart = window.accessedElementStatesIndex();
        layoutAccessedStartTime = window.captureTime();
        window.moveAccessedElementStates(preRendered.layoutAccessedStart, preRendered.layoutAccessedEnd);
        layoutAccessedEnd = window.accessedElementStatesIndex();
        layoutAccessedEndTime = window.captureTime();
        final nested = preRendered.nested;
        if (nested != null) {
            final delta = layoutAccessedStart - preRendered.layoutAccessedStart;
            final oldStartTime = preRendered.layoutAccessedStartTime;
            final oldSpan = preRendered.layoutAccessedEndTime - oldStartTime;
            final newStartTime = layoutAccessedStartTime;
            final newSpan = layoutAccessedEndTime - newStartTime;
            inline function mapTime(time:Float):Float {
                return newStartTime + newSpan * (time - oldStartTime) / oldSpan;
            }
            for (element in nested) {
                element.layoutAccessedStart += delta;
                element.layoutAccessedEnd += delta;
                element.layoutAccessedStartTime = mapTime(element.layoutAccessedStartTime);
                element.layoutAccessedEndTime = mapTime(element.layoutAccessedEndTime);
                // Its copies are no longer in this frame's reused list
                element.layoutReusedStart = -1;
            }
            preRendered.nested = null;
        }
    }

    /** The render of this element, given to the full frame drawn instead of rendering in place */
    @:allow(glaze)
    function preRendered():PreRenderedView {
        final result = new PreRenderedView();
        result.stateId = stateId;
        result.rendered = rendered;
        result.layoutId = layoutId;
        result.layoutNodes = layoutNodes;
        result.layoutTextStyle = layoutTextStyle;
        result.layoutAccessedStart = layoutAccessedStart;
        result.layoutAccessedEnd = layoutAccessedEnd;
        result.layoutAccessedStartTime = layoutAccessedStartTime;
        result.layoutAccessedEndTime = layoutAccessedEndTime;
        rendered = null;
        return result;
    }

    /** Records what in place rendering needs about the view (see `ViewElementState.model`) */
    inline function recordInPlaceContext(state:ViewElementState, window:Window):Void {
        state.model = view;
        state.stateId = stateId;
        state.cachedStyle = mode == MODE_CACHED_STYLE;
        state.dispatchNode = window.nextFrameDispatchTree().activeNodeId();
        state.elementOffset = window.elementOffset();
        state.inSharedContext = Window.inSharedContext();
    }

    /**
     * Tells the view's tracker whether the view is cached by default in this
     * frame (outside of a view cached with a style): a notify of an entity it
     * accessed then renders it again (`Window.markViewsThatAccessed`).
     */
    inline function followAccessedEntities(window:Window, defaultCached:Bool):Void {
        final tracker = window.viewTracker(entityId);
        if (tracker != null) {
            tracker.defaultCaching = defaultCached && window.viewDependencies.cachedStyleDepth == 0;
        }
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (entityId == -1) {
            window.pushElementId(componentElementId());
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
                    prepaintRenderedState(box.value, bounds, window, cx);
                }
                else {
                    window.markUncachedViewDrawn();
                    window.beginRenderedView(view, false);
                    try {
                        rendered.prepaint(window, cx);
                    }
                    catch (e:haxe.Exception) {
                        window.endRenderedView();
                        throw glaze.util.Exceptions.rethrow(e);
                    }
                    window.endRenderedView();
                }
        }
    }

    /**
     * Prepaints the view rendered in this frame with default caching,
     * recording its ranges and context in `state`.
     */
    function prepaintRenderedState(state:ViewElementState, bounds:Bounds, window:Window, cx:App):Void {
        this.state = state;
        recordInPlaceContext(state, window);
        #if glaze_verify_cache
        if (verification != null && verification.pending) {
            // The reuse of `prepaintRetainedLayout` needs the same context
            verification.compare = state.bounds != null
                && state.bounds.equals(bounds)
                && state.contentMask.equals(window.contentMask())
                && state.textStyle.equals(window.sharedCurrentTextStyle())
                && state.prepaintOpacity == window.prepaintOpacity
                && state.groupHitboxesEqual(window.prepaintGroupHitboxes)
                && state.imageCache == window.currentImageCache();
        }
        else {
            keepOldRanges(state, window);
        }
        #end
        prepaintRendered(state, window, cx);
        recordKey(state, bounds, window);
        state.layoutId = layoutId;
        state.layoutFrame = window.layoutFrame();
        state.layoutTextStyle = layoutTextStyle;
        state.layoutAccessedStart = layoutAccessedStart;
        state.layoutAccessedEnd = layoutAccessedEnd;
        state.layoutAccessedStartTime = layoutAccessedStartTime;
        state.layoutAccessedEndTime = layoutAccessedEndTime;
        state.layoutNodes = layoutNodes;
    }

    /**
     * Prepaints the rendered element, recording its prepaint range in `state`.
     */
    function prepaintRendered(state:ViewElementState, window:Window, cx:App):Void {
        #if glaze_verify_cache
        hoverPrepaintStart = window.hoverLogMark();
        #end
        window.prepaintIndexInto(state.prepaintStart);
        window.beginRenderedView(view, false);
        try {
            rendered.prepaint(window, cx);
        }
        catch (e:haxe.Exception) {
            window.endRenderedView();
            throw glaze.util.Exceptions.rethrow(e);
        }
        window.endRenderedView();
        window.prepaintIndexInto(state.prepaintEnd);
        state.prepaintFrame = window.layoutFrame();
        window.registerViewState(state);
        #if glaze_verify_cache
        hoverPrepaintEnd = window.hoverLogMark();
        #end
    }

    #if glaze_verify_cache
    /**
     * `glaze_verify_cache`: a view rendered for real without being compared
     * (dirty, moved) keeps the ranges it drew in the last frame, if it was
     * drawn in it, so that the views around it leave them out of their
     * comparison (see `Window.endVerifyScope`).
     */
    function keepOldRanges(state:ViewElementState, window:Window):Void {
        final previousFrame = window.reusableFrame();
        if (state.prepaintFrame == previousFrame && state.paintFrame == previousFrame) {
            verification = CacheVerification.oldRangesOf(verification, state);
        }
        else if (verification != null) {
            verification.reset();
            verification = null;
        }
    }
    #end

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
        window.registerViewState(state);
        window.countReusedView();
    }

    function prepaintRetainedLayout(id:GlobalElementId, bounds:Bounds, window:Window, cx:App):Void {
        final box = window.elementStateBox(stateId, STATE_TYPE);
        final state:ViewElementState = box.value;
        this.state = state;
        recordInPlaceContext(state, window);
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
            state.layoutAccessedStartTime = layoutAccessedStartTime;
            state.layoutAccessedEndTime = layoutAccessedEndTime;
            rendered = null;
            return;
        }

        // The context changed (it moved, scrolling): render again. The view
        // is clean, so it requests the same nodes as last time: they adopt
        // the retained ones, already laid out, and nothing is laid out again.
        // Otherwise its new subtree replaces the retained one, laid out again.
        #if glaze_verify_cache
        keepOldRanges(state, window);
        #end
        final oldRoot = layoutId;
        window.forgetReusedElementStates(layoutAccessedStart, layoutAccessedEnd, layoutReusedStart);
        layoutAccessedStart = window.accessedElementStatesIndex();
        layoutAccessedStartTime = window.captureTime();
        final newRoot = renderAndRequestLayout(window, cx, state.layoutNodes);
        layoutAccessedEnd = window.accessedElementStatesIndex();
        layoutAccessedEndTime = window.captureTime();
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
        // The render happened before the prepaint range: the element states
        // it accessed are kept like those of a render in `requestLayout`
        state.layoutAccessedStart = layoutAccessedStart;
        state.layoutAccessedEnd = layoutAccessedEnd;
        state.layoutAccessedStartTime = layoutAccessedStartTime;
        state.layoutAccessedEndTime = layoutAccessedEndTime;
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
            && existing.prepaintFrame == window.reusableFrame()
            && existing.paintFrame == window.reusableFrame()
            && existing.bounds.equals(bounds)
            && existing.contentMask.equals(contentMask)
            && existing.textStyle.equals(textStyle)
            && existing.remSize == window.remSize()
            && existing.prepaintOpacity == window.prepaintOpacity
            && existing.groupHitboxesEqual(window.prepaintGroupHitboxes)
            && existing.imageCache == window.currentImageCache()
            && !window.isViewDirty(entityId)
            && !window.refreshing) {
            #if glaze_verify_cache
            if (Window.verifyCache && !window.exemptFromVerification(entityId)) {
                // Rendered for real instead, compared in paint with what
                // the reuse would have drawn
                verification = CacheVerification.of(verification, existing);
                verification.compare = true;
            }
            else {
            #end
            state = existing;
            recordInPlaceContext(existing, window);
            reusePrepaint(existing, window);
            rendered = null;
            return;
            #if glaze_verify_cache
            }
            #end
        }

        final state:ViewElementState = existing != null ? existing : new ViewElementState();
        box.value = state;
        this.state = state;
        recordInPlaceContext(state, window);
        #if glaze_verify_cache
        if (verification == null || !verification.compare) {
            keepOldRanges(state, window);
        }
        #end
        final refreshing = window.refreshing;
        window.refreshing = true;
        #if glaze_verify_cache
        hoverPrepaintStart = window.hoverLogMark();
        #end
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
            throw glaze.util.Exceptions.rethrow(e);
        }
        window.viewDependencies.cachedStyleDepth--;
        window.endRenderedView();
        window.prepaintIndexInto(state.prepaintEnd);
        #if glaze_verify_cache
        hoverPrepaintEnd = window.hoverLogMark();
        #end
        window.refreshing = refreshing;
        recordKey(state, bounds, window);
        state.prepaintFrame = window.layoutFrame();
        window.registerViewState(state);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (entityId == -1) {
            window.pushElementId(componentElementId());
            rendered.paint(window, cx);
            window.popElementId();
            rendered = null;
            return;
        }

        final state = this.state;
        if (state == null) {
            // Not cached
            paintRendered(window, cx);
            #if glaze_verify_cache
            window.cacheVerificationUnverifiable();
            #end
        }
        else if (rendered != null) {
            #if glaze_verify_cache
            final scope = window.beginVerifyScope(entityId, verification, state, window.isViewDirty(entityId) || window.refreshing);
            final hoverPaintStart = window.hoverLogMark();
            #end
            recordPaintContext(state, window);
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
                    throw glaze.util.Exceptions.rethrow(e);
                }
                window.viewDependencies.cachedStyleDepth--;
                window.refreshing = refreshing;
            }
            else {
                paintRendered(window, cx);
            }
            window.paintIndexInto(state.paintEnd);
            state.paintFrame = window.layoutFrame();
            #if glaze_verify_cache
            // What the hover tests answered while it drew: hover changes
            // without an event are not invalidations (GPUI's rule). Other
            // answers to the same tests are a hover change; another number
            // of tests is a change of what the view draws, compared below.
            final hover = window.hoverLogSegment(hoverPrepaintStart, hoverPrepaintEnd) + '|' + window.hoverLogSegment(hoverPaintStart, window.hoverLogMark());
            final hoverChanged = state.hoverLog != null && state.hoverLog != hover && state.hoverLog.length == hover.length;
            state.hoverLog = hover;
            if (hoverChanged) {
                window.hoverChangedInFrame = true;
            }
            final verification = this.verification;
            // Compared with its cache when its cache was reusable; a view
            // rendered for real for another reason (dirty, moved) is left
            // out of the comparison of the views around it
            final compare = verification != null && verification.compare && !hoverChanged && state.paintOpacity == window.currentElementOpacity();
            window.endVerifyScope(scope, compare, viewName(), stateId);
            if (verification != null) {
                verification.reset();
            }
            #end
            state.paintOpacity = window.currentElementOpacity();
        }
        else {
            if (state.paintOpacity != window.currentElementOpacity()) {
                // An ancestor painted with an opacity that did not show at
                // prepaint (hover dependent): correct it on the next frame.
                window.invalidateViewForNextFrame(entityId);
            }
            recordPaintContext(state, window);
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

    /** Records the context of the view's paint (in place rendering, see `ViewElementState.model`) */
    inline function recordPaintContext(state:ViewElementState, window:Window):Void {
        state.paintContentMask = window.contentMask();
        state.paintTextStyle = window.sharedCurrentTextStyle();
        state.paintImageCache = window.currentImageCache();
        state.paintRemSize = window.remSize();
        if (Window.inSharedContext()) {
            state.inSharedContext = true;
        }
    }

    function paintRendered(window:Window, cx:App):Void {
        window.beginRenderedView(view, false);
        try {
            rendered.paint(window, cx);
        }
        catch (e:haxe.Exception) {
            window.endRenderedView();
            throw glaze.util.Exceptions.rethrow(e);
        }
        window.endRenderedView();
    }

}

/**
 * The render of a view made by an in place rendering that gave way to a
 * full frame in the same draw (see `Window`): the full frame takes it
 * instead of rendering the view a second time.
 */
@:allow(glaze)
class PreRenderedView {

    public var viewId:Int = -1;
    public var stateId:Null<GlobalElementId> = null;
    public var rendered:Null<AnyElement> = null;
    public var layoutId:LayoutId = 0;
    public var layoutNodes:Null<Array<Int>> = null;
    public var layoutTextStyle:Null<TextStyle> = null;
    public var layoutAccessedStart:Int = 0;
    public var layoutAccessedEnd:Int = 0;
    public var layoutAccessedStartTime:Float = 0;
    public var layoutAccessedEndTime:Float = 0;
    /** The view elements that requested their layout inside it (see `Window.amendLayoutElements`) */
    public var nested:Null<Array<ViewElement>> = null;

    public function new() {}

}
