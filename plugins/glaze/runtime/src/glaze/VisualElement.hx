// New code for the Haxe port of GPUI (no GPUI origin): shows a Ceramic visual
// as an element of a Glaze window. See NOTICE.md.
package glaze;

import ceramic.Filter;
import glaze.Listeners;
import ceramic.TextureFilter;
import ceramic.TextureTilePacker;

/**
 * How the content of a `visual()` element is rendered into its texture.
 */
enum abstract VisualRenderMode(Int) {

    /**
     * The visual is rendered at every Ceramic frame (an animation, a game):
     * the window draws the element's rectangle again at every frame, and
     * nothing else.
     */
    var Always = 0;

    /**
     * The visual is rendered when the element is first shown or resized, and
     * on `VisualElement.renderNow(visual)` (static content): no cost while
     * nothing changes.
     */
    var Explicit = 1;

}

/**
 * An element showing a Ceramic `Visual` (a quad, a mesh, text, Spine, a
 * whole sub scene, a game) as a part of a Glaze window. Create one with
 * `Prelude.visual(v)`. Specific to the Haxe port (GPUI has no equivalent).
 *
 * The element is sized by the flex layout like any `Styled` element
 * (without a size, it takes the size of the visual). The visual is
 * reparented into the content of a Ceramic `Filter` that renders it into a
 * texture at the window's scale factor, and the window shows that texture
 * as an image primitive in place of the element: it is drawn in order with
 * the other elements (a popover, a menu or a dialog goes over it), clipped
 * by scrolling containers, with the element's corner radii and opacity.
 * Small visuals share an atlas of render textures (`TextureTilePacker`),
 * large ones get their own texture.
 *
 * - Computed size: a Ceramic `View` (plugin `ui`) measures itself: the
 *   element is a measured leaf of the layout that asks the view its size
 *   with `computeSize` (an `ImageView` takes the size of its texture, a
 *   `TextView` wraps in the width it is given, a `LinearLayout` takes the
 *   size of its children), the view is resized to the element and laid out
 *   in the same frame, and the element is laid out again when the content
 *   of the view changes size. Sizes that depend on the parent belong to the
 *   Glaze style (`flex1()`, `wFull()`), not to `ViewSize.fill()` or
 *   `ViewSize.percent()`. Any other visual keeps its own size, or computes
 *   it with `measure(fn)`. See "Computed sizes" in the README.
 * - Size: the content area is the element's size (rounded to device
 *   pixels). `onResize(width, height)` is called when it changes, to lay
 *   out the visual; with `fit()`, the visual is scaled and placed in the
 *   area with that `ObjectFit` (from its own `width` and `height`), like an
 *   image. With `nativeResolution()`, the visual is rendered at its own
 *   size and the texture is scaled into the element (pixel art with
 *   `textureFilter(NEAREST)`, or a game at its native resolution).
 * - Rendering: `renderMode(Always)` (default) renders the visual at every
 *   frame, `renderMode(Explicit)` only when shown, resized or on
 *   `VisualElement.renderNow(visual)`. The window draws only the element's
 *   rectangle again when the texture changed: no view renders again.
 * - Pointer: with `interactive(true)` (default), Ceramic pointer events
 *   (`onPointerDown`, `onPointerOver`...) reach the visuals of the content,
 *   with their local coordinates, through an invisible hit visual placed
 *   over the element (the filter's `hitVisual`), only where no Glaze element
 *   drawn over it blocks the mouse in the last drawn frame, and inside its
 *   content mask: a Glaze popover or dialog over it, or a part scrolled out
 *   of view, receives nothing. The element blocks the mouse
 *   for the Glaze elements behind it (scroll wheel excepted, so scrolling
 *   containers still scroll).
 * - Keyboard: Ceramic keys are global. `trackFocus(handle)` gives the
 *   element a Glaze focus handle, focused when the content is clicked: read
 *   `VisualElement.isFocused(visual)` (or `handle.isFocused(window)`) to
 *   know whether the visual should react to keys. `isHovered(visual)` tells
 *   whether the pointer is over it.
 * - Lifecycle: a visual not shown anymore (its element not drawn in a
 *   frame) is deactivated and detached from the filter, never destroyed.
 *   The filter and the hit visual are kept for `gracePeriodFrames` Ceramic
 *   frames (an element shown again soon reuses them), then destroyed. A
 *   visual is shown by one element at a time.
 *
 * Interactive methods: the common subset of GPUI's `InteractiveElement`
 * (`id`, `hover`, `onClick`, `onMouseDown`, `tooltip`, `trackFocus`...);
 * the others are reachable through `interactivity`.
 */
@:allow(glaze.VisualHost)
class VisualElement extends Element implements Styled {

    /** Ceramic frames a filter is kept after its visual stops being shown */
    public static var gracePeriodFrames:Int = 120;

    /** The interactivity of this element */
    public final interactivity:Interactivity = new Interactivity();

    /** The shown visual */
    public final visual:ceramic.Visual;

    var interactiveValue:Bool = true;

    var renderModeValue:VisualRenderMode = Always;

    var antialiasingValue:Int = 0;

    var textureFilterValue:TextureFilter = LINEAR;

    var nativeResolutionValue:Bool = false;

    var fitValue:Null<ObjectFit> = null;

