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
        return interactivity.requestLayout(globalId, #if glaze_inspector inspectorId, #end window, cx, (style, window, cx) -> {
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

    function new(visual:ceramic.Visual) {
        this.visual = visual;
    }

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

        final fit = element.fitValue;
        if (!native && fit != null && visual.width > 0 && visual.height > 0) {
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