    var onResizeValue:Null<(Float, Float) -> Void> = null;

    var measureFn:Null<TaffyLayoutEngine.MeasureFn> = null;

    /** Whether the visual is a Ceramic `View` measured by the layout (set by `requestLayout`) */
    var viewMeasured:Bool = false;

    var hitbox:Null<Hitbox> = null;

    var host:Null<VisualHost> = null;

    public function new(visual:ceramic.Visual #if glaze_inspector , ?pos:haxe.PosInfos #end) {
        this.visual = visual;
        #if glaze_inspector
        interactivity.sourceLocation = pos;
        #end
    }

    #if glaze_inspector
    override function sourceLocation():Null<haxe.PosInfos> {
        return interactivity.sourceLocation;
    }
    #end

    public inline function style():StyleRefinement {
        return interactivity.baseStyle;
    }

    /**
     * The id of the element: the one given with `id()`, else one derived
     * from the visual (its state is kept by visual).
     */
    override function elementId():Null<ElementId> {
        final id = interactivity.elementId;
        if (id != null)
            return id;
        return ElementId.NamedInteger('glaze.visual', VisualHost.keyOf(visual));
    }

/// Options (close to `ImGuiVisuals.visual()`)

    /** Whether Ceramic pointer events reach the content (default `true`). */
    public function interactive(interactive:Bool):VisualElement {
        interactiveValue = interactive;
        return this;
    }

    /** `Always` (default) or `Explicit` rendering of the content. */
    public function renderMode(mode:VisualRenderMode):VisualElement {
        renderModeValue = mode;
        return this;
    }

    /** Multisampling of the content's texture (0, 2, 4...; default 0). */
    public function antialiasing(samples:Int):VisualElement {
        antialiasingValue = samples;
        return this;
    }

    /** Filtering of the content's texture (`LINEAR` by default, `NEAREST` for pixel art). */
    public function textureFilter(filter:TextureFilter):VisualElement {
        textureFilterValue = filter;
        return this;
    }

    /**
     * Render the visual at its own size (`width`, `height`) and scale the
     * texture into the element (with `fit()`, `Fill` by default).
     */
    public function nativeResolution(native:Bool = true):VisualElement {
        nativeResolutionValue = native;
        return this;
    }

    /**
     * Fit the visual (its own `width` and `height`) into the element with
     * this `ObjectFit`. Without it, the visual is left where it is in the
     * content area (lay it out from `onResize`).
     */
    public function fit(fit:ObjectFit):VisualElement {
        fitValue = fit;
        return this;
    }

    /**
     * Called with the size of the content area (logical pixels) when it
     * changes, before the visual is rendered at that size.
     */
    public function onResize(listener:(width:Float, height:Float) -> Void):VisualElement {
        onResizeValue = listener;
        return this;
    }

    /**
     * Computes the size of the element with `fn`, like `Canvas.measure()`:
     * the element becomes a measured leaf of the layout. `known` holds, for
     * each axis, the size given by the style or the parent (or `null`), and
     * `available` the space the element can take (`Definite(n)`,
     * `MinContent` or `MaxContent`). It replaces the default size (the
     * visual's own size, or what a Ceramic `View` computes).
     *
     * ```haxe
     * visual(particles).measure((known, available, window, cx) -> size(px(known.width ?? 120.), px(80.)))
     * ```
     */
    public function measure(fn:TaffyLayoutEngine.MeasureFn):VisualElement {
        measureFn = fn;
        return this;
    }

/// InteractiveElement subset

    public function id(id:ElementIdArg):VisualElement {
        interactivity.elementId = id;
        return this;
    }

    public function group(group:String):VisualElement {
        interactivity.group = group;
        return this;
    }

    public function hover(f:(StyleBuilder) -> StyleBuilder):VisualElement {
        interactivity.hoverStyle = StyleBuilder.build(f);
        return this;
    }

    public function onMouseDown(button:MouseButton, listener:MouseDownListener):VisualElement {
        interactivity.onMouseDown(button, listener);
        return this;
    }

    public function onMouseUp(button:MouseButton, listener:MouseUpListener):VisualElement {
        interactivity.onMouseUp(button, listener);
        return this;
    }

    public function onClick(listener:ClickListener):VisualElement {
        interactivity.onClick(listener);
        return this;
    }

    public function onHover(listener:HoverListener):VisualElement {
        interactivity.onHover(listener);
        return this;
    }

    public function tooltip(buildTooltip:(Window, App) -> AnyView):VisualElement {
        interactivity.tooltip(buildTooltip);
        return this;
    }

    /** Track the focus of this element with `handle`: a click in the content focuses it. */
    public function trackFocus(handle:FocusHandle):VisualElement {
        interactivity.trackedFocusHandle = handle;
        return this;
    }

/// Static API (by visual)

    /**
     * Render the content of the element showing `visual` at the next frame
     * (`Explicit` mode; `Always` renders anyway). `done` is called once
     * rendered.
     */
    public static function renderNow(visual:ceramic.Visual, ?done:() -> Void):Void {
        final host = VisualHost.hosts.get(visual);
        if (host == null || !host.attached) {
            if (done != null) done();
            return;
        }
        host.render(done);
    }

    /** Whether the pointer is over the element showing `visual` (Glaze hover: blocked by what is over it). */
    public static function isHovered(visual:ceramic.Visual):Bool {
        final host = VisualHost.hosts.get(visual);
        return host != null && host.attached && host.hitbox != null && host.window != null && !host.window.isDestroyed()
            && host.window.isHitboxIdHovered(host.hitbox.id);
    }

    /** Whether the focus handle tracked by the element showing `visual` (`trackFocus`) is focused. */
    public static function isFocused(visual:ceramic.Visual):Bool {
        final host = VisualHost.hosts.get(visual);
        return host != null && host.attached && host.focusHandle != null && host.window != null && !host.window.isDestroyed()
            && host.focusHandle.isFocused(host.window);
    }

    /** Width of the content area of the element showing `visual` (0 when not shown). */
    public static function contentWidth(visual:ceramic.Visual):Float {
        final host = VisualHost.hosts.get(visual);
        return host != null ? host.areaWidth : 0;
    }

    /** Height of the content area of the element showing `visual` (0 when not shown). */
    public static function contentHeight(visual:ceramic.Visual):Float {
        final host = VisualHost.hosts.get(visual);
        return host != null ? host.areaHeight : 0;
    }

    /** The visuals shown or kept in their grace period (tests, benchmarks). */
    public static function hostCount():Int {
        return VisualHost.count;
    }

/// Element

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        // When interactive, Glaze elements behind do not get the mouse (scrolling passes)
        if (interactiveValue && interactivity.hitboxBehavior == Normal) {
            interactivity.blockMouseExceptScroll();
        }
        viewMeasured = false;
        return interactivity.requestLayout(globalId, #if glaze_inspector inspectorId, #end window, cx, (style, window, cx) -> {
            final measure = measureFn;
            if (measure != null) {
                return window.requestMeasuredLayout(style, measure);
            }
            #if plugin_ui
            if (!nativeResolutionValue && visual != null && !visual.destroyed && Std.isOfType(visual, ceramic.View)) {
                // A Ceramic view measures itself (`VisualHost.measureView`)
                viewMeasured = true;
                final host = VisualHost.obtainForMeasure(visual);
                host.beginViewMeasures();
                return window.requestMeasuredLayout(style, host.viewMeasure);
            }
            #end
            if (visual != null && !visual.destroyed && (style.sizeWidth == Length.Auto || style.sizeHeight == Length.Auto)) {
                // Like an image: the visual's own size when not given
                interactivity.forgetComputedStyle();
                final width = visual.width;
                final height = visual.height;
                if (style.sizeWidth == Length.Auto) {
                    style.sizeWidth = Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(width)));
                }
                if (style.sizeHeight == Length.Auto) {
                    style.sizeHeight = Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(height)));
                }
            }
            return window.requestLayout(style, null, cx);
        });
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        hitbox = interactivity.prepaint(globalId, #if glaze_inspector inspectorId, #end bounds, bounds.size, window, cx, (_, _, hitbox, window, cx) -> {
            return hitbox;
        });
        host = null;
        if (visual == null || visual.destroyed || globalId == null)
            return;
        final host = window.withElementState(globalId, VisualElementState, (box, window) -> {
            var state = box.value;
            if (state == null) {
                state = new VisualElementState();
                box.value = state;
            }
            final host = VisualHost.obtain(visual);
            if (state.host != null && state.host != host && state.host.owner == state) {
                // Another visual at this id: the previous one is released
                state.host.release();
            }
            state.host = host;
            host.owner = state;
            return host;
        });
        this.host = host;
        // The filter reads and writes its observable `renderTexture`, and
        // `onResize` lays out Ceramic visuals: none of it is a dependency
        // of the view (it would be notified by its own drawing)
        tracker.Autorun.unobserve();
        try {
            host.update(this, bounds, hitbox, window);
        }
        catch (e:haxe.Exception) {
            tracker.Autorun.reobserve();
            throw glaze.util.Exceptions.rethrow(e);
        }
        tracker.Autorun.reobserve();
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final hitbox = this.hitbox;
        this.hitbox = null;
        final host = this.host;
        this.host = null;
        interactivity.paint(globalId, #if glaze_inspector inspectorId, #end bounds, hitbox, window, cx, (style, window, cx) -> {
            if (host == null)
                return;
            final remSize = window.remSize();
            final cornerRadii = new Corners(
                style.cornerRadiusTopLeft.toPixels(remSize),
                style.cornerRadiusTopRight.toPixels(remSize),
                style.cornerRadiusBottomRight.toPixels(remSize),
                style.cornerRadiusBottomLeft.toPixels(remSize)
            );
            host.paint(cornerRadii, window);
        });
    }

}

/**
 * The element state of a `visual()` element: dropped (`Droppable`) when the
 * element is not drawn in a frame, which releases its host.
 */
class VisualElementState implements Droppable {

    public var host:Null<VisualHost> = null;

    public function new() {}

    public function drop():Void {
        final host = this.host;
        this.host = null;
        if (host != null && host.owner == this) {
            host.owner = null;
            host.release();
        }
    }

}

/**
 * The invisible hit visual of a `visual()` element (its filter's
 * `hitVisual`), a child of the window's renderable placed over the element:
 * Ceramic routes pointer events through it to the content of the filter,
 * only where no Glaze element over it blocks the mouse (see
 * `Window.isHitboxReachedAt`).
 */
class VisualHitProxy extends ceramic.Quad {

    static final point:ceramic.Point = new ceramic.Point();

    public var host:Null<VisualHost> = null;

    public function new() {
        super();
        transparent = true;
    }

    override function hitTest(x:Float, y:Float, matrix:ceramic.Transform):Bool {
        if (!super.hitTest(x, y, matrix))
            return false;
        final host = this.host;
        return host != null && host.hitsAt(x, y, point);
    }

}

/**
 * What a shown visual uses (by visual, like `ImGuiVisuals` entries): its
 * filter, its hit visual and its settings. Kept during a grace period
 * after the element stops being drawn.
 */
@:allow(glaze.VisualElement)
@:allow(glaze.VisualElementState)
@:allow(glaze.VisualHitProxy)
class VisualHost {

    static final hosts:haxe.ds.ObjectMap<ceramic.Visual, VisualHost> = new haxe.ds.ObjectMap();

    static final keys:haxe.ds.ObjectMap<ceramic.Visual, Int> = new haxe.ds.ObjectMap();

    static var nextKey:Int = 1;

    static var count:Int = 0;

    /** Hosts released, waiting for the end of their grace period */
    static final released:Array<VisualHost> = [];

    static var ticker:Null<ceramic.Entity> = null;

    static var frame:Int = 0;

    /** One shared packer per (antialiasing, filter): texture level settings */
    static final packers:Map<Int, TextureTilePacker> = new Map();

    static inline final PAD_WIDTH:Int = 16;
    static inline final PAD_HEIGHT:Int = 16;
    static inline final MARGIN:Int = 1;

    /** A key for the element id of `visual` (stable while it lives) */
    static function keyOf(visual:ceramic.Visual):Int {
        var key = keys.get(visual);
        if (key == null) {
            key = nextKey++;
            keys.set(visual, key);
            visual.onDestroy(null, _ -> keys.remove(visual));
        }
        return key;
    }

    static function obtain(visual:ceramic.Visual):VisualHost {
        var host = hosts.get(visual);
        if (host == null) {
            host = new VisualHost(visual);
            hosts.set(visual, host);
            count++;
            final created = host;
            visual.onDestroy(null, _ -> {
                if (hosts.get(visual) == created) {
                    created.dispose(false);
                }
            });
        }
        else {
            released.remove(host);
        }
        return host;
    }

    #if plugin_ui
    /**
     * The host of `visual` for a measure, before it is shown: a host created
     * here waits in the released list (disposed after the grace period if
     * the element is never painted).
     */
    static function obtainForMeasure(visual:ceramic.Visual):VisualHost {
        var host = hosts.get(visual);
        if (host == null) {
            host = obtain(visual);
            host.releasedFrame = frame;
            released.push(host);
            ensureTicker();
        }
        return host;
    }
    #end

    static function packer(antialiasing:Int, nearest:Bool):TextureTilePacker {
        final key = antialiasing | (nearest ? 0x10000 : 0);
        var p = packers.get(key);
        if (p == null || p.destroyed) {
            p = new TextureTilePacker(true, -1, -1, PAD_WIDTH, PAD_HEIGHT, MARGIN, antialiasing);
            p.texture.filter = nearest ? NEAREST : LINEAR;
            packers.set(key, p);
        }
        return p;
    }

    /** Largest tile side a shared packer page holds (`TextureTilePacker.allocTile`) */
    static function maxTileSize(isWidth:Bool):Int {
        final textureSize = Std.int(2048 / ceramic.App.app.screen.texturesDensity);
        final pad = isWidth ? PAD_WIDTH : PAD_HEIGHT;
        final padWithMargin = pad + MARGIN * 2;
        var cells = 0;
        var v = MARGIN;
        while (v + pad < textureSize) {
            cells++;
            v += padWithMargin;
        }
        return cells * padWithMargin - MARGIN * 2;
    }

    static function ensureTicker():Void {
        if (ticker != null && !ticker.destroyed)
            return;
        final entity = new ceramic.Entity();
        ticker = entity;
        ceramic.App.app.onUpdate(entity, _ -> tick());
    }

    static function tick():Void {
        frame++;
        var i = released.length - 1;
        while (i >= 0) {
            final host = released[i];
            if (frame - host.releasedFrame > VisualElement.gracePeriodFrames) {
                released.splice(i, 1);
                host.dispose(true);
            }
            i--;
        }
    }

    var visual:Null<ceramic.Visual>;

    var filter:Null<Filter> = null;

    var proxy:Null<VisualHitProxy> = null;

    /** The element state showing the visual */
    var owner:Null<VisualElementState> = null;

    var attached:Bool = false;

    var releasedFrame:Int = 0;

    var window:Null<Window> = null;

    var hitbox:Null<Hitbox> = null;

    var focusHandle:Null<FocusHandle> = null;

    var interactive:Bool = true;

    /** Settings of the current filter */
    var dedicated:Bool = false;
    var explicit:Bool = false;
    var antialiasing:Int = 0;
    var nearest:Bool = false;
    var density:Float = 0;

    /** Content area (logical pixels), as given to `onResize` */
    var areaWidth:Float = 0;
    var areaHeight:Float = 0;

    /** Where the texture is shown (window coordinates) */
    var displayX:Float = 0;
    var displayY:Float = 0;
    var displayWidth:Float = 0;
    var displayHeight:Float = 0;

    /** Region of the texture shown (pixels) */
    var tileX:Float = 0;
    var tileY:Float = 0;
    var tileWidth:Float = 0;
    var tileHeight:Float = 0;

    /** Whether an explicit render is due (shown, resized, rebuilt) */
    var renderDue:Bool = false;

    #if plugin_ui
    /** Number of `computeSize` questions asked to measured views (tests) */
    public static var viewMeasureCount:Int = 0;

    /** Number of relayouts requested because a measured view changed size (tests) */
    public static var viewRelayoutCount:Int = 0;

    static inline final MEASURE_FIELDS:Int = 6;

    static inline final MAX_MEASURES:Int = 8;

    /** The measure of the view, given to the layout (one closure per host) */
    var viewMeasure:Null<TaffyLayoutEngine.MeasureFn> = null;

    /** The view whose `layout` event is listened to */
    var boundView:Null<ceramic.View> = null;

    var viewLayoutListener:Null<() -> Void> = null;

    /**
     * The questions of the last Glaze layout and their answers, 6 numbers
     * each: known width and height (NaN when free), available width and
     * height (NaN when not definite), measured width and height.
     */
    final measures:Array<Float> = [];

    /** The Glaze view to notify when the view changes size */
    var viewEntityId:Int = -1;

    /** Result of `computeViewSize()` */
    var measuredWidth:Float = 0;
    var measuredHeight:Float = 0;
    #end

    function new(visual:ceramic.Visual) {
        this.visual = visual;
        #if plugin_ui
        viewMeasure = measureView;
        viewLayoutListener = handleViewLayout;
        #end
    }

    #if plugin_ui
/// Ceramic views measured by the layout

    static function anyLayoutDirty(view:ceramic.View):Bool {
        if (view.layoutDirty)
            return true;
        final subviews = view.subviews;
        if (subviews != null) {
            for (i in 0...subviews.length) {
                if (anyLayoutDirty(subviews[i]))
                    return true;
            }
        }
        return false;
    }

    /** A Glaze layout of the element starts: its questions are recorded again. */
    function beginViewMeasures():Void {
        measures.resize(0);
        final view:ceramic.View = cast visual;
        // A view changed since Ceramic's last layout pass (which empties its
        // cache of computed sizes): nothing cached can be trusted
        if (anyLayoutDirty(view)) {
            view.resetComputedSize(true);
        }
    }

    /**
     * The size of the view for a question of the layout (`MeasureFn`):
     * - a known axis is imposed (parent size, no freedom in the mask);
     * - a free axis gets the natural size (parent 0, flexible), for
     *   `MinContent` like for `MaxContent` (Ceramic has no minimal size);
     * - a free width with `Definite(n)` is like CSS fit-content: the
     *   natural width, or n imposed when the natural width exceeds it (a
     *   `TextView` then wraps in n). The height is left to overflow, like
     *   the height of a Glaze text.
     * - `ViewSize.fill()` or `percent()` on a free axis uses the definite
     *   available space as its parent size.
     */
    function measureView(known:SizeOf<Null<Float>>, available:SizeOf<AvailableSpace>, window:Window, cx:App):Size {
        final visual = this.visual;
        if (visual == null || visual.destroyed)
            return new Size(0, 0);
        final view:ceramic.View = cast visual;
        final knownWidth:Float = known.width != null ? known.width : Math.NaN;
        final knownHeight:Float = known.height != null ? known.height : Math.NaN;
        final availableWidth:Float = switch available.width {
            case Definite(n): n;
            case _: Math.NaN;
        };
        final availableHeight:Float = switch available.height {
            case Definite(n): n;
            case _: Math.NaN;
        };
        // Ceramic's own state, not a dependency of the Glaze view
        tracker.Autorun.unobserve();
        try {
            computeViewSize(view, knownWidth, knownHeight, availableWidth, availableHeight);
        }
        catch (e:haxe.Exception) {
            tracker.Autorun.reobserve();
            throw glaze.util.Exceptions.rethrow(e);
        }
        tracker.Autorun.reobserve();
        recordMeasure(knownWidth, knownHeight, availableWidth, availableHeight, measuredWidth, measuredHeight);
        return new Size(measuredWidth, measuredHeight);
    }

    static inline function sameNumber(a:Float, b:Float):Bool {
        return a == b || (Math.isNaN(a) && Math.isNaN(b));
    }

    function recordMeasure(knownWidth:Float, knownHeight:Float, availableWidth:Float, availableHeight:Float, width:Float, height:Float):Void {
        final measures = this.measures;
        var i = 0;
        while (i < measures.length) {
            if (sameNumber(measures[i], knownWidth) && sameNumber(measures[i + 1], knownHeight)
                && sameNumber(measures[i + 2], availableWidth) && sameNumber(measures[i + 3], availableHeight)) {
                measures[i + 4] = width;
                measures[i + 5] = height;
                return;
            }
            i += MEASURE_FIELDS;
        }
        if (measures.length >= MAX_MEASURES * MEASURE_FIELDS) {
            // The oldest question is forgotten
            measures.splice(0, MEASURE_FIELDS);
        }
        measures.push(knownWidth);
        measures.push(knownHeight);
        measures.push(availableWidth);
        measures.push(availableHeight);
        measures.push(width);
        measures.push(height);
    }

    static inline function dependsOnParent(viewSize:Float):Bool {
        return ceramic.ViewSize.isFill(viewSize) || ceramic.ViewSize.isPercent(viewSize);
    }

    /** Asks the view its size, into `measuredWidth` and `measuredHeight`. */
    function computeViewSize(view:ceramic.View, knownWidth:Float, knownHeight:Float, availableWidth:Float, availableHeight:Float):Void {
        var parentWidth = 0.0;
        var parentHeight = 0.0;
        var mask:Int = 0;
        final freeWidth = Math.isNaN(knownWidth);
        final freeHeight = Math.isNaN(knownHeight);
        if (!freeWidth) {
            parentWidth = knownWidth;
        }
        else if (!Math.isNaN(availableWidth) && dependsOnParent(view.viewWidth)) {
            parentWidth = availableWidth;
        }
        else {
            mask |= ceramic.ViewLayoutMask.FLEXIBLE_WIDTH;
        }
        if (!freeHeight) {
            parentHeight = knownHeight;
        }
        else if (!Math.isNaN(availableHeight) && dependsOnParent(view.viewHeight)) {
            parentHeight = availableHeight;
        }
        else {
            mask |= ceramic.ViewLayoutMask.FLEXIBLE_HEIGHT;
        }
        viewMeasureCount++;
        view.computeSizeIfNeeded(parentWidth, parentHeight, mask, true);
        var width = view.computedSize.computedWidth;
        var height = view.computedSize.computedHeight;
        if ((mask & ceramic.ViewLayoutMask.FLEXIBLE_WIDTH) != 0 && !Math.isNaN(availableWidth) && width > availableWidth) {
            // Does not fit: the available width imposed
            parentWidth = availableWidth;
            mask &= ~(ceramic.ViewLayoutMask.FLEXIBLE_WIDTH : Int);
            viewMeasureCount++;
            view.computeSizeIfNeeded(parentWidth, parentHeight, mask, true);
            width = view.computedSize.computedWidth;
            height = view.computedSize.computedHeight;
        }
        measuredWidth = freeWidth ? width : knownWidth;
        measuredHeight = freeHeight ? height : knownHeight;
    }

    /** Listens to the `layout` event of the measured view (prepaint). */
    function bindViewLayout(view:ceramic.View):Void {
        if (boundView == view)
            return;
        unbindViewLayout();
        boundView = view;
        view.onLayout(null, viewLayoutListener);
    }

    function unbindViewLayout():Void {
        final view = boundView;
        if (view == null)
            return;
        boundView = null;
        if (!view.destroyed) {
            view.offLayout(viewLayoutListener);
        }
    }

    /** Gives the view the size of the element and lays out its content in this frame. */
    function placeView(view:ceramic.View):Void {
        // Like a parent view does for its child: the size computed for the
        // final size is the current one (a `TextView` lays out its text from it)
        view.computeSizeIfNeeded(areaWidth, areaHeight, ceramic.ViewLayoutMask.FIXED, true);
        view.size(areaWidth, areaHeight);
        // Ceramic's layout system ran before Glaze in this frame: the pass
        // runs again when immediate callbacks are flushed, before drawing
        ceramic.View.requestLayout();
    }

    /**
     * Ceramic laid out the view (its content changed, or after a Glaze
     * layout, whose measures and final size make the view dirty): the
     * questions of the last Glaze layout are asked again, and the Glaze view
     * is notified only if an answer changed.
     */
    function handleViewLayout():Void {
        final view = boundView;
        if (view == null || view.destroyed || !attached)
            return;
        final measures = this.measures;
        var changed = false;
        var i = 0;
        while (i < measures.length) {
            computeViewSize(view, measures[i], measures[i + 1], measures[i + 2], measures[i + 3]);
            if (measuredWidth != measures[i + 4] || measuredHeight != measures[i + 5]) {
                changed = true;
                break;
            }
            i += MEASURE_FIELDS;
        }
        // The size computed for the final size is the current one again
        view.computeSizeIfNeeded(areaWidth, areaHeight, ceramic.ViewLayoutMask.FIXED, true);
        if (changed) {
            // Asked again by the Glaze layout to come
            measures.resize(0);
            viewRelayoutCount++;
            final window = this.window;
            if (window != null && !window.isDestroyed()) {
                if (viewEntityId >= 0) {
                    window.app.notify(viewEntityId);
                }
                else {
                    window.refresh();
                }
            }
        }
    }
    #end

    /** Shows the visual in `element` at `bounds` of `window` (prepaint). */
    function update(element:VisualElement, bounds:Bounds, hitbox:Null<Hitbox>, window:Window):Void {
        final visual = this.visual;
        if (visual == null || visual.destroyed)
            return;

        this.window = window;
        this.hitbox = hitbox;
        this.interactive = element.interactiveValue;
        this.focusHandle = element.interactivity.trackedFocusHandle;

        final scale = window.scaleFactor();
        final native = element.nativeResolutionValue;

        #if plugin_ui
        final measuredView:Null<ceramic.View> = element.viewMeasured ? cast visual : null;
        if (measuredView != null) {
            viewEntityId = window.renderedViewId();
            bindViewLayout(measuredView);
        }
        else {
            unbindViewLayout();
        }
        #end

        // Content area: the element in device pixels, or the visual's own size
        var areaWidth:Float;
        var areaHeight:Float;
        var pixelWidth:Float;
        var pixelHeight:Float;
        if (native) {
            areaWidth = Math.max(1, Math.ceil(visual.width));
            areaHeight = Math.max(1, Math.ceil(visual.height));
            pixelWidth = Math.round(areaWidth * scale);
            pixelHeight = Math.round(areaHeight * scale);
            final fit = element.fitValue != null ? element.fitValue : ObjectFit.Fill;
            final shown = fit.getBounds(bounds, new Size(areaWidth, areaHeight));
            displayX = shown.origin.x;
            displayY = shown.origin.y;
            displayWidth = shown.size.width;
            displayHeight = shown.size.height;
        }
        else {
            final left = TaffyLayoutEngine.roundToDevicePixel(bounds.origin.x, scale);
            final top = TaffyLayoutEngine.roundToDevicePixel(bounds.origin.y, scale);
            pixelWidth = Math.max(TaffyLayoutEngine.roundToDevicePixel(bounds.origin.x + bounds.size.width, scale) - left, 0);
            pixelHeight = Math.max(TaffyLayoutEngine.roundToDevicePixel(bounds.origin.y + bounds.size.height, scale) - top, 0);
            areaWidth = pixelWidth / scale;
            areaHeight = pixelHeight / scale;
            displayX = bounds.origin.x;
            displayY = bounds.origin.y;
            displayWidth = bounds.size.width;
            displayHeight = bounds.size.height;
        }

        if (pixelWidth <= 0 || pixelHeight <= 0) {
            tileWidth = 0;
            tileHeight = 0;
            detach();
            return;
        }

        final explicit = element.renderModeValue == Explicit;
        final nearest = element.textureFilterValue == NEAREST;
        final antialiasing = element.antialiasingValue;
        final filterWidth = Math.ceil(areaWidth);
        final filterHeight = Math.ceil(areaHeight);
        // The shared atlas: rendered at every frame, at the screen's texture density
        final dedicated = explicit
            || scale != ceramic.App.app.screen.texturesDensity
            || filterWidth > maxTileSize(true)
            || filterHeight > maxTileSize(false);

        if (filter != null && (dedicated != this.dedicated || explicit != this.explicit || antialiasing != this.antialiasing
            || nearest != this.nearest || (dedicated && scale != density))) {
            destroyFilter();
        }

        var resized = areaWidth != this.areaWidth || areaHeight != this.areaHeight;
        if (filter == null) {
            createFilter(dedicated, explicit, antialiasing, nearest, scale);
            resized = true;
        }
        this.areaWidth = areaWidth;
        this.areaHeight = areaHeight;

        attach();

        if (resized) {
            final listener = element.onResizeValue;
            if (listener != null) listener(areaWidth, areaHeight);
            renderDue = true;
        }

        #if plugin_ui
        if (measuredView != null) {
            placeView(measuredView);
        }
        #end

        final fit = element.fitValue;
        if (!native && fit != null #if plugin_ui && measuredView == null #end && visual.width > 0 && visual.height > 0) {
            // The visual fitted into the area, like an image
            final placed = fit.getBounds(new Bounds(new Point(0, 0), new Size(areaWidth, areaHeight)), new Size(visual.width, visual.height));
            final scaleX = placed.size.width / visual.width;
            final scaleY = placed.size.height / visual.height;
            visual.scale(scaleX, scaleY);
            visual.pos(placed.origin.x + visual.anchorX * placed.size.width, placed.origin.y + visual.anchorY * placed.size.height);
        }

        if (filter.width != filterWidth || filter.height != filterHeight) {
            filter.size(filterWidth, filterHeight);
        }
        if (filter.contentDirty) {
            filter.computeContent();
        }
        final texture = @:privateAccess filter.unobservedRenderTexture;
        if (texture == null) {
            tileWidth = 0;
            tileHeight = 0;
            return;
        }
        final tile = filter.textureTile;
        final tileOffsetX = tile != null ? tile.frameX : 0.0;
        final tileOffsetY = tile != null ? tile.frameY : 0.0;
        tileX = tileOffsetX * texture.density;
        tileY = tileOffsetY * texture.density;
        tileWidth = pixelWidth;
        tileHeight = pixelHeight;

        if (renderDue && explicit) {
            renderDue = false;
            filter.render();
        }
        renderDue = false;

        // The hit visual maps the texture's coordinates (tile offset
        // included) to the element in the renderable (window coordinates)
        final scaleX = displayWidth / areaWidth;
        final scaleY = displayHeight / areaHeight;
        ensureProxy();
        final proxy = this.proxy;
        if (proxy.parent != window.renderable) {
            window.renderable.add(proxy);
        }
        proxy.pos(displayX - tileOffsetX * scaleX, displayY - tileOffsetY * scaleY);
        proxy.scale(scaleX, scaleY);
        proxy.size(tileOffsetX + areaWidth, tileOffsetY + areaHeight);
        proxy.touchable = interactive;
        filter.touchable = interactive;
    }

    /** Paints the texture (paint). */
    function paint(cornerRadii:Corners, window:Window):Void {
        if (filter == null || tileWidth <= 0 || tileHeight <= 0)
            return;
        final texture = @:privateAccess filter.unobservedRenderTexture;
        if (texture == null)
            return;
        window.paintTexture(new Bounds(new Point(displayX, displayY), new Size(displayWidth, displayHeight)), cornerRadii, texture, tileX, tileY, tileWidth, tileHeight);
    }

    /** Whether the content is hit at screen `x, y` (`VisualHitProxy`). */
    function hitsAt(x:Float, y:Float, point:ceramic.Point):Bool {
        final window = this.window;
        final hitbox = this.hitbox;
        if (!attached || !interactive || window == null || hitbox == null || window.isDestroyed())
            return false;
        window.renderable.screenToVisual(x, y, point);
        final px = point.x;
        final py = point.y;
        if (px < displayX || px >= displayX + displayWidth || py < displayY || py >= displayY + displayHeight)
            return false;
        return window.isHitboxReachedAt(hitbox, px, py);
    }

    function render(?done:() -> Void):Void {
        if (filter == null || !explicit) {
            if (done != null) done();
            return;
        }
        if (done != null) {
            filter.render(() -> done());
        }
        else {
            filter.render();
        }
    }

    function createFilter(dedicated:Bool, explicit:Bool, antialiasing:Int, nearest:Bool, scale:Float):Void {
        final filter = new Filter();
        if (!dedicated) {
            filter.textureTilePacker = packer(antialiasing, nearest);
        }
        else {
            filter.antialiasing = antialiasing;
            filter.textureFilter = nearest ? NEAREST : LINEAR;
            filter.density = scale;
            // No depth or stencil buffer needed by most content: Ceramic's defaults kept
        }
        if (explicit) {
            // Rendered on `render()` only (it marks the texture dirty)
            filter.autoRender = false;
            filter.explicitRender = true;
        }
        filter.touchable = false;
        // Mounted for the content to render into its texture, never drawn
        // itself: the window shows the texture
        filter.transparent = true;
        ceramic.App.app.screen.add(filter);
        this.filter = filter;
        this.dedicated = dedicated;
        this.explicit = explicit;
        this.antialiasing = antialiasing;
        this.nearest = nearest;
        this.density = scale;

        ensureProxy();
        attached = false;
    }

    /**
     * Creates the hit visual if needed (it is destroyed with the renderable
     * of a closed window) and makes it the filter's `hitVisual`.
     */
    function ensureProxy():Void {
        if (proxy == null || proxy.destroyed) {
            proxy = new VisualHitProxy();
            proxy.host = this;
            proxy.touchable = false;
        }
        if (filter != null && filter.hitVisual != proxy) {
            filter.hitVisual = proxy;
        }
    }

    function destroyFilter():Void {
        detach();
        if (filter != null) {
            filter.destroy();
            filter = null;
        }
    }

    /** Reparents the visual into the filter's content. */
    function attach():Void {
        final visual = this.visual;
        if (filter == null || visual == null || visual.destroyed)
            return;
        filter.active = true;
        if (proxy != null && !proxy.destroyed) proxy.active = true;
        if (!attached || visual.parent != filter.content) {
            if (visual.parent != null && visual.parent != filter.content) {
                visual.parent.remove(visual);
            }
            if (visual.parent != filter.content) {
                filter.content.add(visual);
            }
            visual.active = true;
            attached = true;
            renderDue = true;
        }
    }

    /** Detaches and deactivates the visual, pauses the filter. */
    function detach():Void {
        final visual = this.visual;
        if (attached) {
            if (visual != null && !visual.destroyed && filter != null && visual.parent == filter.content) {
                filter.content.remove(visual);
                visual.active = false;
            }
            attached = false;
        }
        if (filter != null) {
            filter.active = false;
            filter.touchable = false;
        }
        if (proxy != null && !proxy.destroyed) {
            proxy.touchable = false;
            proxy.active = false;
        }
    }

    /** The element stopped being drawn: detached, kept for the grace period. */
    function release():Void {
        #if plugin_ui
        unbindViewLayout();
        #end
        detach();
        hitbox = null;
        releasedFrame = frame;
        if (released.indexOf(this) == -1) {
            released.push(this);
        }
        ensureTicker();
    }

    /** Destroys the filter and the hit visual. `detachVisual`: `false` when the visual itself is destroyed. */
    function dispose(detachVisual:Bool):Void {
        #if plugin_ui
        unbindViewLayout();
        measures.resize(0);
        #end
        if (detachVisual) detach();
        released.remove(this);
        if (filter != null) {
            filter.destroy();
            filter = null;
        }
        if (proxy != null) {
            proxy.host = null;
            if (!proxy.destroyed) proxy.destroy();
            proxy = null;
        }
        if (visual != null && hosts.get(visual) == this) {
            hosts.remove(visual);
            count--;
        }
        if (owner != null) {
            owner.host = null;
            owner = null;
        }
        visual = null;
        window = null;
        hitbox = null;
    }

}
