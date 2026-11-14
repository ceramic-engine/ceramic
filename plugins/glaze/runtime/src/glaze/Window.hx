// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.util.Stacks;
import glaze.platform.SceneRenderable;
import glaze.TouchGestureRecognizer.RecognizedTouchGesture;
import glaze.scene.Scene;
import haxe.ds.IntMap;
import glaze.TabStopMap.TabStopOperation;

/**
 * Options of a new window.
 */
@:structInit
class WindowOptions {

    /** Logical width of the window (viewport) */
    public var width:Float = 512;

    /** Logical height of the window (viewport) */
    public var height:Float = 512;

    /** Scale factor (device pixels per logical pixel), the screen density when not set */
    public var scaleFactor:Null<Float> = null;

    /** Size of a rem, in logical pixels */
    public var remSize:Float = 16;

    /** Draw automatically from the `GlazeSystem` when the window is dirty */
    public var autoDraw:Bool = true;

    /** Whether the window starts active (focused at the platform level) */
    public var active:Bool = true;

    /** Route Ceramic input (mouse, keyboard) to this window, see `GlazeInput` */
    public var bindInput:Bool = true;

    /**
     * The sprite atlas (glyphs, SVGs, images). By default a new
     * `CeramicAtlas` whose textures are given to the renderable.
     */
    public var atlas:Null<PlatformAtlas> = null;

    /**
     * Whether views are cached by default (see `ViewElement`), when not set:
     * `Window.defaultViewCaching`.
     */
    public var viewCaching:Null<Bool> = null;

    /** Whether the user can resize the window (GPUI `WindowOptions::is_resizable`) */
    public var isResizable:Bool = true;

    /** Whether the user can minimize the window (GPUI `WindowOptions::is_minimizable`) */
    public var isMinimizable:Bool = true;

    /**
     * Whether the renderable draws the scene into a render texture, only when
     * it changed (see `SceneRenderable.renderToTexture`), when not set:
     * `SceneRenderable.defaultRenderToTexture`.
     */
    public var renderToTexture:Null<Bool> = null;

}

/**
 * The state of a piece of element state, kept across frames by
 * `Window.withElementState()`. `value` is `null` the first time.
 */
class ElementStateBox<S> {

    public var value:Null<S> = null;

    /** The path of the element (Rust's `GlobalElementId` of the key) */
    @:allow(glaze)
    final node:GlobalElementId;

    /** The id of the state type (Rust's `TypeId` of the key, see `ElementStateType`) */
    @:allow(glaze)
    final typeId:Int;

    /** Mark of the in place rendering that saw this box last (see `Window.amendView`) */
    @:allow(glaze)
    var inPlaceMark:Int = 0;

    /** The frame whose element states hold this box (the box moves to the next frame when accessed) */
    @:allow(glaze)
    var owner:Frame;

    @:allow(glaze)
    function new(node:GlobalElementId, typeId:Int, owner:Frame) {
        this.node = node;
        this.typeId = typeId;
        this.owner = owner;
    }

}

/**
 * The model created by `Window.useState()` / `useKeyedState()`: a small
 * entity holding an observable value. Reading `value` during render
 * subscribes the view, writing it from a handler draws the view again.
 */
class StateModel<T> extends Model {

    @observe public var value:T;

    public function new(value:T) {
        super();
        this.value = value;
    }

    /**
     * GPUI drops a keyed state entity with its value; a dropped focus handle
     * is released, so a window focused on it reports no focus anymore
     * (`Window::focused` is `None`). Port focus handles are never released:
     * the windows focused on a dropped state's handle forget it here.
     */
    override function destroy() {
        final value:Dynamic = this.value;
        if (value != null && Std.isOfType(value, Droppable)) {
            (value : Droppable).drop();
        }
        if (value != null && Std.isOfType(value, FocusHandle)) {
            for (window in Window.windows) {
                if (@:privateAccess window._focus == value) {
                    @:privateAccess window._focus = null;
                }
            }
        }
        super.destroy();
    }

}

/**
 * A mouse listener registered for the next frame (Rust `AnyMouseListener`),
 * called for events of the given kind only.
 */
/**
 * A mouse listener of the next frame (internal: subclasses keep the state of
 * the element listeners in fields instead of closures).
 */
@:noCompletion
@:allow(glaze)
class MouseListenerEntry {

    public final kind:PlatformInputKind;

    public final listener:Null<(event:PlatformInput, phase:DispatchPhase, window:Window, cx:App) -> Void>;

    /**
     * Or an element listener called with `hitbox` (no closure binding the
     * hitbox to the listener per element and per frame)
     */
    public final elementListener:Null<Interactivity.ElementMouseListener>;

    public final hitbox:Null<Hitbox>;

    public function new(kind:PlatformInputKind, listener:Null<(PlatformInput, DispatchPhase, Window, App) -> Void>, elementListener:Null<Interactivity.ElementMouseListener>, hitbox:Null<Hitbox>) {
        this.kind = kind;
        this.listener = listener;
        this.elementListener = elementListener;
        this.hitbox = hitbox;
    }

    public function call(event:PlatformInput, phase:DispatchPhase, window:Window, cx:App):Void {
        if (elementListener != null) {
            elementListener(event, phase, hitbox, window, cx);
        }
        else {
            listener(event, phase, window, cx);
        }
    }

}

/**
 * The hover listener of an element (`Interactivity.paintMouseListeners`):
 * its state in fields instead of a closure capturing it.
 */
private class HoverListenerEntry extends MouseListenerEntry {

    final hoverState:Null<Interactivity.ElementHoverState>;

    final currentView:Int;

    /** The hover state the view was painted with: -1 when not tracked, else 0 or 1 */
    final paintedHovered:Int;

    public function new(hitbox:Hitbox, hoverState:Null<Interactivity.ElementHoverState>, currentView:Int, paintedHovered:Int) {
        super(MouseMove, null, null, hitbox);
        this.hoverState = hoverState;
        this.currentView = currentView;
        this.paintedHovered = paintedHovered;
    }

    override function call(event:PlatformInput, phase:DispatchPhase, window:Window, cx:App):Void {
        final hovered = hitbox.isHovered(window);
        final wasHovered = hoverState != null && hoverState.element;
        if (phase == Capture && hovered != wasHovered) {
            if (hoverState != null) {
                hoverState.element = hovered;
                cx.notify(currentView);
            }
        }
        else if (phase == Capture && paintedHovered != -1 && hovered != (paintedHovered == 1)) {
            cx.notify(currentView);
        }
    }

}

/**
 * A cursor style requested by an element for its hitbox (or for the whole
 * window when `hitboxId == -1`).
 */
@:noCompletion
class CursorStyleRequest {

    public final hitboxId:Int;

    public final style:CursorStyle;

    public function new(hitboxId:Int, style:CursorStyle) {
        this.hitboxId = hitboxId;
        this.style = style;
    }

}

/**
 * A tooltip set by an element for the next frame.
 */
@:noCompletion
class TooltipRequest {

    public final id:Int;

    public final tooltip:AnyTooltip;

    public function new(id:Int, tooltip:AnyTooltip) {
        this.id = id;
        this.tooltip = tooltip;
    }

}

/**
 * The pending keystrokes of a multi-stroke binding, with the focus they were
 * typed in and the timeout after which they are replayed.
 */
private class PendingInput {

    public var keystrokes:Array<Keystroke> = [];

    /** The focus id when the keystrokes were typed, -1 for none */
    public var focus:Int = -1;

    public var timeout:Null<PendingInputTimeout> = null;

    public function new() {}

}

/**
 * The timeout of pending input: running (with its timer) or paused by an entity.
 */
private class PendingInputTimeout {

    public var duration:Float;

    public var remaining:Float;

    /** Running: start time and timer task. Paused: `task == null`. */
    public var startedAt:Float = 0;

    public var task:Null<AnyTask> = null;

    /** The entity that paused the timeout, -1 when running */
    public var pauseOwnerId:Int = -1;

    public var pauseReleaseSubscription:Null<Subscription> = null;

    public function new(duration:Float) {
        this.duration = duration;
        this.remaining = duration;
    }

    public inline function isPaused():Bool {
        return pauseOwnerId != -1;
    }

    public function pause(ownerId:Int, releaseSubscription:Subscription, now:Float):Bool {
        if (isPaused()) {
            releaseSubscription.dispose();
            return false;
        }
        remaining = Math.max(0, remaining - (now - startedAt));
        if (task != null) {
            task.cancel();
            task = null;
        }
        pauseOwnerId = ownerId;
        pauseReleaseSubscription = releaseSubscription;
        return true;
    }

    public function resume(ownerId:Int, startedAt:Float, task:AnyTask):Bool {
        if (isPaused() && pauseOwnerId == ownerId) {
            pauseOwnerId = -1;
            if (pauseReleaseSubscription != null) {
                pauseReleaseSubscription.dispose();
                pauseReleaseSubscription = null;
            }
            this.startedAt = startedAt;
            this.task = task;
            return true;
        }
        task.cancel();
        return false;
    }

    public function resetDuration(duration:Float):Void {
        this.duration = duration;
        this.remaining = duration;
    }

    /** Drops the timeout (Rust: dropping the task and the pause subscription) */
    public function drop():Void {
        if (task != null) {
            task.cancel();
            task = null;
        }
        if (pauseReleaseSubscription != null) {
            pauseReleaseSubscription.dispose();
            pauseReleaseSubscription = null;
        }
    }

}

/**
 * An element whose drawing is deferred until after the main tree (see `Window.deferDraw`).
 */
@:noCompletion
class DeferredDraw {

    public var currentView:Model;

    public var priority:Int;

    public var parentNode:Int;

    /** The element id path at the time of the call (Rust copies the id stack: the port keeps the interned node) */
    public var elementIdNode:GlobalElementId;

    public var textStyleStack:Array<TextStyleRefinement>;

    public var contentMask:Null<ContentMask>;

    public var remSize:Float;

    /** The element to draw, `null` when the draw is reused from the previous frame */
    public var element:Null<AnyElement>;

    public var absoluteOffset:Point;

    public final prepaintStart:PrepaintStateIndex = new PrepaintStateIndex();

    public final prepaintEnd:PrepaintStateIndex = new PrepaintStateIndex();

    /** The in place rendering that prepainted this draw (`Window.amendSerial`), -1 for a full frame */
    public var amendSerial:Int = -1;

    public final paintStart:PaintIndex = new PaintIndex();

    public final paintEnd:PaintIndex = new PaintIndex();

    public function new() {}

}

/**
 * The bounds of the tooltip shown during the last frame.
 */
private class TooltipBounds {

    public final id:Int;

    public final bounds:Bounds;

    public function new(id:Int, bounds:Bounds) {
        this.id = id;
        this.bounds = bounds;
    }

}

private enum abstract InputModality(Int) {
    var Mouse = 0;
    var Keyboard = 1;
    var Touch = 2;
}

/**
 * A window control area and the hitbox of the element that acts as it.
 */
class WindowControlHitbox {

    public final area:WindowControlArea;

    public final hitbox:Hitbox;

    public function new(area:WindowControlArea, hitbox:Hitbox) {
        this.area = area;
        this.hitbox = hitbox;
    }

}

#if glaze_inspector
/**
 * An inspector element path and the next instance id given to an element
 * built at that path (an entry of Rust's `next_inspector_instance_ids`).
 */
class InspectorInstanceCount {

    public final path:InspectorElementId.InspectorElementPath;

    public var count:Int = 0;

    public function new(path:InspectorElementId.InspectorElementPath) {
        this.path = path;
    }

}
#end

private class Frame {

    /** Swapped with the other frame's when a view is rendered in place (the scene is made again) */
    public var scene:Scene = new Scene();

    /**
     * The element state boxes this frame owns (Rust `element_states`, a map
     * by `(GlobalElementId, TypeId)`): the boxes hang on their path node
     * (`GlobalElementId.states`) and record their owner, so this array may
     * still list boxes that moved to the other frame since; `clear()` skips
     * them.
     */
    public final elementStates:Array<ElementStateBox<Dynamic>> = [];

    public final accessedElementStates:Array<ElementStateBox<Dynamic>> = [];

    /**
     * Element states accessed by reused prepaint and paint ranges:
     * `finish()` moves them from the previous frame.
     */
    public final reusedElementStates:Array<ElementStateBox<Dynamic>> = [];

    /** The focused handle when this frame was drawn */
    public var focus:Null<FocusHandle> = null;

    public var windowActive:Bool = false;

    public final mouseListeners:Array<MouseListenerEntry> = [];

    public final dispatchTree:DispatchTree;

    public final hitboxes:Array<Hitbox> = [];

    public final tooltipRequests:Array<TooltipRequest> = [];

    public final cursorStyles:Array<CursorStyleRequest> = [];

    /** The window control areas painted this frame (Rust `window_control_hitboxes`) */
    public final windowControlHitboxes:Array<WindowControlHitbox> = [];

    /** Swapped with the other frame's when a view is rendered in place (the tab order is made again) */
    public var tabStops:TabStopMap = new TabStopMap();

    public final deferredDraws:Array<DeferredDraw> = [];

    /*
     * In place rendering (see `Window.renderInPlace`): the views whose
     * ranges index this frame, and what the frame was drawn with.
     */

    /** The cache states of the views drawn in this frame (`Window.registerViewState`) */
    public final viewStates:Array<ViewElement.ViewElementState> = [];

    /** Number of this frame (0: cleared) */
    public var serial:Int = 0;

    /** Whether a view was drawn without view caching (it renders on every frame) */
    public var hasUncachedViews:Bool = false;

    /** Whether some prepaint state was rolled back (`ListState`'s transactions) */
    public var hadRollback:Bool = false;

    /**
     * Where the deferred draws start and end in the prepaint state and in
     * the paint state of this frame (they are drawn after the tree): what
     * an in place rendering replaces as a whole when the deferred draws
     * come from the views it renders (see `Window.renderInPlace`).
     */
    public final deferredPrepaintStart:PrepaintStateIndex = new PrepaintStateIndex();

    public final deferredPrepaintEnd:PrepaintStateIndex = new PrepaintStateIndex();

    public final deferredPaintStart:PaintIndex = new PaintIndex();

    public final deferredPaintEnd:PaintIndex = new PaintIndex();

    /** Whether a dragged view was drawn after the deferred draws */
    public var hadDrag:Bool = false;

    public var scaleFactor:Float = 0;

    public var remSize:Float = 0;

    public var viewportWidth:Float = 0;

    public var viewportHeight:Float = 0;

    public var rootView:Null<AnyView> = null;

    /** Input handlers registered with `handleInput` (only the last one is used) */
    public final inputHandlers:Array<Null<PlatformInputHandler>> = [];

    /**
     * Every text input painted in the frame, focused or not (port addition,
     * see `Window.textInputRegionAt`).
     */
    public final textInputRegions:Array<TextInputRegion> = [];

    #if glaze_inspector
    /** Next instance id of each inspector element path, by path key (Rust `next_inspector_instance_ids`) */
    public var nextInspectorInstanceIds:Map<String, InspectorInstanceCount> = new Map();

    /** The inspector id of the pickable hitboxes, by hitbox id (Rust `inspector_hitboxes`) */
    public var inspectorHitboxes:Map<Int, InspectorElementId> = new Map();
    #end

    public function new(keymap:Keymap) {
        dispatchTree = new DispatchTree(keymap);
    }

    /**
     * Clears the frame for reuse. Element states still in it were not accessed
     * during the last frame: they are dropped, and models among them destroyed.
     */
    public function clear():Void {
        for (i in 0...elementStates.length) {
            final state = elementStates[i];
            if (state.owner != this) {
                // Moved to the other frame when accessed
                continue;
            }
            dropState(state);
        }
        elementStates.resize(0);
        viewStates.resize(0);
        serial = 0;
        hasUncachedViews = false;
        hadRollback = false;
        hadDrag = false;
        rootView = null;
        accessedElementStates.resize(0);
        reusedElementStates.resize(0);
        scene.clear();
        focus = null;
        mouseListeners.resize(0);
        dispatchTree.clear();
        hitboxes.resize(0);
        tooltipRequests.resize(0);
        cursorStyles.resize(0);
        windowControlHitboxes.resize(0);
        tabStops.clear();
        deferredDraws.resize(0);
        inputHandlers.resize(0);
        textInputRegions.resize(0);

        #if glaze_inspector
        nextInspectorInstanceIds.clear();
        inspectorHitboxes.clear();
        #end
    }

    /**
     * Drops an element state no frame accessed: detached from its path,
     * models destroyed, interactive states disposed.
     */
    public static function dropState(state:ElementStateBox<Dynamic>):Void {
        state.node.removeState(state);
        state.owner = null;
        final value:Dynamic = state.value;
        if (value != null) {
            if (Std.isOfType(value, Model)) {
                (value : Model).destroy();
            }
            else if (Std.isOfType(value, Interactivity.InteractiveElementState)) {
                (value : Interactivity.InteractiveElementState).dispose();
            }
            else if (Std.isOfType(value, Droppable)) {
                (value : Droppable).drop();
            }
        }
    }

    /**
     * Drops the boxes of `elementStates` that moved to the other frame or
     * were dropped (after in place renderings, which only add boxes).
     */
    public function compactElementStates():Void {
        var kept = 0;
        for (i in 0...elementStates.length) {
            final state = elementStates[i];
            if (state.owner == this) {
                elementStates[kept++] = state;
            }
        }
        elementStates.resize(kept);
    }

    /**
     * Moves the element states accessed through reused ranges from the
     * previous frame (Rust `Frame::finish`; other states are moved when
     * accessed), then sorts the scene.
     */
    public function finish(previous:Frame):Void {
        for (i in 0...reusedElementStates.length) {
            final state = reusedElementStates[i];
            if (state.owner == previous) {
                state.owner = this;
                elementStates.push(state);
            }
        }
        reusedElementStates.resize(0);
        scene.finish();
    }

    public function cursorStyle(window:Window):Null<CursorStyle> {
        var style:Null<CursorStyle> = null;
        var i = cursorStyles.length - 1;
        while (i >= 0) {
            final request = cursorStyles[i];
            if (request.hitboxId == -1) {
                return request.style;
            }
            if (style == null && window.isHitboxIdHoveredIgnoringLastInput(request.hitboxId)) {
                style = request.style;
            }
            i--;
        }
        return style;
    }

    public function hitTest(position:Point):HitTest {
        var setHoverHitboxCount = false;
        final hitTest = new HitTest();
        var i = hitboxes.length - 1;
        while (i >= 0) {
            final hitbox = hitboxes[i];
            if (hitbox.bounds.intersectContains(hitbox.contentMask.bounds, position)) {
                hitTest.ids.push(hitbox.id);
                if (!setHoverHitboxCount && hitbox.behavior == BlockMouseExceptScroll) {
                    hitTest.hoverHitboxCount = hitTest.ids.length;
                    setHoverHitboxCount = true;
                }
                if (hitbox.behavior == BlockMouse) {
                    break;
                }
            }
            i--;
        }
        if (!setHoverHitboxCount) {
            hitTest.hoverHitboxCount = hitTest.ids.length;
        }
        return hitTest;
    }

    public function focusPath():Array<Int> {
        return focus != null ? dispatchTree.focusPath(focus.id) : [];
    }

}

/**
 * Holds the state for a specific window: its root view, its layout engine,
 * the scene of the last frame (shown by `renderable`, a Ceramic visual), and
 * the stacks used while drawing (text styles, content masks, offsets...).
 *
 * Drawing (`draw()`) renders the root view, lays out the element tree with
 * taffy, prepaints and paints it into the next frame's scene, then swaps
 * frames. It runs from the `GlazeSystem` in `lateUpdate`, only when the window
 * is dirty: a view whose observed fields changed, `cx.notify()` on a view of
 * the window, `refresh()`... When nothing changed, `renderable` keeps drawing
 * the scene of the previous frame and nothing is rebuilt.
 *
 * Input: `dispatchEvent()` dispatches a `PlatformInput` (mouse events to the
 * hitboxes and mouse listeners of the last frame, capture then bubble; key
 * events along the dispatch tree from the root to the focused element, with
 * multi-stroke key bindings, their pending timeout and action dispatch).
 * `GlazeInput` feeds Ceramic input to the windows.
 *
 * View caching: like GPUI, a view embedded with `.cached(style)` reuses the
 * prepaint and paint of the previous frame (hitboxes, dispatch nodes,
 * listeners, scene paint operations...) while it is not dirty. Unlike GPUI,
 * every view is also cached by default (`viewCaching`, `.uncached()` opts
 * out): its tracker tells exactly when it must render again. A view is dirty
 * when it was notified (`cx.notify()` or a tracker reaction) or when one of
 * its descendants is; `refresh()` redraws every view. See `ViewElement`.
 *
 * Differences with GPUI: no platform window (the window is a Ceramic visual
 * of the given size, `setActive()` stands for platform activation; the
 * platform's text input side is `textInputPlatform` plus the input handler
 * slot of `takeInputHandler()` / `setInputHandler()`), no prompts,
 * inspector or accessibility. Focus handles are stored, not referenced by
 * id. Touch gestures read the executor clock instead of the wall clock.
 */
class Window implements WindowInvalidator {

    static var nextWindowId:Int = 1;

    static final ORIGIN:Point = new Point(0, 0);

    /**
     * Open windows.
     */
    public static final windows:Array<Window> = [];

    /**
     * A unique id of this window.
     */
    public final id:Int;

    /**
     * The app of this window.
     */
    public final app:App;

    /**
     * The Ceramic visual showing the scene of the last frame. Add it to a
     * scene or a visual to display the window.
     */
    public final renderable:SceneRenderable;

    /**
     * Draw automatically from the `GlazeSystem` when dirty.
     */
    public var autoDraw:Bool;

    /**
     * `true` when the window needs to be drawn again.
     */
    public var dirty(default, null):Bool = true;

    /**
     * Number of frames drawn so far.
     */
    public var drawCount(default, null):Int = 0;

    /**
     * Number of views rendered during the last frame.
     */
    public var renderedViewCount(default, null):Int = 0;

    /**
     * Number of cached views reused (not rendered) during the last frame.
     */
    public var reusedViewCount(default, null):Int = 0;

    /**
     * Whether views are cached by default (see `ViewElement`). Views embedded
     * with `.cached(style)` are cached either way.
     */
    public var viewCaching:Bool;

    /**
     * Disables every view cache, `.cached(style)` included (GPUI disables
     * caching this way while the inspector is picking). For tests and debugging.
     */
    public var viewCachingDisabled:Bool = false;

    /**
     * The default of `WindowOptions.viewCaching`.
     */
    public static var defaultViewCaching:Bool = true;

    /**
     * `true` while drawing a frame that must not reuse any cached view
     * (Rust `refreshing`): after `refresh()`, and while a `.cached(style)`
     * view renders its content.
     */
    @:allow(glaze)
    var refreshing:Bool = false;

    var focusMovedWhileDrawing:Bool = false;

    /**
     * `true` while drawing a window that was not dirty (an explicit `draw()`):
     * views cached by default render like GPUI's uncached views, views
     * cached with a style are reused.
     */
    @:allow(glaze)
    var drawingClean:Bool = false;

    /**
     * Views to render in the next frame (Rust: the invalidator's dirty
     * views). The value tells whether the entity was notified (`cx.notify()`,
     * a tracker reaction): the views that read it render again too
     * (`markViewsThatAccessed`). A view that only has to render again
     * (`invalidateViewForNextFrame`, a reader) is recorded with `false`.
     */
    final pendingDirtyViews:IntMap<Bool> = new IntMap();

    /** The keys of `pendingDirtyViews`, iterated without allocating (a map's `keys()` copies them) */
    final pendingDirtyViewIds:Array<Int> = [];

    /**
     * View trackers invalidated outside a draw whose reaction has not run yet
     * (see `viewTrackerInvalidated`).
     */
    final invalidatedTrackers:Array<ViewTracker> = [];

    /** Shared scroll states read by the views cached by default (port, see `ViewDependencies`) */
    @:allow(glaze)
    final viewDependencies:ViewDependencies = new ViewDependencies();

    /** Hitbox ids of the groups being prepainted (see `ViewElement` cache keys) */
    @:allow(glaze)
    final prepaintGroupHitboxes:Array<Int> = [];

    /** Product of the opacities of the elements being prepainted */
    @:allow(glaze)
    var prepaintOpacity:Float = 1.0;

    final scratchPrepaintIndex:PrepaintStateIndex = new PrepaintStateIndex();

    final scratchPaintIndex:PaintIndex = new PaintIndex();

    var root:Null<AnyView> = null;

    var _scaleFactor:Float;

    /**
     * The scale factor the platform window reports (Rust
     * `platform_window.scale_factor()`): fixed by `WindowOptions.scaleFactor`
     * or `setScaleFactor()`, the screen density when null (the window then
     * follows the display, see `handleScreenResize()`).
     */
    var fixedScaleFactor:Null<Float> = null;

    /** Rust `bounds_observers`, called by `boundsChanged()` */
    final boundsObservers:SubscriberSet<(Window, App) -> Bool> = new SubscriberSet();

    var _remSize:Float;

    var _viewportSize:Size;

    /** The content mask of the whole window (`contentMask()` when the stack is empty), rebuilt on resize */
    var windowContentMask:ContentMask;

    final layoutEngine:TaffyLayoutEngine = new TaffyLayoutEngine();

    var renderedFrame:Frame;

    var nextFrame:Frame;

    #if glaze_inspector
    var inspector:Null<Inspector> = null;
    #end

    final textStyleStack:Array<TextStyleRefinement> = [];

    final contentMaskStack:Array<ContentMask> = [];

    final elementOffsetStack:Array<Point> = [];

    /** The root of the interned element id paths of this window (Rust `element_id_stack`, empty) */
    final elementIdRoot:GlobalElementId = GlobalElementId.root();

    /** The interned path of the current element id stack */
    var elementIdNode:GlobalElementId;

    final remSizeOverrideStack:Array<Float> = [];

    final renderedEntityStack:Array<Model> = [];

    /** Image caches of the enclosing `ImageCacheElement`s (the last one is used by `img`) */
    public final imageCacheStack:Array<AnyImageCache> = [];

    var elementOpacity:Float = 1.0;

    final trackers:IntMap<ViewTracker> = new IntMap();

    /** The keys of `trackers`, iterated without allocating (a map's `keys()` copies them) */
    final trackerIds:Array<Int> = [];

    /**
     * For each entity, the views of this window whose last render, prepaint
     * or paint accessed it (the reverse of the trackers' `accessed` sets,
     * kept as the accesses are recorded): a notify of the entity marks them
     * dirty in O(readers), see `markViewsThatAccessed`. A view counts among
     * its own readers (its render leases it).
     */
    final readersByEntity:IntMap<Array<Int>> = new IntMap();

    /** Empty reader lists kept for reuse */
    final readerListPool:Array<Array<Int>> = [];

    /** The view whose accessed set `currentAccessed` is, -1 outside of any view */
    var currentAccessedViewId:Int = -1;

    final accessedViewStack:Array<Int> = [];

    /**
     * The window drawing a frame, whose views record the entities accessed
     * (read, updated or created) while it draws (Rust: `accessed_entities`
     * of the entity map, cleared when a draw starts).
     */
    @:allow(glaze)
    static var accessRecorder:Null<Window> = null;

    /** Where accesses are recorded: the accessed set of the view drawing, or `frameAccessed` */
    @:allow(glaze)
    var currentAccessed:AccessedEntities;

    final accessedStack:Array<AccessedEntities> = [];

    /** Entities accessed during this draw outside of any view (focus listeners...) */
    final frameAccessed:AccessedEntities = new AccessedEntities();

    /**
     * The entities accessed during the last draw (Rust `tracked_entities`):
     * this window is their invalidator in `App` (`window_invalidators_by_entity`).
     */
    var liveEntities:AccessedEntities = new AccessedEntities();

    var nextLiveEntities:AccessedEntities = new AccessedEntities();

    final renderedViews:IntMap<Bool> = new IntMap();

    final dirtyViews:IntMap<Bool> = new IntMap();

    final scratchQuad:PaintQuad = new PaintQuad();

    var drawing:Bool = false;

    var destroyed:Bool = false;

    // Input, hitboxes and focus (step 8 / 9)

    var _active:Bool = true;

    /** Whether the pointer is over the window (set by `GlazeInput`) */
    @:allow(glaze)
    var hovered:Bool = false;

    var _mousePosition:Point = new Point(0, 0);

    var mouseHitTest:HitTest = new HitTest();

    var _modifiers:Modifiers = Modifiers.none();

    var _capslock:Bool = false;

    var lastInputModality:InputModality = Mouse;

    /** The portable recognizer of raw touch input (Rust `touch_gestures`). */
    final touchGestures:TouchGestureRecognizer = new TouchGestureRecognizer(GestureTuning.defaults());

    var _touchPredictionEnabled:Bool = true;

    var longPressTimer:Null<AnyTask> = null;

    /** The entity that claimed the current long press (Rust `long_press_capture`), or -1. */
    var longPressCapture:Int = -1;

    var nextHitboxId:Int = 0;

    var nextTooltipId:Int = 0;

    var tooltipBounds:Null<TooltipBounds> = null;

    var requestedAutoscroll:Null<Bounds> = null;

    var _defaultPrevented:Bool = false;

    /** The hitbox that has captured the pointer, -1 if none */
    var _capturedHitbox:Int = -1;

    /** The focused handle (Rust stores the `FocusId`) */
    var _focus:Null<FocusHandle> = null;

    var focusEnabled:Bool = true;

    /**
     * Incremented every time focus moves. Used to invalidate a pending
     * keyboard activation state when focus changes.
     */
    @:allow(glaze)
    var focusGeneration:Int = 0;

    var focusLostPath:Array<Int> = [];

    final focusListeners:SubscriberSet<(WindowFocusEvent, Window, App) -> Bool> = new SubscriberSet();

    final focusLostListeners:SubscriberSet<(Window, App) -> Bool> = new SubscriberSet();

    final pendingInputObservers:SubscriberSet<(Window, App) -> Bool> = new SubscriberSet();

    final activationObservers:SubscriberSet<(Window, App) -> Bool> = new SubscriberSet();

    final appearanceObservers:SubscriberSet<(Window, App) -> Bool> = new SubscriberSet();

    var pendingInput:Null<PendingInput> = null;

    var pendingModifierModifiers:Modifiers = Modifiers.none();

    var pendingModifierSawOtherInput:Bool = false;

    // Text input (step 11)

    /**
     * The input handler given to the platform after the last draw (Rust: owned by
     * the platform window, `set_input_handler` / `take_input_handler`).
     */
    var platformInputHandler:Null<PlatformInputHandler> = null;

    /**
     * The platform side of text input (Rust `PlatformWindow` text input methods):
     * configuration, text input state changes and IME position. `GlazeInput` sets
     * a `TextInputBridge` driving Ceramic's text editing; `null` ignores them.
     */
    public var textInputPlatform:Null<PlatformTextInput> = null;

    var lastTextInputConfiguration:Null<TextInputConfiguration> = null;

    /** The focus id of the focused element accepting text input, -1 if none */
    var focusedTextInput:Int = -1;

    var nextFrameCallbacks:Array<(Window, App) -> Void> = [];

    var currentCursorStyle:CursorStyle = Arrow;

    // Text, sprites and paths (steps 4 and 10)

    /**
     * The sprite atlas of this window (glyphs, SVGs, images): its textures
     * are the `atlasTextures` of the renderable.
     */
    public final spriteAtlas:PlatformAtlas;

    final windowTextSystem:WindowTextSystem;

    final painter:TextPainter;

    final glyphParams:RenderGlyphParams = new RenderGlyphParams();

    public function new(app:App, ?options:WindowOptions) {
        if (options == null) options = {};
        this.id = nextWindowId++;
        this.app = app;
        this.platformOperations = new glaze.platform.CeramicWindowOperations(this);
        this.autoDraw = options.autoDraw;
        this.viewCaching = options.viewCaching != null ? options.viewCaching : defaultViewCaching;
        fixedScaleFactor = options.scaleFactor;
        _scaleFactor = platformScaleFactor();
        app.textSystem().setLayoutScaleFactor(_scaleFactor);
        _remSize = options.remSize;
        _viewportSize = new Size(options.width, options.height);
        windowContentMask = new ContentMask(new Bounds(new Point(0, 0), _viewportSize));
        _active = options.active;
        _appearance = platformAppearance();
        _isResizable = options.isResizable;
        _isMinimizable = options.isMinimizable;
        renderedFrame = new Frame(app.keymap);
        nextFrame = new Frame(app.keymap);
        elementIdNode = elementIdRoot;

        renderable = new SceneRenderable();
        renderable.size(options.width, options.height);
        renderable.sceneScale = _scaleFactor;
        renderable.scene = renderedFrame.scene;
        if (options.renderToTexture != null) renderable.renderToTexture = options.renderToTexture;

        if (options.atlas != null) {
            spriteAtlas = options.atlas;
        }
        else {
            // The headless backend has no textures: pages stay on the CPU
            final atlas = new glaze.platform.CeramicAtlas(1024, #if headless false #else true #end);
            renderable.atlasTextures = atlas.textures;
            renderable.atlas = atlas;
            atlas.onTexturesChange = () -> renderable.usedTexturesDirty = true;
            renderable.usedTexturesDirty = true;
            spriteAtlas = atlas;
        }
        windowTextSystem = new WindowTextSystem(app.textSystem());
        painter = new TextPainter(nextFrame.scene, spriteAtlas, app.textSystem(), _scaleFactor);
        painter.quadPainter = paintQuad;
        currentAccessed = frameAccessed;

        windows.push(this);
        if (app.onRefreshWindows == null) {
            app.onRefreshWindows = refreshWindowsOf;
        }
        if (autoDraw) {
            GlazeSystem.ensure();
        }
        if (options.bindInput) {
            GlazeInput.bind(this);
        }
        // The platform window reports its new scale factor (Rust `on_resize`
        // callback, wired in `Window::new`): Ceramic emits `resize` when the
        // screen density changes (browser zoom, another display)
        ceramic.App.app.screen.onResize(renderable, handleScreenResize);
        // The platform window reports an appearance change (Rust
        // `on_appearance_changed`, wired in `Window::new`): Ceramic emits
        // `systemAppearanceChange` when the system appearance changes
        ceramic.App.app.screen.onSystemAppearanceChange(renderable, handleSystemAppearanceChange);
    }

    static function refreshWindowsOf(app:App):Void {
        for (window in windows) {
            if (window.app == app) {
                window.refresh();
            }
        }
    }

    /**
     * Opens a window whose root view is `root` (Rust
     * `cx.open_window(options, |window, cx| cx.new(...))`): the builder
     * `(window, cx) -> AnyView`, or directly a component, a `Render` entity
     * or an `AnyView` (see `GlazeRoot`).
     */
    public static function open(app:App, options:Null<WindowOptions>, root:GlazeRoot):Window {
        final window = new Window(app, options);
        final view = root.build(window, app);
        window.initRootComponent(view, app);
        window.root = view;
        // Rust `open_window` defers `appearance_changed` once the root view
        // is built: observers registered while building run once. Without
        // observers it would only read the appearance again, so the port
        // skips it then (no extra effect cycle).
        if (window.appearanceObservers.hasSubscribers(0))
            window.defer(app, (window, cx) -> window.appearanceChanged(cx));
        return window;
    }

    /**
     * Sets the root view of the window.
     */
    public function setRoot(view:AnyView):Void {
        initRootComponent(view, app);
        root = view;
        refresh();
    }

    /**
     * A `Component` as the root view (`new Glaze(Root.component()...)`) is
     * initialized with the window, like a view built by the builder: its
     * `init(window, cx)` runs now, not at the first draw (the kit's `Root`
     * builds its plugins there, which `WindowState.read` needs before).
     * Called before `view` becomes the root, inside one update: the
     * entities `init` creates flush their effects once it returned, like the
     * entities a builder creates under its `cx.newEntity`, and a draw that
     * flush starts does not show a root with its initialization half done.
     */
    function initRootComponent(view:Null<AnyView>, cx:App):Void {
        if (view == null)
            return;
        final model:Model = view;
        if (!Std.isOfType(model, ComponentBuilder.ComponentHost))
            return;
        final host:ComponentBuilder.ComponentHost = cast model;
        @:privateAccess cx.startUpdate();
        try {
            // A host made by `AnyView.fromGlazeComponent` (a builder returning
            // `X.component()`) is an entity of this window's app, like the
            // view a builder creates with `cx.newEntity`
            if (host._slot == null) {
                cx.attachEntity(host);
            }
            host.ensureInit(this, cx);
        }
        catch (e:haxe.Exception) {
            @:privateAccess cx.pendingUpdates--;
            throw glaze.util.Exceptions.rethrow(e);
        }
        @:privateAccess cx.finishUpdate();
    }

    /**
     * The root view of the window.
     */
    public inline function rootView():Null<AnyView> {
        return root;
    }

    /**
     * Closes the window: stops drawing and reacting, destroys the renderable.
     */
    public function destroy():Void {
        if (destroyed)
            return;
        destroyed = true;
        windows.remove(this);
        if (hitRegionsOwner == this) {
            hitRegionsOwner = null;
            ceramic.App.app.screen.setWindowHitRegions([]);
        }
        GlazeInput.unbind(this);
        clearPendingInput();
        for (entityId in trackerIds) {
            trackers.get(entityId).destroy();
        }
        trackers.clear();
        trackerIds.resize(0);
        readersByEntity.clear();
        invalidatedTrackers.resize(0);
        for (entityId in liveEntities.ids) {
            app.removeWindowInvalidator(entityId, id);
        }
        liveEntities.clear();
        nextFrame.clear();
        renderedFrame.clear();
        renderable.destroy();
        if (Std.isOfType(spriteAtlas, glaze.platform.CeramicAtlas)) {
            (cast spriteAtlas : glaze.platform.CeramicAtlas).destroy();
        }
        final root:Null<Model> = this.root;
        this.root = null;
        if (root != null && Std.isOfType(root, ComponentBuilder.ComponentHost)) {
            // A root component (`AnyView.fromGlazeComponent`) belongs to the
            // window: it is destroyed with it, like Rust drops the root view
            root.destroy();
        }
    }

    public inline function isDestroyed():Bool {
        return destroyed;
    }

/// Invalidation

    /**
     * Marks the view of the given entity dirty (called by `App.notify`, which
     * tracker reactions go through too).
     */
    public function invalidateView(entityId:Int, cx:App):Bool {
        addPendingDirtyView(entityId, true);
        // Like GPUI's `WindowInvalidator::invalidate_view`, a view notified
        // while the window draws is recorded for the next frame but does not
        // make the window dirty (otherwise a view that notifies from its own
        // render, like gpui-kit's list syncing its search placeholder, would
        // be drawn again forever by the effect flush), and its observers are
        // not notified (`App.notify` pushes no effect).
        if (!drawing) {
            dirty = true;
            return true;
        }
        addPendingReaders(entityId);
        return false;
    }

    /**
     * An entity notified while the window draws: the views that read it
     * render again like the entity itself, in this frame when they are
     * reached after it (`promotePendingDirtyView`: GPUI's uncached views
     * drawn after the notify show the change), else in the next frame
     * (those drawn before it, like in GPUI, where the notify marks the
     * window's dirty views for the next frame). Between frames the readers
     * are marked when the frame starts (`drawFrame`), from the accessed
     * sets of that moment.
     *
     * The views rendering at that moment are left out: the notify comes
     * from their own render (a view writing the state it draws from, like
     * the kit's inputs pushing their props to their state, or a story
     * filling a command palette every render), which is the render being
     * drawn, like a view notifying itself from its render. A notified model
     * stays pending, so its readers render in the next frame anyway.
     */
    function addPendingReaders(entityId:Int):Void {
        final readers = readersByEntity.get(entityId);
        if (readers == null) {
            return;
        }
        for (i in 0...readers.length) {
            final viewId = readers[i];
            if (viewId != entityId && !isRendering(viewId)) {
                final tracker = trackers.get(viewId);
                if (tracker != null && tracker.defaultCaching) {
                    addPendingDirtyView(viewId);
                }
            }
        }
    }

    /** Whether the view is in one of its phases right now (render, prepaint or paint) */
    inline function isRendering(viewId:Int):Bool {
        var found = false;
        final stack = renderedEntityStack;
        for (i in 0...stack.length) {
            if (stack[i].entityId == viewId) {
                found = true;
                break;
            }
        }
        return found;
    }

    /**
     * Told by a view tracker of this window as soon as it is invalidated (an
     * observable field the view read has changed). The port's views track
     * the fields they read where GPUI renders every uncached view on every
     * frame, so the change has the effect of a `cx.notify()` on the view:
     *
     * - While the window draws, like GPUI's notify during a draw
     *   (`WindowInvalidator::invalidate_view`, window.rs:178-202): the view
     *   renders on the next frame, but no frame is scheduled and nothing
     *   observes it. The reaction is consumed here: the change of a model a
     *   view prepaints or paints from (gpui-kit's resizable panels report
     *   their bounds to their state on every prepaint) would otherwise draw
     *   the window again after every frame.
     * - Except when the view's own render wrote a value it read earlier in
     *   that render (`ViewTracker.rendering`): tracker unbound the view from
     *   everything it read before the write, so until it renders again the
     *   view reacts to nothing. The next frame is scheduled, with the view
     *   dirty, so it renders again (and binds again) right away instead of
     *   staying frozen until something else draws the window. A render
     *   that writes a different value each time still draws forever, and
     *   is what the debug warning of `ViewTracker` reports.
     * - Otherwise, the reaction runs as scheduled by tracker, or at the
     *   latest when the window draws (`reactToInvalidatedTrackers`).
     */
    @:allow(glaze)
    function viewTrackerInvalidated(tracker:ViewTracker):Void {

        if (drawing) {
            @:privateAccess tracker.reacted = true;
            if (tracker.rendering) {
                invalidateViewForNextFrame(tracker.viewId);
            }
            else {
                invalidateView(tracker.viewId, app);
            }
        }
        else {
            invalidatedTrackers.push(tracker);
        }
    }

    /**
     * Runs the reactions of the view trackers invalidated before this draw
     * that tracker has not run yet (the change was made in the update that
     * draws): GPUI's notify is immediate, so the draw that follows it renders
     * the view.
     */
    function reactToInvalidatedTrackers():Void {
        final list = invalidatedTrackers;
        if (list.length == 0)
            return;
        var i = 0;
        while (i < list.length) {
            list[i].run();
            i++;
        }
        list.resize(0);
    }

    /**
     * Schedule this window to be redrawn on the next frame, rendering every
     * view again (cached views included).
     */
    public function refresh():Void {
        // Like GPUI, a refresh requested while drawing is ignored
        if (!drawing) {
            refreshing = true;
            dirty = true;
        }
    }

    /**
     * Marks the given view and its ancestors in the last frame dirty (Rust
     * `mark_view_dirty`): a cached view renders again when one of its
     * descendants must.
     */
    function addPendingDirtyView(viewId:Int, notified:Bool = false):Void {
        if (!pendingDirtyViews.exists(viewId)) {
            pendingDirtyViews.set(viewId, notified);
            pendingDirtyViewIds.push(viewId);
        }
        else if (notified && !pendingDirtyViews.get(viewId)) {
            pendingDirtyViews.set(viewId, true);
        }
        if (amending) {
            amendPendingIds.push(viewId);
        }
    }

    /**
     * `App.notify` of an entity this window has not registered yet, while it
     * draws: recorded like a notify during a draw (the views that accessed
     * it render in the next frame, which is not scheduled).
     */
    @:allow(glaze)
    function entityNotifiedWhileDrawing(entityId:Int):Void {
        if (drawing) {
            addPendingDirtyView(entityId, true);
            addPendingReaders(entityId);
        }
    }

    function markViewDirty(viewId:Int):Void {
        if (collectingDirtyViews) {
            // The views dirty themselves, before in place rendering decides (see `drawFrame`)
            if (!dirtyRootSet.exists(viewId)) {
                dirtyRootSet.set(viewId, true);
                dirtyRootIds.push(viewId);
            }
            return;
        }
        final tree = renderedFrame.dispatchTree;
        var nodeId = tree.viewNodeId(viewId);
        if (nodeId == -1) {
            dirtyViews.set(viewId, true);
            return;
        }
        while (nodeId != -1) {
            final node = tree.node(nodeId);
            final nodeViewId = node.viewId;
            if (nodeViewId != -1) {
                if (dirtyViews.exists(nodeViewId)) {
                    break;
                }
                dirtyViews.set(nodeViewId, true);
            }
            nodeId = node.parent;
        }
    }

    /**
     * Marks dirty the views cached by default that accessed the given
     * notified entity while they were last drawn (read it with `read(cx)`,
     * updated it, created it), whether the entity is a model or itself a
     * view of this window. In GPUI those views are not cached: they render
     * again in the next frame and show what the entity's notify announced.
     * Views cached with a style and the views inside them keep GPUI's rule
     * (only their own notify, or a descendant's, renders them). Costs
     * O(readers) through `readersByEntity`.
     */
    function markViewsThatAccessed(entityId:Int):Void {
        final readers = readersByEntity.get(entityId);
        if (readers == null) {
            return;
        }
        for (i in 0...readers.length) {
            final viewId = readers[i];
            final tracker = trackers.get(viewId);
            if (tracker != null && tracker.defaultCaching) {
                markViewDirty(viewId);
            }
        }
    }

    /**
     * Whether the given view must render during the frame being drawn.
     */
    @:allow(glaze)
    inline function isViewDirty(viewId:Int):Bool {
        return dirtyViews.exists(viewId);
    }

/// Geometry

    /**
     * The scale factor of the display associated with the window.
     */
    public inline function scaleFactor():Float {
        return _scaleFactor;
    }

    /**
     * Fixes the scale factor and redraws (Rust test-support
     * `set_scale_factor`): the window stops following the screen density.
     */
    public function setScaleFactor(scaleFactor:Float):Void {
        fixedScaleFactor = scaleFactor;
        _scaleFactor = scaleFactor;
        app.textSystem().setLayoutScaleFactor(_scaleFactor);
        refresh();
    }

    /**
     * The scale factor of the platform window (Rust
     * `platform_window.scale_factor()`): the fixed one, or the density of
     * the Ceramic screen.
     */
    function platformScaleFactor():Float {
        return fixedScaleFactor != null ? fixedScaleFactor : ceramic.App.app.screen.density;
    }

    /**
     * Ceramic screen resize (size or density). The size of the window comes
     * from `resize()` (its owner lays it out); a new density is a new scale
     * factor of the platform window, which goes through `boundsChanged()`
     * like GPUI's `on_resize` callback.
     */
    function handleScreenResize():Void {
        if (!destroyed && platformScaleFactor() != _scaleFactor) {
            boundsChanged();
        }
    }

    /**
     * Notify the window that its bounds have changed (Rust `bounds_changed`):
     * takes the scale factor of the platform window and the viewport size,
     * redraws everything (`refresh()`), then calls the bounds observers.
     * The next frame is laid out (device pixel snapping), rasterized (glyph
     * and SVG tiles are keyed by device size and scale) and presented at the
     * new scale; the renderable takes the scale of a frame when it shows it.
     */
    public function boundsChanged():Void {
        _scaleFactor = platformScaleFactor();
        app.textSystem().setLayoutScaleFactor(_scaleFactor);
        windowContentMask = new ContentMask(new Bounds(new Point(0, 0), _viewportSize));
        renderable.size(_viewportSize.width, _viewportSize.height);
        refresh();
        boundsObservers.retain(0, callback -> callback(this, app));
    }

    /**
     * The size of the drawable area of the window, in logical pixels.
     */
    public inline function viewportSize():Size {
        return _viewportSize;
    }

    /**
     * Resizes the window (and its renderable), then redraws.
     */
    public function resize(width:Float, height:Float):Void {
        _viewportSize = new Size(width, height);
        boundsChanged();
    }

    /**
     * The size of an em for the base font of the application.
     */
    public function remSize():Pixels {
        return remSizeOverrideStack.length > 0 ? remSizeOverrideStack[remSizeOverrideStack.length - 1] : _remSize;
    }

    /**
     * Sets the size of an em for the base font of the application.
     */
    public function setRemSize(remSize:Pixels):Void {
        _remSize = remSize;
    }

    /**
     * Executes the provided function with the specified rem size.
     */
    public function withRemSize<R>(remSize:Null<Float>, f:(Window) -> R):R {
        if (remSize == null)
            return f(this);
        remSizeOverrideStack.push(remSize);
        final result = f(this);
        Stacks.drop(remSizeOverrideStack);
        return result;
    }

    /**
     * Snaps a value to the device pixel grid.
     */
    public inline function pixelSnap(value:Pixels):Pixels {
        return TaffyLayoutEngine.roundToDevicePixel(value, _scaleFactor) / _scaleFactor;
    }

    /**
     * Snaps bounds to the device pixel grid.
     */
    public inline function pixelSnapBounds(bounds:Bounds):Bounds {
        // `bounds.map(pixelSnap)` without the bound method (Floats boxed per call)
        return new Bounds(
            new Point(pixelSnap(bounds.origin.x), pixelSnap(bounds.origin.y)),
            new Size(pixelSnap(bounds.size.width), pixelSnap(bounds.size.height))
        );
    }

    /**
     * Snaps a point to the device pixel grid.
     */
    public inline function pixelSnapPoint(position:Point):Point {
        return new Point(pixelSnap(position.x), pixelSnap(position.y));
    }

    /**
     * The line height of the current text style.
     */
    public function lineHeight():Pixels {
        return currentTextStyle().lineHeightInPixels(remSize());
    }

/// Drawing

    /**
     * Draws the window if it is dirty. Returns `true` if it was drawn.
     */
    public function drawIfDirty():Bool {
        if (!dirty || destroyed)
            return false;
        draw();
        return true;
    }

    /**
     * Produce a new frame and assign it to the renderable (Rust `Window::draw`).
     * Runs inside an app update, so effects pushed while drawing are flushed at the end.
     */
    public function draw():Void {
        if (drawing || destroyed)
            return;
        reactToInvalidatedTrackers();
        if (accessRecorder == null) {
            // Left unbalanced by a draw that threw
            sharedContextDepth = 0;
        }
        drawing = true;
        drawingClean = !dirty;
        final previousRecorder = accessRecorder;
        accessRecorder = this;
        accessedStack.resize(0);
        accessedViewStack.resize(0);
        currentAccessed = frameAccessed;
        currentAccessedViewId = -1;
        frameAccessed.clear();
        app.startUpdate();
        try {
            drawFrame();
        }
        catch (e:haxe.Exception) {
            accessRecorder = previousRecorder;
            drawing = false;
            drawingClean = false;
            #if glaze_verify_cache
            resetVerifyScopes();
            #end
            AnyElement.clearArena();
            @:privateAccess app.pendingUpdates--;
            throw glaze.util.Exceptions.rethrow(e);
        }
        accessRecorder = previousRecorder;
        drawing = false;
        drawingClean = false;
        // Focus listeners may move focus: draw again to render the new focus
        // state and dispatch the resulting focus events (`refresh` is ignored
        // while drawing, so this happens once the draw phase is over).
        if (focusMovedWhileDrawing) {
            focusMovedWhileDrawing = false;
            refresh();
        }
        publishHitRegions();
        app.finishUpdate();
    }

    function drawFrame():Void {
        // Rust `invalidate_entities`. The views notified since the last
        // frame are collected first (`markViewDirty` while
        // `collectingDirtyViews`): when each of them can render alone, in
        // place, its ancestors do not render (`renderInPlace`); otherwise
        // they are marked dirty with their ancestors, like in GPUI.
        collectingDirtyViews = true;
        final pendingIds = pendingDirtyViewIds;
        for (i in 0...pendingIds.length) {
            final entityId = pendingIds[i];
            if (pendingDirtyViews.get(entityId)) {
                // Notified: the views that read it render again, whether it
                // is a model or a view (a view read by another view's render
                // is a model to that reader: the kit's `InputBaseState` read
                // by its field and its search panel). A view that only
                // renders again (its render wrote what it read) does not
                // render its readers.
                markViewsThatAccessed(entityId);
            }
            markViewDirty(entityId);
        }
        pendingIds.resize(0);
        pendingDirtyViews.clear();
        // Default view caching: views whose scroll states changed render again
        viewDependencies.invalidateChanged(renderedFrame.dispatchTree, this);
        collectingDirtyViews = false;
        // The animation frames requested before this draw (those requested
        // while it draws are for the next one)
        final animated = animationViews;
        animationViews = drawnAnimationViews;
        drawnAnimationViews = animated;
        animationViews.clear();

        if (dirtyRootIds.length > 0 && renderInPlace()) {
            clearDirtyRoots();
            return;
        }
        for (i in 0...dirtyRootIds.length) {
            markViewDirty(dirtyRootIds[i]);
        }
        clearDirtyRoots();
        drawFullFrame(true);
    }

    /** Empties `dirtyRootIds` and `dirtyRootSet` (key by key: `clear()` would allocate the map's table again) */
    function clearDirtyRoots():Void {
        final ids = dirtyRootIds;
        final set = dirtyRootSet;
        for (i in 0...ids.length) {
            set.remove(ids[i]);
        }
        ids.resize(0);
    }

    /**
     * Draws a whole frame: the root renders, then every view that is dirty
     * or cannot be reused. `resetDirty`: false when the draw started as an
     * in place rendering (which reset it already, and may have marked the
     * window dirty for the next frame since).
     */
    function drawFullFrame(resetDirty:Bool):Void {
        if (resetDirty) {
            dirty = false;
        }
        #if glaze_verify_cache
        clearHoverLog();
        #end
        renderedViews.clear();
        renderedViewCount = 0;
        reusedViewCount = 0;
        inPlaceViewCount = 0;
        requestedAutoscroll = null;
        #if glaze_verify_cache
        hoverChangedInFrame = false;
        #end

        restorePlatformInputHandler();

        final frame = nextFrame;
        frame.serial = ++frameSerial;
        frame.scaleFactor = _scaleFactor;
        frame.remSize = _remSize;
        frame.viewportWidth = _viewportSize.width;
        frame.viewportHeight = _viewportSize.height;
        frame.rootView = root;

        if (root != null) {
            drawRoots();
        }
        preRenderedView = null;

        dirtyViews.clear();
        nextFrame.windowActive = _active;

        registerPlatformInputHandler(nextFrame);

        glaze.util.FrameProfiler.begin(glaze.util.FrameProfiler.FINISH);
        layoutEngine.finishFrame();
        windowTextSystem.finishFrame();
        nextFrame.finish(renderedFrame);
        #if glaze_verify_cache
        if (inPlaceOracle) {
            compareInPlaceFrame(renderedFrame, nextFrame);
        }
        #end

        final previousFocusPath = renderedFrame.focusPath();
        final previousWindowActive = renderedFrame.windowActive;
        final previous = renderedFrame;
        renderedFrame = nextFrame;
        nextFrame = previous;
        nextFrame.clear();
        // Dropped states are detached from their id nodes: the trie can be swept
        elementIdRoot.trie.endFrame(elementIdRoot);
        // The scene is in device pixels at the scale it was drawn at: the
        // renderable takes both together, so a frame drawn before a scale
        // change is never shown at the new scale
        renderable.sceneScale = _scaleFactor;
        renderable.scene = renderedFrame.scene;
        var focusBeforeListeners = _focus;

        // Views not rendered (or reused) anymore stop reacting
        final dispatchTree = renderedFrame.dispatchTree;
        final ids = trackerIds;
        var kept = 0;
        for (i in 0...ids.length) {
            final entityId = ids[i];
            if (!renderedViews.exists(entityId) && !dispatchTree.containsView(entityId)) {
                dropTracker(entityId);
            }
            else {
                ids[kept++] = entityId;
            }
        }
        ids.resize(kept);

        AnyElement.clearArena();
        drawCount++;

        focusBeforeListeners = dispatchFocusChanges(previousFocusPath, previousWindowActive, focusBeforeListeners);

        recordEntitiesAccessed();
        resetCursorStyle();
        refreshing = false;
        focusMovedWhileDrawing = _focus != focusBeforeListeners;
        glaze.util.FrameProfiler.end(glaze.util.FrameProfiler.FINISH);
    }

    /**
     * Restores the input handler given to the platform after the last
     * frame into an empty slot of that frame, so that a reused paint range
     * finds it at its index.
     */
    function restorePlatformInputHandler():Void {
        final previousInputHandler = platformInputHandler;
        platformInputHandler = null;
        if (previousInputHandler != null) {
            final handlers = renderedFrame.inputHandlers;
            var slot = handlers.length - 1;
            while (slot >= 0 && handlers[slot] != null) {
                slot--;
            }
            if (slot >= 0) {
                handlers[slot] = previousInputHandler;
            }
            else {
                handlers.push(previousInputHandler);
            }
        }
    }

    /**
     * Registers the input handler requested by the frame with the platform
     * (the last one).
     */
    function registerPlatformInputHandler(frame:Frame):Void {
        var focusedTextInput = -1;
        var handlerIndex = frame.inputHandlers.length - 1;
        while (handlerIndex >= 0) {
            final inputHandler = frame.inputHandlers[handlerIndex];
            if (inputHandler != null) {
                frame.inputHandlers[handlerIndex] = null;
                final acceptsTextInput = inputHandler.acceptsTextInput(this, app);
                platformInputHandler = inputHandler;
                if (acceptsTextInput) {
                    focusedTextInput = focusId();
                }
                break;
            }
            handlerIndex--;
        }
        applyTextInputConfiguration(app);
        final previousTextInput = this.focusedTextInput;
        this.focusedTextInput = focusedTextInput;
        if ((previousTextInput != -1) != (focusedTextInput != -1) && textInputPlatform != null) {
            textInputPlatform.textInputStateChanged(focusedTextInput != -1 ? FocusGained : FocusLost);
        }
    }

    /**
     * Calls the focus listeners when the focus path or the activation
     * changed between the last frame and this one (`previousFocusPath`).
     * Returns the focused handle after the listeners ran when they made the
     * focus path empty (the handle to compare for `focusMovedWhileDrawing`).
     */
    function dispatchFocusChanges(previousFocusPath:Array<Int>, previousWindowActive:Bool, focusBeforeListeners:Null<FocusHandle>):Null<FocusHandle> {
        final currentFocusPath = renderedFrame.focusPath();
        final currentWindowActive = renderedFrame.windowActive;
        if (!samePath(previousFocusPath, currentFocusPath) || previousWindowActive != currentWindowActive) {
            if (previousFocusPath.length > 0 && currentFocusPath.length == 0) {
                focusLostPath = previousFocusPath;
                focusLostListeners.retain(0, listener -> listener(this, app));
                focusLostPath = [];
                focusBeforeListeners = _focus;
            }

            final event = new WindowFocusEvent(
                previousWindowActive ? previousFocusPath : [],
                currentWindowActive ? currentFocusPath : []
            );
            focusListeners.retain(0, listener -> listener(event, this, app));
        }
        return focusBeforeListeners;
    }

    static function samePath(a:Array<Int>, b:Array<Int>):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (a[i] != b[i])
                return false;
        }
        return true;
    }

    function drawRoots():Void {
        tooltipBounds = null;

        // Layout all root elements. Like the root element on the web, which
        // stretches to fill the viewport unless explicitly sized, window roots
        // fill the window when their size is `auto`.
        #if glaze_inspector
        final inspectorWidth:Float = 30.0 * (remSize() : Float);
        final rootSize = inspector != null
            ? new Size(Math.max(_viewportSize.width - inspectorWidth, 0.0), _viewportSize.height)
            : _viewportSize;
        final rootElement = root.intoAnyElement();
        glaze.util.FrameProfiler.begin(glaze.util.FrameProfiler.LAYOUT);
        final rootLayoutId = rootElement.requestLayout(this, app);
        layoutEngine.stretchAutoSizeToFill(rootLayoutId, rootSize, _scaleFactor);
        glaze.util.FrameProfiler.end(glaze.util.FrameProfiler.LAYOUT);
        glaze.util.FrameProfiler.begin(glaze.util.FrameProfiler.PREPAINT);
        rootElement.prepaintAsRoot(
            new Point(0, 0),
            new SizeOf<AvailableSpace>(AvailableSpace.Definite(rootSize.width), AvailableSpace.Definite(rootSize.height)),
            this,
            app
        );

        final inspectorElement = prepaintInspector(inspectorWidth, app);
        #else
        final rootElement = root.intoAnyElement();
        glaze.util.FrameProfiler.begin(glaze.util.FrameProfiler.LAYOUT);
        final rootLayoutId = rootElement.requestLayout(this, app);
        layoutEngine.stretchAutoSizeToFill(rootLayoutId, _viewportSize, _scaleFactor);
        glaze.util.FrameProfiler.end(glaze.util.FrameProfiler.LAYOUT);
        glaze.util.FrameProfiler.begin(glaze.util.FrameProfiler.PREPAINT);
        rootElement.prepaintAsRoot(
            new Point(0, 0),
            new SizeOf<AvailableSpace>(AvailableSpace.Definite(_viewportSize.width), AvailableSpace.Definite(_viewportSize.height)),
            this,
            app
        );
        #end

        prepaintIndexInto(nextFrame.deferredPrepaintStart);
        prepaintDeferredDraws();
        prepaintIndexInto(nextFrame.deferredPrepaintEnd);

        var activeDragElement:Null<AnyElement> = null;
        var tooltipElement:Null<AnyElement> = null;
        final activeDrag = app.activeDrag;
        nextFrame.hadDrag = activeDrag != null;
        if (activeDrag != null) {
            app.activeDrag = null;
            final element = activeDrag.view.intoAnyElement();
            final offset = _mousePosition.sub(activeDrag.cursorOffset);
            element.prepaintAsRoot(offset, minSize(), this, app);
            activeDragElement = element;
            app.activeDrag = activeDrag;
        }
        else {
            tooltipElement = prepaintTooltip();
        }

        mouseHitTest = nextFrame.hitTest(_mousePosition);
        glaze.util.FrameProfiler.end(glaze.util.FrameProfiler.PREPAINT);

        // Now actually paint the elements.
        glaze.util.FrameProfiler.begin(glaze.util.FrameProfiler.PAINT);
        rootElement.paint(this, app);

        #if glaze_inspector
        paintInspector(inspectorElement, app);
        #end

        paintIndexInto(nextFrame.deferredPaintStart);
        paintDeferredDraws();
        paintIndexInto(nextFrame.deferredPaintEnd);

        if (activeDragElement != null) {
            activeDragElement.paint(this, app);
        }
        else if (tooltipElement != null) {
            tooltipElement.paint(this, app);
        }

        #if glaze_inspector
        paintInspectorHitbox(app);
        #end
        glaze.util.FrameProfiler.end(glaze.util.FrameProfiler.PAINT);
    }

    static inline function minSize():SizeOf<AvailableSpace> {
        return new SizeOf<AvailableSpace>(AvailableSpace.MinContent, AvailableSpace.MinContent);
    }

    function prepaintTooltip():Null<AnyElement> {
        var tooltipRequestIndex = nextFrame.tooltipRequests.length - 1;
        while (tooltipRequestIndex >= 0) {
            final tooltipRequest = nextFrame.tooltipRequests[tooltipRequestIndex];
            tooltipRequestIndex--;
            final element = tooltipRequest.tooltip.view.intoAnyElement();
            final mousePosition = tooltipRequest.tooltip.mousePosition;
            final tooltipSize = element.layoutAsRoot(minSize(), this, app);

            var originX:Float = mousePosition.x + 1;
            var originY:Float = mousePosition.y + 1;
            final windowRight = _viewportSize.width;
            final windowBottom = _viewportSize.height;

            if (originX + tooltipSize.width > windowRight) {
                final newX = mousePosition.x - tooltipSize.width - 1;
                if (newX >= 0) {
                    originX = newX;
                }
                else {
                    originX = Math.max(0, originX - (originX + tooltipSize.width) - windowRight);
                }
            }

            if (originY + tooltipSize.height > windowBottom) {
                final newY = mousePosition.y - tooltipSize.height - 1;
                if (newY >= 0) {
                    originY = newY;
                }
                else {
                    originY = Math.max(0, originY - (originY + tooltipSize.height) - windowBottom);
                }
            }

            final tooltipBoundsValue = new Bounds(new Point(originX, originY), tooltipSize);

            // It's possible for an element to have an active tooltip while not being painted (e.g.
            // via the `visible_on_hover` method). Since mouse listeners are not active in this
            // case, instead update the tooltip's visibility here.
            final isVisible = tooltipRequest.tooltip.checkVisibleAndUpdate(tooltipBoundsValue, this, app);
            if (!isVisible) {
                continue;
            }

            pushAbsoluteElementOffset(tooltipBoundsValue.origin);
            element.prepaint(this, app);
            popElementOffset();

            tooltipBounds = new TooltipBounds(tooltipRequest.id, tooltipBoundsValue);
            return element;
        }
        return null;
    }

    /**
     * The scene of the last frame.
     */
    public inline function renderedScene():Scene {
        return renderedFrame.scene;
    }

/// Rendered views and tracker capture

    /**
     * Starts a phase of the given view: pushes it on the rendered entity stack
     * and makes its tracker the current autorun. The first phase of a frame
     * (`requestLayout`, which renders the view) drops the previous
     * dependencies; the next ones keep collecting.
     */
    @:allow(glaze)
    function beginRenderedView(view:Model, firstPhase:Bool):Void {
        final entityId = view.entityId;
        renderedEntityStack.push(view);
        var tracker = trackers.get(entityId);
        if (tracker == null) {
            tracker = new ViewTracker(() -> app.notify(entityId), view);
            tracker.window = this;
            tracker.viewId = entityId;
            trackers.set(entityId, tracker);
            trackerIds.push(entityId);
        }
        if (firstPhase) {
            if (!renderedViews.exists(entityId)) {
                renderedViews.set(entityId, true);
                renderedViewCount++;
                if (amending) {
                    amendRenderedIds.push(entityId);
                }
            }
            if (amending) {
                // What the view accessed before (see `updateLiveEntitiesInPlace`)
                for (accessed in tracker.accessed.ids) {
                    amendOldAccessed.push(accessed);
                }
            }
            // Its accessed set starts again: so do its reader entries
            removeReaders(tracker);
            tracker.beginCapture();
        }
        else {
            tracker.resumeCapture();
        }
        accessedStack.push(currentAccessed);
        accessedViewStack.push(currentAccessedViewId);
        currentAccessed = tracker.accessed;
        currentAccessedViewId = entityId;
    }

    /**
     * Records an access to the given entity while this window draws (Rust
     * `EntityMap::read` / `lease` / `insert` mark the entity accessed).
     */
    @:allow(glaze)
    static inline function recordAccess(entityId:Int):Void {
        final window = accessRecorder;
        if (window != null) {
            window.recordAccessIn(entityId);
        }
    }

    /**
     * `recordAccess` for a model, whose id is only read while a window draws.
     */
    @:allow(glaze)
    static inline function recordModelAccess(model:Model):Void {
        final window = accessRecorder;
        if (window != null) {
            window.recordAccessIn(model.entityId);
        }
    }

    /** Records an access in the current set, and the view as a reader of the entity when the set is a view's */
    inline function recordAccessIn(entityId:Int):Void {
        if (currentAccessed.add(entityId) && currentAccessedViewId != -1) {
            addReader(entityId, currentAccessedViewId);
        }
    }

    /**
     * Records the creation of an entity while this window draws (Rust
     * `EntityMap::insert` marks it accessed): tracked like a read, so that
     * the window is its invalidator, but the creating view is not one of its
     * readers (it did not draw from the entity's state; a list creating its
     * rows while it renders must not render again at their first notify).
     */
    @:allow(glaze)
    static inline function recordCreation(entityId:Int):Void {
        final window = accessRecorder;
        if (window != null) {
            window.currentAccessed.add(entityId);
        }
    }

    function addReader(entityId:Int, viewId:Int):Void {
        var readers = readersByEntity.get(entityId);
        if (readers == null) {
            readers = readerListPool.length > 0 ? readerListPool.pop() : [];
            readersByEntity.set(entityId, readers);
        }
        readers.push(viewId);
    }

    /**
     * Removes the view from the readers of everything its tracker accessed
     * (before its accessed set is cleared by a new render, or when the
     * tracker stops).
     */
    function removeReaders(tracker:ViewTracker):Void {
        final viewId = tracker.viewId;
        for (entityId in tracker.accessed.ids) {
            final readers = readersByEntity.get(entityId);
            if (readers != null) {
                readers.remove(viewId);
                if (readers.length == 0) {
                    readersByEntity.remove(entityId);
                    readerListPool.push(readers);
                }
            }
        }
    }

    /** Stops the tracker of a view that is not drawn anymore (its reader entries with it) */
    function dropTracker(viewId:Int):Void {
        final tracker = trackers.get(viewId);
        if (tracker != null) {
            removeReaders(tracker);
            tracker.destroy();
            trackers.remove(viewId);
        }
    }

    /**
     * Makes this window the invalidator of the entities accessed during the
     * draw (Rust `record_entities_accessed`, after the focus listeners): the
     * views rendered or reused, and the entities their last render, prepaint
     * and paint accessed (a reused cached view keeps them, like Rust's
     * `extend_accessed`), and those accessed outside any view.
     */
    function recordEntitiesAccessed():Void {
        final next = nextLiveEntities;
        for (entityId in trackerIds) {
            next.add(entityId);
            for (accessed in trackers.get(entityId).accessed.ids) {
                next.add(accessed);
            }
        }
        lastFrameAccessed.clear();
        for (accessed in frameAccessed.ids) {
            next.add(accessed);
            lastFrameAccessed.add(accessed);
        }
        frameAccessed.clear();
        final previous = liveEntities;
        for (entityId in previous.ids) {
            if (!next.contains(entityId)) {
                app.removeWindowInvalidator(entityId, id);
            }
        }
        for (entityId in next.ids) {
            if (!previous.contains(entityId)) {
                app.addWindowInvalidator(entityId, id, this);
            }
        }
        previous.clear();
        liveEntities = next;
        nextLiveEntities = previous;
    }

    /**
     * Ends the phase started by `beginRenderedView()`.
     */
    /**
     * Counts a view reused from the cache during this frame.
     */
    @:allow(glaze)
    inline function countReusedView():Void {
        reusedViewCount++;
    }

    @:allow(glaze)
    function endRenderedView():Void {
        final view = renderedEntityStack.pop();
        final tracker = trackers.get(view.entityId);
        if (tracker != null) {
            tracker.endCapture();
        }
        final outer = accessedStack.pop();
        currentAccessed = outer != null ? outer : frameAccessed;
        final outerView = accessedViewStack.pop();
        currentAccessedViewId = outerView != null ? outerView : -1;
    }

    /**
     * Runs `f` as part of the rendering of the given view (Rust
     * `with_rendered_view`): reads of observable fields subscribe the view.
     */
    public function withRenderedView<R>(view:Model, f:(Window) -> R):R {
        beginRenderedView(view, false);
        var result:R;
        try {
            result = f(this);
        }
        catch (e:haxe.Exception) {
            endRenderedView();
            throw glaze.util.Exceptions.rethrow(e);
        }
        endRenderedView();
        return result;
    }

    /**
     * The entity id of the view being drawn (Rust `current_view`).
     */
    public function currentView():Int {
        if (renderedEntityStack.length == 0) {
            throw 'No view is being rendered';
        }
        return renderedEntityStack[renderedEntityStack.length - 1].entityId;
    }

    /**
     * The entity id of the view being drawn, `-1` outside of any view.
     */
    @:allow(glaze)
    inline function renderedViewId():Int {
        final stack = renderedEntityStack;
        return stack.length > 0 ? stack[stack.length - 1].entityId : -1;
    }

    /**
     * `Component.notify()`: the given view, drawn by this window, renders
     * again as if an observable field it read had changed (its tracker is
     * invalidated, the path of a tracked change). Ignored while the view
     * renders (that render is the one being drawn), and when the view or
     * this window is gone.
     */
    @:allow(glaze)
    function notifyRenderedView(viewId:Int):Void {
        if (destroyed || viewId == -1)
            return;
        final tracker = trackers.get(viewId);
        if (tracker == null || tracker.rendering)
            return;
        tracker.invalidate();
    }

    /**
     * The tracker of the given view in this window, if it was rendered.
     */
    public inline function viewTracker(entityId:Int):Null<ViewTracker> {
        return trackers.get(entityId);
    }

/// Layout

    /**
     * Add a node to the layout tree for the current frame. Takes the `Style` of the element for which
     * layout is being requested, along with the layout ids of any children.
     */
    public function requestLayout(style:Style, children:Null<Array<LayoutId>>, cx:App):LayoutId {
        return layoutEngine.requestLayout(style, remSize(), _scaleFactor, children);
    }

    /**
     * `requestLayout()` giving `children` away: the layout node keeps the
     * array (the element may still read it, never change it). Internal.
     */
    @:allow(glaze)
    function requestLayoutOwned(style:Style, children:Array<LayoutId>, cx:App):LayoutId {
        return layoutEngine.requestLayoutWith(style, remSize(), _scaleFactor, children, true);
    }

    /**
     * Add a node to the layout tree for the current frame. Instead of taking a `Style` and children,
     * this variant takes a function that is invoked during layout so you can use arbitrary logic to
     * determine the element's size.
     */
    public function requestMeasuredLayout(style:Style, measure:TaffyLayoutEngine.MeasureFn):LayoutId {
        return layoutEngine.requestMeasuredLayout(style, remSize(), _scaleFactor, measure);
    }

    /** `requestMeasuredLayout()` with the measure as an object (`TextLayout`). Internal. */
    @:allow(glaze)
    function requestMeasuredNode(style:Style, measure:TaffyLayoutEngine.MeasuredNode):LayoutId {
        return layoutEngine.requestMeasuredNode(style, remSize(), _scaleFactor, measure);
    }

    /**
     * Compute the layout for the given id within the given available space.
     */
    public function computeLayout(layoutId:LayoutId, availableSpace:SizeOf<AvailableSpace>, cx:App):Void {
        layoutEngine.computeLayout(layoutId, availableSpace, this, cx);
    }

    /**
     * Obtain the bounds computed for the given LayoutId relative to the window. This method will usually be invoked by
     * GPUI itself automatically in order to pass your element its `Bounds` automatically.
     */
    public function layoutBounds(layoutId:LayoutId):Bounds {
        computeLayoutBounds(layoutId);
        return new Bounds(new Point(layoutBoundsX, layoutBoundsY), layoutBoundsSize);
    }

    // Result of `computeLayoutBounds()`: the bounds of a layout id without a `Bounds`
    @:allow(glaze) var layoutBoundsX:Float = 0;
    @:allow(glaze) var layoutBoundsY:Float = 0;
    @:allow(glaze) var layoutBoundsSize:Size = null;

    /**
     * Computes the bounds of the given `LayoutId` relative to the window into
     * `layoutBoundsX`, `layoutBoundsY` and `layoutBoundsSize` (what
     * `layoutBounds()` returns, without allocating): for callers that only
     * read them.
     */
    @:allow(glaze)
    function computeLayoutBounds(layoutId:LayoutId):Void {
        final engine = layoutEngine;
        engine.computeBounds(layoutId, _scaleFactor);
        final offset = elementOffset();
        // Always add the snapped offset like GPUI does, even when it is zero:
        // `-0.0 + 0.0` is `+0.0`, so skipping it would keep a negative zero
        layoutBoundsX = engine.boundsLeft(layoutId) + pixelSnap(offset.x);
        layoutBoundsY = engine.boundsTop(layoutId) + pixelSnap(offset.y);
        layoutBoundsSize = engine.boundsSize(layoutId);
    }

    /**
     * A `Bounds` of the last `computeLayoutBounds()` result.
     */
    @:allow(glaze)
    inline function computedLayoutBounds():Bounds {
        return new Bounds(new Point(layoutBoundsX, layoutBoundsY), layoutBoundsSize);
    }

/// Element ids and element state

    @:allow(glaze)
    inline function pushElementId(id:ElementId):Void {
        elementIdNode = elementIdNode.child(id);
    }

    @:allow(glaze)
    inline function popElementId():Void {
        elementIdNode = elementIdNode.parent;
    }

    @:allow(glaze)
    function prepareElementId(id:ElementId):GlobalElementId {
        final node = elementIdNode.child(id);
        elementIdNode = node;
        return node;
    }

    /**
     * Push an element id onto the stack, and call a function with that id active.
     */
    public function withId<R>(elementId:ElementIdArg, f:(Window) -> R):R {
        final node = elementIdNode;
        elementIdNode = node.child(elementId);
        final result = f(this);
        elementIdNode = node;
        return result;
    }

    /**
     * Calls the provided function with the `GlobalElementId` of the given element id appended to the current path.
     */
    public function withGlobalId<R>(elementId:ElementIdArg, f:(GlobalElementId, Window) -> R):R {
        final node = elementIdNode;
        final child = node.child(elementId);
        elementIdNode = child;
        final result = f(child, this);
        elementIdNode = node;
        return result;
    }

    /**
     * Provide elements in the called function with a new namespace in which their identifiers must be unique.
     */
    public inline function withElementNamespace<R>(elementId:ElementIdArg, f:(Window) -> R):R {
        return withId(elementId, f);
    }

    /**
     * Updates or initializes state for an element with the given id that lives across multiple
     * frames. The state is in `box.value` (`null` the first time): read it, and assign it before
     * returning. States not accessed during a frame are dropped (models among them destroyed).
     * Rust keys states by type: here `type` is that key.
     */
    public function withElementState<S, R>(globalId:GlobalElementId, type:Class<S>, f:(ElementStateBox<S>, Window) -> R):R {
        final box = elementStateBox(globalId, ElementStateType.of(type));
        return f(cast box, this);
    }

    /**
     * The state box of the given path and state type for this frame, moved
     * from the last frame or created (the state is marked as accessed; Rust
     * `take_element_state` + `insert_element_state`).
     */
    @:allow(glaze)
    function elementStateBox(globalId:GlobalElementId, typeId:Int):ElementStateBox<Dynamic> {
        final next = nextFrame;
        var box = globalId.findState(typeId);
        if (box == null) {
            box = new ElementStateBox<Dynamic>(globalId, typeId, next);
            globalId.addState(box);
            next.elementStates.push(box);
        }
        else if (box.owner != next) {
            // Held by the rendered frame: moved to this one
            box.owner = next;
            next.elementStates.push(box);
        }
        next.accessedElementStates.push(box);
        return box;
    }

    /**
     * The value of the given element state, from this frame or the last
     * one, without accessing it.
     */
    @:allow(glaze)
    function peekElementState(globalId:GlobalElementId, typeId:Int):Dynamic {
        final box = globalId.findState(typeId);
        return box != null ? box.value : null;
    }

    /**
     * Like `withElementState()`, for elements that may have no id: `f` gets
     * `null` instead of a state box when `globalId` is `null`.
     */
    public function withOptionalElementState<S, R>(globalId:Null<GlobalElementId>, type:Class<S>, f:(Null<ElementStateBox<S>>, Window) -> R):R {
        if (globalId != null) {
            return withElementState(globalId, type, f);
        }
        return f(null, this);
    }

    /**
     * Use a piece of state that exists as long this element is being rendered in consecutive frames.
     * The state is a `StateModel` holding an observable value: reading it in render subscribes the
     * view, and the view is also notified when the state entity is notified.
     */
    public function useKeyedState<T>(key:ElementIdArg, cx:App, init:(Window) -> T):Entity<StateModel<T>> {
        final currentView = this.currentView();
        // `withGlobalId(key, ...)` and `withElementState(globalId, StateModel, ...)`
        // without their closures
        final node = elementIdNode;
        final globalId = node.child(key);
        elementIdNode = globalId;
        final state = elementStateBox(globalId, ElementStateType.of(StateModel));
        var result:Entity<StateModel<T>>;
        if (state.value != null) {
            result = (cast state.value : Entity<StateModel<T>>);
        }
        else {
            final initial = init(this);
            final newState:Entity<StateModel<T>> = cx.newEntity(_ -> new StateModel<T>(initial));
            cx.observe(newState, (_, cx) -> cx.notify(currentView));
            state.value = (newState : StateModel<T>);
            result = newState;
        }
        elementIdNode = node;
        return result;
    }

    /**
     * Use a piece of state that exists as long this element is being rendered in consecutive frames,
     * keyed by the code location of the call.
     */
    public function useState<T>(cx:App, init:(Window) -> T, ?pos:haxe.PosInfos):Entity<StateModel<T>> {
        return useKeyedState(ElementId.CodeLocation(pos.fileName, pos.lineNumber), cx, init);
    }

    /**
     * The host entity of the persistent component placed by `proto` (the
     * placeholder returned by `X.component()`), kept as an element state
     * under the placeholder's identity (`proto.__key`: the position of the
     * `component()` call, or `.at(key)`) as long as the parent renders it in
     * consecutive frames; dropped (and the component destroyed) otherwise.
     *
     * The first time, the component is created, given the props of the
     * placeholder and initialized. Afterwards the props are assigned: a
     * changed data prop invalidates the host's tracker while its parent
     * renders, which would only mark the host dirty for the next frame
     * (`invalidateView` while drawing), so the host is made dirty for this
     * frame instead and renders right after its parent, with the new props.
     */
    @:allow(glaze)
    function useComponent(proto:Component, cx:App):ComponentBuilder.ComponentHost {
        final node = elementIdNode;
        final globalId = node.child(proto.__key);
        final box = elementStateBox(globalId, componentStateType);
        var host:ComponentBuilder.ComponentHost = box.value;
        if (host != null && host.instance.__elementId() != proto.__elementId()) {
            // Another component class at the same identity (`cond ? A.component() : B.component()`)
            host.destroy();
            host = null;
        }
        if (host == null) {
            final live = proto.__create();
            proto.__apply(live);
            host = new ComponentBuilder.ComponentHost(live);
            cx.attachEntity(host);
            box.value = host;
            host.ensureInit(this, cx);
        }
        else {
            final viewId = host.entityId;
            final childrenChanged = proto.__apply(host.instance);
            if (!promotePendingDirtyView(viewId) && childrenChanged) {
                markViewDirty(viewId);
            }
        }
        return host;
    }

    /**
     * A view notified earlier in this draw (`invalidateView` while drawing
     * records it for the next frame, like GPUI) that is reached before it
     * rendered renders in this frame: GPUI draws every uncached view on
     * every frame, so a view notified while its parent renders shows the
     * change in that frame, and no frame follows. The port's views render
     * only when dirty, so the pending view is made dirty now. A kit control
     * whose state is pushed by its parent's render
     * (`Select.component().value(v)`) shows the new value right away.
     * Returns `true` when the view was pending.
     */
    @:allow(glaze)
    function promotePendingDirtyView(viewId:Int):Bool {
        if (!pendingDirtyViews.exists(viewId)) {
            return false;
        }
        pendingDirtyViews.remove(viewId);
        pendingDirtyViewIds.remove(viewId);
        markViewDirty(viewId);
        return true;
    }

    static var componentStateType(get, null):Int = -1;
    static function get_componentStateType():Int {
        if (componentStateType == -1) {
            componentStateType = ElementStateType.of(ComponentBuilder.ComponentHost);
        }
        return componentStateType;
    }

/// Stacks

    /**
     * The current text style. Which is composed of all the style refinements provided to `withTextStyle`.
     */
    public function textStyle():TextStyle {
        return currentTextStyle().clone();
    }

    /**
     * Composed text styles of the stack: entry `i` is the default style
     * refined by `textStyleStack[0...i + 1]`. Entries are never modified once
     * composed (they are shared by `currentTextStyle()`).
     */
    final textStyleCache:Array<TextStyle> = [];

    /** The refinement each entry of `textStyleCache` was composed with */
    final textStyleCacheRefinements:Array<TextStyleRefinement> = [];

    /**
     * Number of valid entries of `textStyleCache` (lowered by every push and
     * pop; entries whose refinement is no longer the one on the stack, after
     * the stack was replaced, are also composed again).
     */
    var textStyleCacheValid:Int = 0;

    static var defaultTextStyle:Null<TextStyle> = null;

    /**
     * Holds the child slots of the styles composed on the first level of the
     * text style stack (no parent style there): equal first refinements of
     * siblings share one style. Only its slots are used.
     */
    var textStyleRootSlots:Null<TextStyle> = null;

    /**
     * The current text style, shared between calls while the text style
     * stack holds the same refinements: must not be modified (`textStyle()`
     * returns a copy to modify). Composed once per stack depth.
     */
    @:allow(glaze)
    function currentTextStyle():TextStyle {
        final stack = textStyleStack;
        final length = stack.length;
        if (length == 0) {
            var style = defaultTextStyle;
            if (style == null) {
                style = new TextStyle();
                defaultTextStyle = style;
            }
            return style;
        }
        final cache = textStyleCache;
        final refinements = textStyleCacheRefinements;
        var index = 0;
        final valid = textStyleCacheValid < length ? textStyleCacheValid : length;
        while (index < valid && refinements[index] == stack[index]) {
            index++;
        }
        while (index < length) {
            final refinement = stack[index];
            final parent = index == 0 ? null : cache[index - 1];
            // The style this refinement composed with the same parent earlier
            // in the frame (siblings, and the paint phase after the layout
            // phase): the same values, no clone
            var style = refinement.composedStyle;
            if (style == null || refinement.composedParent != parent || refinement.composedFrame != drawCount || refinement.composedWindow != this) {
                // A sibling with an equal refinement composed this parent
                // already: the same values (styles composed here are not changed)
                var slots = parent;
                if (slots == null) {
                    slots = textStyleRootSlots;
                    if (slots == null) {
                        slots = new TextStyle();
                        textStyleRootSlots = slots;
                    }
                }
                style = slots.composedChild(refinement, parent, drawCount, this);
                if (style == null) {
                    style = parent == null ? new TextStyle() : parent.clone();
                    style.refine(refinement);
                    slots.rememberChild(refinement, style);
                }
                refinement.composedStyle = style;
                refinement.composedParent = parent;
                refinement.composedFrame = drawCount;
                refinement.composedWindow = this;
            }
            cache[index] = style;
            refinements[index] = refinement;
            index++;
        }
        textStyleCacheValid = length;
        return cache[length - 1];
    }

    /**
     * The current text style, shared (see `currentTextStyle()`). Used for
     * the cache keys of views (no allocation per view).
     */
    @:allow(glaze)
    inline function sharedCurrentTextStyle():TextStyle {
        return currentTextStyle();
    }

    /**
     * Push a text style onto the stack, and call a function with that style active.
     */
    public function withTextStyle<R>(style:Null<TextStyleRefinement>, f:(Window) -> R):R {
        if (style == null)
            return f(this);
        pushTextStyle(style);
        final result = f(this);
        popTextStyle();
        return result;
    }

    public inline function pushTextStyle(style:TextStyleRefinement):Void {
        final length = textStyleStack.length;
        if (textStyleCacheValid > length) textStyleCacheValid = length;
        textStyleStack.push(style);
    }

    public inline function popTextStyle():Void {
        textStyleStack.pop();
        final length = textStyleStack.length;
        if (textStyleCacheValid > length) textStyleCacheValid = length;
    }

    /**
     * Obtain the current content mask.
     */
    public function contentMask():ContentMask {
        if (contentMaskStack.length > 0) {
            return contentMaskStack[contentMaskStack.length - 1];
        }
        return windowContentMask;
    }

    /**
     * Invoke the given function with the given content mask after intersecting it
     * with the current mask.
     */
    public function withContentMask<R>(mask:Null<ContentMask>, f:(Window) -> R):R {
        if (mask == null)
            return f(this);
        pushContentMask(mask);
        final result = f(this);
        popContentMask();
        return result;
    }

    public function pushContentMask(mask:ContentMask):Void {
        contentMaskStack.push(mask.intersect(contentMask()));
    }

    /**
     * `pushContentMask(style.overflowMask(bounds, remSize()))` when the
     * style has one (true), making only the intersected mask: the same
     * operations as `Bounds.intersect` (`Point.max`, `Point.min`,
     * `fromCorners`).
     */
    @:allow(glaze)
    function pushOverflowMask(style:Style, bounds:Bounds, ?like:ContentMask):Bool {
        if (!style.computeOverflowMask(bounds, remSize())) {
            return false;
        }
        final x = Style.overflowMaskX;
        final y = Style.overflowMaskY;
        final right = x + Style.overflowMaskWidth;
        final bottom = y + Style.overflowMaskHeight;
        final other = contentMask().bounds;
        final otherRight = other.origin.x + other.size.width;
        final otherBottom = other.origin.y + other.size.height;
        final left = glaze.util.MathUtil.totalLess(other.origin.x, x) ? x : other.origin.x;
        final top = glaze.util.MathUtil.totalLess(other.origin.y, y) ? y : other.origin.y;
        final minRight = !glaze.util.MathUtil.totalLess(otherRight, right) ? right : otherRight;
        final minBottom = !glaze.util.MathUtil.totalLess(otherBottom, bottom) ? bottom : otherBottom;
        final width = (glaze.util.MathUtil.totalLess(left, minRight) ? minRight : left) - left;
        final height = (glaze.util.MathUtil.totalLess(top, minBottom) ? minBottom : top) - top;
        // `like` (the mask of the same element in the prepaint phase) when
        // it is the same: masks are immutable
        if (like != null) {
            final b = like.bounds;
            if (sameFloat(b.origin.x, left) && sameFloat(b.origin.y, top) && sameFloat(b.size.width, width) && sameFloat(b.size.height, height)) {
                contentMaskStack.push(like);
                return true;
            }
        }
        // The current mask when the element does not clip it further (masks are immutable)
        if (sameFloat(other.origin.x, left) && sameFloat(other.origin.y, top) && sameFloat(other.size.width, width) && sameFloat(other.size.height, height)) {
            contentMaskStack.push(contentMask());
            return true;
        }
        contentMaskStack.push(new ContentMask(new Bounds(new Point(left, top), new Size(width, height))));
        return true;
    }

    /** The same value, zero signs included */
    static inline function sameFloat(a:Float, b:Float):Bool {
        return a == b && (b != 0.0 || 1.0 / a == 1.0 / b);
    }

    public inline function popContentMask():Void {
        contentMaskStack.pop();
    }

    /**
     * Obtain the current element offset.
     */
    public function elementOffset():Point {
        if (elementOffsetStack.length > 0) {
            return elementOffsetStack[elementOffsetStack.length - 1];
        }
        return ORIGIN;
    }

    /**
     * Updates the global element offset relative to the current offset.
     */
    public function withElementOffset<R>(offset:Point, f:(Window) -> R):R {
        if (offset.isZero())
            return f(this);
        return withAbsoluteElementOffset(elementOffset().add(offset), f);
    }

    /**
     * Updates the global element offset based on the given offset.
     */
    public function withAbsoluteElementOffset<R>(offset:Point, f:(Window) -> R):R {
        elementOffsetStack.push(offset);
        final result = f(this);
        elementOffsetStack.pop();
        return result;
    }

    public inline function pushAbsoluteElementOffset(offset:Point):Void {
        elementOffsetStack.push(offset);
    }

    public inline function popElementOffset():Void {
        elementOffsetStack.pop();
    }

    /**
     * Executes the provided function with the specified image cache (none: `f` runs as is).
     */
    public function withImageCache<R>(imageCache:Null<AnyImageCache>, f:(Window) -> R):R {
        if (imageCache == null)
            return f(this);
        imageCacheStack.push(imageCache);
        final result = f(this);
        imageCacheStack.pop();
        return result;
    }

    public inline function pushImageCache(imageCache:AnyImageCache):Void {
        imageCacheStack.push(imageCache);
    }

    public inline function popImageCache():Void {
        imageCacheStack.pop();
    }

    /**
     * Executes the given closure with an additional element opacity applied.
     */
    public function withElementOpacity<R>(opacity:Null<Float>, f:(Window) -> R):R {
        if (opacity == null)
            return f(this);
        final previous = pushElementOpacity(opacity);
        final result = f(this);
        popElementOpacity(previous);
        return result;
    }

    /**
     * Multiplies the element opacity by `opacity` and returns the previous one, to give to `popElementOpacity`.
     */
    public inline function pushElementOpacity(opacity:Float):Float {
        final previous = elementOpacity;
        elementOpacity = previous * opacity;
        return previous;
    }

    public inline function popElementOpacity(previous:Float):Void {
        elementOpacity = previous;
    }

    /**
     * The current element opacity.
     */
    public inline function currentElementOpacity():Float {
        return elementOpacity;
    }

/// Snapping (scaled pixels)

    inline function snapStroke(value:Float):Float {
        return TaffyLayoutEngine.roundStrokeToDevicePixel(value, _scaleFactor);
    }

    inline function roundToDevice(value:Float):Float {
        return TaffyLayoutEngine.roundToDevicePixel(value, _scaleFactor);
    }

    inline function floorToDevice(value:Float):Float {
        return TaffyLayoutEngine.floorToDevicePixel(value, _scaleFactor);
    }

    inline function ceilToDevice(value:Float):Float {
        return TaffyLayoutEngine.ceilToDevicePixel(value, _scaleFactor);
    }

    // Snapped content mask, refreshed by `snapContentMask()`
    var maskX:Float = 0;
    var maskY:Float = 0;
    var maskW:Float = 0;
    var maskH:Float = 0;

    /** Covers the current content mask with device pixels (floor near edges, ceil far edges) */
    function snapContentMask():Void {
        final bounds = contentMask().bounds;
        final left = floorToDevice(bounds.origin.x);
        final top = floorToDevice(bounds.origin.y);
        final right = Math.max(ceilToDevice(bounds.origin.x + bounds.size.width), left);
        final bottom = Math.max(ceilToDevice(bounds.origin.y + bounds.size.height), top);
        maskX = left;
        maskY = top;
        maskW = right - left;
        maskH = bottom - top;
    }

/// Painting

    /**
     * A `PaintQuad` reused by the elements of this window to paint quads
     * without allocating (fill it, then give it to `paintQuad()`).
     */
    public function scratchPaintQuad():PaintQuad {
        final quad = scratchQuad;
        quad.background = null;
        quad.setSolidBackground(0, 0, 0, 0);
        quad.setBorderWidths(0, 0, 0, 0);
        quad.setBorderColor(0, 0, 0, 0);
        quad.borderStyle = Solid;
        return quad;
    }

    /**
     * Invoke the given function with the content mask reset to that
     * of the window.
     */
    public function paintLayer<R>(bounds:Bounds, f:(Window) -> R):R {
        final mask = contentMask().bounds;
        // In f32, like GPUI (see `TextPainter.pushCoverLayer`)
        final pushed = TextPainter.pushCoverLayer(nextFrame.scene, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, mask.origin.x, mask.origin.y, mask.size.width, mask.size.height, _scaleFactor);
        final result = f(this);
        if (pushed) {
            nextFrame.scene.popLayer();
        }
        return result;
    }

    /**
     * Paint one or more drop shadows into the scene for the next frame at the current z-index.
     */
    public function paintDropShadows(bounds:Bounds, cornerRadii:Corners, shadows:Array<BoxShadow>):Void {
        if (shadows == null || shadows.length == 0)
            return;
        paintShadows(bounds, cornerRadii, shadows, false);
    }

    /**
     * Paint one or more inset shadows into the scene for the next frame at the current z-index.
     */
    public function paintInsetShadows(bounds:Bounds, cornerRadii:Corners, shadows:Array<BoxShadow>):Void {
        if (shadows == null || shadows.length == 0)
            return;
        paintShadows(bounds, cornerRadii, shadows, true);
    }

    function paintShadows(bounds:Bounds, cornerRadii:Corners, shadows:Array<BoxShadow>, inset:Bool):Void {
        final scaleFactor = _scaleFactor;
        snapContentMask();
        final opacity = elementOpacity;

        // Element bounds covered with device pixels
        final elementLeft = floorToDevice(bounds.origin.x);
        final elementTop = floorToDevice(bounds.origin.y);
        final elementRight = Math.max(ceilToDevice(bounds.origin.x + bounds.size.width), elementLeft);
        final elementBottom = Math.max(ceilToDevice(bounds.origin.y + bounds.size.height), elementTop);

        final scene = nextFrame.scene;
        for (shadow in shadows) {
            if (shadow.inset != inset)
                continue;

            // Drop shadow: (bounds + offset) dilated by the spread. Inset: the hole, shrunk by the spread.
            final spreadRadius:Float = shadow.spreadRadius;
            final amount:Float = inset ? -spreadRadius : spreadRadius;
            final x = bounds.origin.x + shadow.offset.x - amount;
            final y = bounds.origin.y + shadow.offset.y - amount;
            final w = bounds.size.width + amount + amount;
            final h = bounds.size.height + amount + amount;
            final left = floorToDevice(x);
            final top = floorToDevice(y);
            final right = Math.max(ceilToDevice(x + w), left);
            final bottom = Math.max(ceilToDevice(y + h), top);

            final primitive = scene.nextShadow();
            primitive.setBounds(left, top, right - left, bottom - top);
            primitive.setContentMask(maskX, maskY, maskW, maskH);
            if (inset) {
                // Clamp at zero so a large spread can't produce negative radii
                final spread:Float = shadow.spreadRadius;
                primitive.setCornerRadii(
                    Math.max(cornerRadii.topLeft - spread, 0) * scaleFactor,
                    Math.max(cornerRadii.topRight - spread, 0) * scaleFactor,
                    Math.max(cornerRadii.bottomRight - spread, 0) * scaleFactor,
                    Math.max(cornerRadii.bottomLeft - spread, 0) * scaleFactor
                );
            }
            else {
                primitive.setCornerRadii(
                    cornerRadii.topLeft * scaleFactor,
                    cornerRadii.topRight * scaleFactor,
                    cornerRadii.bottomRight * scaleFactor,
                    cornerRadii.bottomLeft * scaleFactor
                );
            }
            final color = shadow.color;
            primitive.setColor(color.h, color.s, color.l, color.a * clamp01(opacity));
            final blurRadius:Float = shadow.blurRadius;
            primitive.blurRadius = blurRadius * scaleFactor;
            primitive.setElementBounds(elementLeft, elementTop, elementRight - elementLeft, elementBottom - elementTop);
            primitive.setElementCornerRadii(
                cornerRadii.topLeft * scaleFactor,
                cornerRadii.topRight * scaleFactor,
                cornerRadii.bottomRight * scaleFactor,
                cornerRadii.bottomLeft * scaleFactor
            );
            primitive.inset = inset;
            scene.commitShadow(primitive);
        }
    }

    static inline function clamp01(value:Float):Float {
        return value < 0 ? 0 : (value > 1 ? 1 : value);
    }

    /**
     * Paint one or more quads into the scene for the next frame at the current stacking context.
     * Quads are colored rectangular regions with an optional background, border, and corner radius.
     *
     * Like GPUI, a quad with a transparent background is split into strips
     * around its largest border free interior.
     */
    public function paintQuad(quad:PaintQuad):Void {
        final bounds = quad.bounds;
        paintQuadAt(quad, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    }

    /**
     * `paintQuad()` with the bounds given as numbers (`quad.bounds` is not
     * read): elements painting many rectangles from a scratch quad
     * (`scratchPaintQuad()`) need no `Bounds` per rectangle.
     */
    public function paintQuadAt(quad:PaintQuad, x:Float, y:Float, width:Float, height:Float):Void {
        final opacity = clamp01(elementOpacity);
        final scaleFactor = _scaleFactor;

        // Snap bounds
        final left = roundToDevice(x);
        final top = roundToDevice(y);
        final right = Math.max(roundToDevice(x + width), left);
        final bottom = Math.max(roundToDevice(y + height), top);

        // Snap border widths
        final borderTop = snapStroke(quad.borderWidthTop);
        final borderRight = snapStroke(quad.borderWidthRight);
        final borderBottom = snapStroke(quad.borderWidthBottom);
        final borderLeft = snapStroke(quad.borderWidthLeft);

        snapContentMask();

        final radii = quad.cornerRadii;
        final radiusTopLeft = radii.topLeft * scaleFactor;
        final radiusTopRight = radii.topRight * scaleFactor;
        final radiusBottomRight = radii.bottomRight * scaleFactor;
        final radiusBottomLeft = radii.bottomLeft * scaleFactor;

        // Background with opacity applied, and transparency check
        final background = quad.background;
        var transparent:Bool;
        if (background == null) {
            transparent = quad.solidA * opacity == 0.0;
        }
        else {
            transparent = switch background.tag {
                case LinearGradient: background.colors0.color.a * opacity == 0.0 && background.colors1.color.a * opacity == 0.0;
                case _: background.solid.a * opacity == 0.0;
            }
        }

        final scene = nextFrame.scene;

        inline function emit(maskX:Float, maskY:Float, maskW:Float, maskH:Float):Void {
            final q = scene.nextQuad();
            q.setBounds(left, top, right - left, bottom - top);
            q.setContentMask(maskX, maskY, maskW, maskH);
            if (background == null) {
                q.backgroundTag = 0;
                q.backgroundColorSpace = 0;
                q.setSolidBackground(quad.solidH, quad.solidS, quad.solidL, quad.solidA * opacity);
            }
            else {
                q.backgroundTag = cast background.tag;
                q.backgroundColorSpace = cast background.colorSpace;
                final solid = background.solid;
                q.backgroundSolidH = solid.h;
                q.backgroundSolidS = solid.s;
                q.backgroundSolidL = solid.l;
                q.backgroundSolidA = solid.a * opacity;
                q.backgroundGradientAngleOrPatternHeight = background.gradientAngleOrPatternHeight;
                final c0 = background.colors0;
                q.backgroundColor0H = c0.color.h;
                q.backgroundColor0S = c0.color.s;
                q.backgroundColor0L = c0.color.l;
                q.backgroundColor0A = c0.color.a * opacity;
                q.backgroundColor0Percentage = c0.percentage;
                final c1 = background.colors1;
                q.backgroundColor1H = c1.color.h;
                q.backgroundColor1S = c1.color.s;
                q.backgroundColor1L = c1.color.l;
                q.backgroundColor1A = c1.color.a * opacity;
                q.backgroundColor1Percentage = c1.percentage;
            }
            q.setBorderColor(quad.borderColorH, quad.borderColorS, quad.borderColorL, quad.borderColorA * opacity);
            q.setCornerRadii(radiusTopLeft, radiusTopRight, radiusBottomRight, radiusBottomLeft);
            q.setBorderWidths(borderTop, borderRight, borderBottom, borderLeft);
            q.borderStyle = quad.borderStyle;
            scene.commitQuad(q);
        }

        if (!transparent) {
            emit(maskX, maskY, maskW, maskH);
            return;
        }

        // Splitting a border-only quad around its empty interior avoids shading
        // every transparent pixel inside large outlines.
        // Largest border interior (GPUI's `largest_border_interior`)
        final edgeTop = Math.max(radiusTopLeft, radiusTopRight);
        final edgeRight = Math.max(radiusTopRight, radiusBottomRight);
        final edgeBottom = Math.max(radiusBottomLeft, radiusBottomRight);
        final edgeLeft = Math.max(radiusTopLeft, radiusBottomLeft);
        final antialias = 1.0;

        // Rounded corners need only be excluded on one axis. Either candidate
        // is empty of border pixels, so use the larger interior.
        final hLeft = left + borderLeft + antialias;
        final hTop = top + Math.max(borderTop, edgeTop) + antialias;
        final hRight = right - borderRight - antialias;
        final hBottom = bottom - Math.max(borderBottom, edgeBottom) - antialias;
        final vLeft = left + Math.max(borderLeft, edgeLeft) + antialias;
        final vTop = top + borderTop + antialias;
        final vRight = right - Math.max(borderRight, edgeRight) - antialias;
        final vBottom = bottom - borderBottom - antialias;
        final hArea = Math.max(hRight - hLeft, 0.0) * Math.max(hBottom - hTop, 0.0);
        final vArea = Math.max(vRight - vLeft, 0.0) * Math.max(vBottom - vTop, 0.0);

        final innerLeft = hArea >= vArea ? hLeft : vLeft;
        final innerTop = hArea >= vArea ? hTop : vTop;
        final innerRight = hArea >= vArea ? hRight : vRight;
        final innerBottom = hArea >= vArea ? hBottom : vBottom;

        // `Bounds::from_corners` then `is_empty`
        if (innerRight - innerLeft <= 0 || innerBottom - innerTop <= 0) {
            emit(maskX, maskY, maskW, maskH);
            return;
        }

        final quadMaskX = maskX;
        final quadMaskY = maskY;
        final quadMaskW = maskW;
        final quadMaskH = maskH;

        inline function strip(x0:Float, y0:Float, x1:Float, y1:Float):Void {
            // content_mask.bounds.intersect(strip), then is_empty
            final ix = Math.max(quadMaskX, x0);
            final iy = Math.max(quadMaskY, y0);
            final ir = Math.max(Math.min(quadMaskX + quadMaskW, x1), ix);
            final ib = Math.max(Math.min(quadMaskY + quadMaskH, y1), iy);
            if (ir - ix > 0 && ib - iy > 0) {
                emit(ix, iy, ir - ix, ib - iy);
            }
        }

        // Top
        strip(left, top, right, innerTop);
        // Bottom
        strip(left, innerBottom, right, bottom);
        // Left
        strip(left, innerTop, innerLeft, innerBottom);
        // Right
        strip(innerRight, innerTop, right, innerBottom);
    }

    /**
     * Paint an underline into the scene for the next frame at the current z-index.
     */
    public function paintUnderline(origin:Point, width:Pixels, style:UnderlineStyle):Void {
        final thickness = snapStroke(style.thickness);
        final height = style.wavy ? thickness * 3.0 : thickness;
        snapContentMask();
        final underline = nextFrame.scene.nextUnderline();
        underline.setBounds(roundToDevice(origin.x), roundToDevice(origin.y), snapStroke(width), height);
        underline.setContentMask(maskX, maskY, maskW, maskH);
        final color = style.color;
        if (color != null) {
            underline.setColor(color.h, color.s, color.l, color.a * clamp01(elementOpacity));
        }
        underline.thickness = thickness;
        underline.wavy = style.wavy;
        nextFrame.scene.commitUnderline(underline);
    }

    /**
     * Paint a strikethrough into the scene for the next frame at the current z-index.
     */
    public function paintStrikethrough(origin:Point, width:Pixels, style:StrikethroughStyle):Void {
        snapContentMask();
        final underline = nextFrame.scene.nextUnderline();
        underline.setBounds(roundToDevice(origin.x), roundToDevice(origin.y), snapStroke(width), snapStroke(style.thickness));
        underline.setContentMask(maskX, maskY, maskW, maskH);
        final color = style.color;
        if (color != null) {
            underline.setColor(color.h, color.s, color.l, color.a * clamp01(elementOpacity));
        }
        underline.thickness = snapStroke(style.thickness);
        underline.wavy = false;
        nextFrame.scene.commitUnderline(underline);
    }

/// Text, SVG and images

    /**
     * The text system of this window (Rust `window.text_system()`): the
     * app's `TextSystem` plus a per window line layout cache.
     */
    public inline function textSystem():WindowTextSystem {
        return windowTextSystem;
    }

    /**
     * The `TextPainter` of this window, refreshed with the current scene,
     * scale factor, element opacity and content mask. Give it to
     * `ShapedLine.paint()` / `WrappedLine.paint()` during the paint phase.
     */
    public function textPainter():TextPainter {
        final p = painter;
        p.scene = nextFrame.scene;
        p.atlas = spriteAtlas;
        p.textSystem = windowTextSystem.textSystem;
        p.scaleFactor = _scaleFactor;
        p.elementOpacity = elementOpacity;
        p.contentMaskBounds = contentMask().bounds;
        return p;
    }

    /**
     * Paints a monochrome (non-emoji) glyph into the scene for the next frame at the current z-index.
     *
     * The y component of the origin is the baseline of the glyph.
     * You should generally prefer to use the `ShapedLine.paint()` or `WrappedLine.paint()` methods.
     * This method is only useful if you need to paint a single glyph that has already been shaped.
     */
    public function paintGlyph(origin:Point, fontId:FontId, glyphId:GlyphId, fontSize:Pixels, color:Hsla):Void {
        snapContentMask();
        TextPainter.emitGlyph(nextFrame.scene, spriteAtlas, windowTextSystem.textSystem, glyphParams, _scaleFactor, elementOpacity, maskX, maskY, maskW, maskH, origin.x, origin.y, fontId, glyphId, fontSize, color);
    }

    /**
     * Paints an emoji glyph into the scene for the next frame at the current z-index.
     *
     * The y component of the origin is the baseline of the glyph.
     */
    public function paintEmoji(origin:Point, fontId:FontId, glyphId:GlyphId, fontSize:Pixels):Void {
        snapContentMask();
        TextPainter.emitEmoji(nextFrame.scene, spriteAtlas, windowTextSystem.textSystem, glyphParams, _scaleFactor, elementOpacity, maskX, maskY, maskW, maskH, origin.x, origin.y, fontId, glyphId, fontSize);
    }

    /**
     * Paint a monochrome SVG into the scene for the next frame at the current stacking context.
     *
     * `data` is the SVG source (when null, `path` is loaded from the asset
     * source); `path` is also the atlas key, so different data needs
     * different paths. Throws if the SVG cannot be rendered.
     */
    var svgTileBuilder:Null<SvgTileBuilder> = null;

    public function paintSvg(bounds:Bounds, path:String, data:Null<haxe.io.Bytes>, transformation:Null<TransformationMatrix>, color:Hsla, cx:App):Void {
        final elementOpacity = this.elementOpacity;

        // snap_bounds
        final left = roundToDevice(bounds.origin.x);
        final top = roundToDevice(bounds.origin.y);
        final right = Math.max(roundToDevice(bounds.origin.x + bounds.size.width), left);
        final bottom = Math.max(roundToDevice(bounds.origin.y + bounds.size.height), top);

        final factor = SvgRenderer.SMOOTH_SVG_SCALE_FACTOR;
        final width = Std.int(Math.fceil((right - left) * factor));
        final height = Std.int(Math.fceil((bottom - top) * factor));

        // The build of a missing tile through one function value made once
        // (`SvgTileBuilder`): no closure nor params per painted SVG
        var builder = svgTileBuilder;
        if (builder == null) {
            builder = new SvgTileBuilder();
            svgTileBuilder = builder;
        }
        builder.path = path;
        builder.width = width;
        builder.height = height;
        builder.data = data;
        builder.cx = cx;
        final tile = spriteAtlas.getOrInsertWith(AtlasKey.Svg(path, width, height), builder.buildFunction);
        builder.data = null;
        builder.cx = null;
        if (tile == null)
            return;

        snapContentMask();
        final tileWidth = tile.bounds.size.width / factor;
        final tileHeight = tile.bounds.size.height / factor;
        final centerX = left + (right - left) / 2;
        final centerY = top + (bottom - top) / 2;
        final x = TextPainter.roundHalfTowardZero(centerX - tileWidth / 2);
        final y = TextPainter.roundHalfTowardZero(centerY - tileHeight / 2);

        final scene = nextFrame.scene;
        final sprite = scene.nextMonochromeSprite();
        sprite.setBounds(x, y, Math.fceil(tileWidth), Math.fceil(tileHeight));
        sprite.setContentMask(maskX, maskY, maskW, maskH);
        sprite.setColor(color.h, color.s, color.l, color.a * clamp01(elementOpacity));
        sprite.setTile(tile.textureId.index, tile.bounds.origin.x, tile.bounds.origin.y, tile.bounds.size.width, tile.bounds.size.height);
        if (transformation != null) {
            sprite.setTransformation(transformation.m00, transformation.m01, transformation.m10, transformation.m11, transformation.tx, transformation.ty);
        }
        scene.commitMonochromeSprite(sprite);
    }

    /**
     * Paint an image into `bounds`, positioning and scaling it according to `imageBounds`.
     *
     * The visible region rendered is `bounds.intersect(imageBounds)`, with `cornerRadii`
     * applied to `bounds`. Throws if `frameIndex` is not valid.
     */
    public function paintImage(bounds:Bounds, imageBounds:Bounds, cornerRadii:Corners, data:RenderImage, frameIndex:Int, grayscale:Bool):Void {
        final visibleBounds = bounds.intersect(imageBounds);
        if (visibleBounds.size.width <= 0 || visibleBounds.size.height <= 0)
            return;
        if (imageBounds.size.width <= 0 || imageBounds.size.height <= 0)
            return;

        final frame = data.frame(frameIndex);
        if (frame == null)
            throw "It's the caller's job to pass a valid frame index";

        final tile = spriteAtlas.getOrInsertWith(AtlasKey.Image(data.id, frameIndex), () -> {
            final source = new AtlasTile.AtlasTileSource(frame.width, frame.height, frame.bytes);
            if (frame.texture != null) {
                source.texture = frame.texture;
            }
            else {
                source.straightAlpha = true;
            }
            return source;
        });
        if (tile == null)
            throw 'Callback above only returns Some';

        // snap_bounds(visible_bounds)
        final left = roundToDevice(visibleBounds.origin.x);
        final top = roundToDevice(visibleBounds.origin.y);
        final right = Math.max(roundToDevice(visibleBounds.origin.x + visibleBounds.size.width), left);
        final bottom = Math.max(roundToDevice(visibleBounds.origin.y + visibleBounds.size.height), top);

        var tileX = tile.bounds.origin.x;
        var tileY = tile.bounds.origin.y;
        var tileW = tile.bounds.size.width;
        var tileH = tile.bounds.size.height;
        if (!visibleBounds.equals(imageBounds)) {
            final xOffsetRatio = (visibleBounds.origin.x - imageBounds.origin.x) / imageBounds.size.width;
            final yOffsetRatio = (visibleBounds.origin.y - imageBounds.origin.y) / imageBounds.size.height;
            final widthRatio = visibleBounds.size.width / imageBounds.size.width;
            final heightRatio = visibleBounds.size.height / imageBounds.size.height;

            final subOriginX = tileX + glaze.util.MathUtil.round(xOffsetRatio * tileW);
            final subOriginY = tileY + glaze.util.MathUtil.round(yOffsetRatio * tileH);
            final subWidth = glaze.util.MathUtil.round(widthRatio * tileW);
            final subHeight = glaze.util.MathUtil.round(heightRatio * tileH);

            final maxX = tileX + tileW;
            final maxY = tileY + tileH;

            final clampedOriginX = Math.min(Math.max(subOriginX, tileX), maxX);
            final clampedOriginY = Math.min(Math.max(subOriginY, tileY), maxY);
            final clampedWidth = Math.max(Math.min(subWidth, maxX - clampedOriginX), 0);
            final clampedHeight = Math.max(Math.min(subHeight, maxY - clampedOriginY), 0);
            tileX = clampedOriginX;
            tileY = clampedOriginY;
            tileW = clampedWidth;
            tileH = clampedHeight;
        }

        snapContentMask();
        final radii = cornerRadii.clampRadiiForQuadSize(visibleBounds.size).scale(_scaleFactor);

        final scene = nextFrame.scene;
        final sprite = scene.nextPolychromeSprite();
        sprite.grayscale = grayscale;
        sprite.setBounds(left, top, right - left, bottom - top);
        sprite.setContentMask(maskX, maskY, maskW, maskH);
        sprite.setCornerRadii(radii.topLeft, radii.topRight, radii.bottomRight, radii.bottomLeft);
        sprite.setTile(tile.textureId.index, tileX, tileY, tileW, tileH);
        sprite.opacity = elementOpacity;
        scene.commitPolychromeSprite(sprite);
    }

    /**
     * Paint the region `tileX, tileY, tileWidth, tileHeight` (in pixels) of a
     * Ceramic texture into `bounds` of the scene for the next frame, clipped
     * by the content mask, with the given corner radii and the element
     * opacity: a polychrome sprite like `paintImage`, whose texture is drawn
     * directly (not owned, see `ImageSource.Texture`). Used by `visual()`
     * elements to show their `Filter`'s render texture or atlas tile.
     * Specific to the Haxe port.
     */
    public function paintTexture(bounds:Bounds, cornerRadii:Corners, texture:ceramic.Texture, tileX:Float, tileY:Float, tileWidth:Float, tileHeight:Float, grayscale:Bool = false):Void {
        if (bounds.size.width <= 0 || bounds.size.height <= 0 || tileWidth <= 0 || tileHeight <= 0)
            return;
        if (texture == null || texture.destroyed)
            return;

        final data = ImageSource.ImageSourceTools.textureImage(texture);
        final frame = data.frame(0);
        final tile = spriteAtlas.getOrInsertWith(AtlasKey.Image(data.id, 0), () -> {
            final source = new AtlasTile.AtlasTileSource(frame.width, frame.height, null);
            source.texture = frame.texture;
            return source;
        });
        if (tile == null)
            return;

        final left = roundToDevice(bounds.origin.x);
        final top = roundToDevice(bounds.origin.y);
        final right = Math.max(roundToDevice(bounds.origin.x + bounds.size.width), left);
        final bottom = Math.max(roundToDevice(bounds.origin.y + bounds.size.height), top);

        snapContentMask();
        final radii = cornerRadii.clampRadiiForQuadSize(bounds.size).scale(_scaleFactor);

        final scene = nextFrame.scene;
        final sprite = scene.nextPolychromeSprite();
        sprite.grayscale = grayscale;
        sprite.setBounds(left, top, right - left, bottom - top);
        sprite.setContentMask(maskX, maskY, maskW, maskH);
        sprite.setCornerRadii(radii.topLeft, radii.topRight, radii.bottomRight, radii.bottomLeft);
        sprite.setTile(tile.textureId.index, tile.bounds.origin.x + tileX, tile.bounds.origin.y + tileY, tileWidth, tileHeight);
        sprite.opacity = elementOpacity;
        scene.commitPolychromeSprite(sprite);
    }

    /**
     * Whether `hitbox` is reached by the mouse at `x, y` (window coordinates)
     * in the last drawn frame: it contains the point inside its content
     * mask, and no hitbox inserted after it that contains the point blocks
     * the mouse (`BlockMouse`, `BlockMouseExceptScroll`: an occluding element
     * painted over it, a popover, a dialog). Hitboxes over it that do not
     * block (a scrollbar's hover area) let it through, like GPUI's hover
     * test (`Hitbox::is_hovered`). Used by `visual()` elements to route
     * Ceramic pointer events to their content. Allocates nothing. Specific
     * to the Haxe port.
     */
    public function isHitboxReachedAt(hitbox:Hitbox, x:Float, y:Float):Bool {
        if (destroyed)
            return false;
        final hitboxes = renderedFrame.hitboxes;
        var i = hitboxes.length - 1;
        while (i >= 0) {
            final candidate = hitboxes[i];
            final b = candidate.bounds;
            final m = candidate.contentMask.bounds;
            if (x >= b.origin.x && x < b.origin.x + b.size.width && y >= b.origin.y && y < b.origin.y + b.size.height
                && x >= m.origin.x && x < m.origin.x + m.size.width && y >= m.origin.y && y < m.origin.y + m.size.height) {
                if (candidate == hitbox || candidate.id == hitbox.id)
                    return true;
                if (candidate.behavior != Normal)
                    return false;
            }
            i--;
        }
        return false;
    }

    /**
     * Paint the given `Path` into the scene for the next frame at the current z-index.
     *
     * Differences with GPUI: the path is rasterized by `PathRasterizer` into
     * a tile of the atlas (cached by geometry), at the device pixel
     * resolution, with the 4x MSAA sample coverage of GPUI's Metal renderer
     * (vertex snapping, Metal sample positions, Loop-Blinn curve alpha),
     * then drawn with its color by a shader that reproduces the per sample
     * storage and the resolve; GPUI renders its triangles into an
     * intermediate 4x MSAA texture. The background (solid, linear gradient
     * or pattern) is evaluated per pixel by the shader, over the path bounds
     * clipped by the content mask, like GPUI.
     */
    public function paintPath(path:Path, color:IntoBackground):Void {
        final background:Background = color;
        final opacity = clamp01(elementOpacity);
        path.contentMask = contentMask();
        path.color = background.opacity(opacity);

        final sf = _scaleFactor;
        final bounds = path.bounds;
        snapContentMask();

        // Device rectangle covering the path (plus antialiasing), clipped by the mask
        var x0 = Math.ffloor(bounds.origin.x * sf) - 1;
        var y0 = Math.ffloor(bounds.origin.y * sf) - 1;
        var x1 = Math.fceil((bounds.origin.x + bounds.size.width) * sf) + 1;
        var y1 = Math.fceil((bounds.origin.y + bounds.size.height) * sf) + 1;
        x0 = Math.max(x0, maskX);
        y0 = Math.max(y0, maskY);
        x1 = Math.min(x1, maskX + maskW);
        y1 = Math.min(y1, maskY + maskH);
        final width = Std.int(x1 - x0);
        final height = Std.int(y1 - y0);
        if (width <= 0 || height <= 0)
            return;

        // GPUI's intermediate path texture has the size of the drawable
        final viewportWidth = Math.round(_viewportSize.width * sf);
        final viewportHeight = Math.round(_viewportSize.height * sf);
        final key = PathRasterizer.cacheKey(path, sf, x0, y0, width, height, viewportWidth, viewportHeight);
        final tile = if (PathRasterizer.hasCurves(path)) {
            spriteAtlas.getOrInsertWith(AtlasKey.PathCurves(key), () -> PathRasterizer.rasterizeCurves(path, sf, x0, y0, width, height, viewportWidth, viewportHeight));
        }
        else {
            spriteAtlas.getOrInsertWith(AtlasKey.Path(key), () -> PathRasterizer.rasterize(path, sf, x0, y0, width, height, viewportWidth, viewportHeight));
        }
        if (tile == null)
            return;

        final scene = nextFrame.scene;
        final sprite = scene.nextPath();
        sprite.setBounds(bounds.origin.x * sf, bounds.origin.y * sf, bounds.size.width * sf, bounds.size.height * sf);
        sprite.setSpriteBounds(x0, y0, width, height);
        // GPUI scales the content mask of paths without covering it with device pixels
        final mask = path.contentMask.bounds;
        sprite.setContentMask(mask.origin.x * sf, mask.origin.y * sf, mask.size.width * sf, mask.size.height * sf);
        final b = path.color;
        sprite.background = b.tag == Solid ? null : b;
        sprite.setColor(b.solid.h, b.solid.s, b.solid.l, b.solid.a);
        sprite.vertexCount = path.vertices.length;
        sprite.setTile(tile.textureId.index, tile.bounds.origin.x, tile.bounds.origin.y, tile.bounds.size.width, tile.bounds.size.height);
        scene.commitPath(sprite);
    }

    /**
     * Removes an image from the sprite atlas.
     */
    public function dropImage(data:RenderImage):Void {
        for (frameIndex in 0...data.frameCount()) {
            spriteAtlas.remove(AtlasKey.Image(data.id, frameIndex));
        }
    }

/// Deferred draws

    /**
     * Defers the drawing of the given element, scheduling it to be painted on top of the currently-drawn tree
     * at a later time. The `priority` parameter determines the drawing order relative to other deferred elements,
     * with higher values being drawn on top.
     *
     * When `contentMask` is provided, the deferred element will be clipped to that region during
     * paint. When `null`, no additional clipping is applied.
     *
     * This method should only be called as part of the prepaint phase of element drawing.
     */
    public function deferDraw(element:AnyElement, absoluteOffset:Point, priority:Int, ?contentMask:ContentMask):Void {
        final draw = new DeferredDraw();
        draw.currentView = renderedEntityStack[renderedEntityStack.length - 1];
        draw.parentNode = nextFrame.dispatchTree.activeNodeId();
        draw.elementIdNode = elementIdNode;
        draw.textStyleStack = textStyleStack.copy();
        draw.contentMask = contentMask;
        draw.remSize = remSize();
        draw.priority = priority;
        draw.element = element;
        draw.absoluteOffset = absoluteOffset;
        nextFrame.deferredDraws.push(draw);
    }

    /**
     * Deferred draws left out by `prepaintDeferredDraws` and
     * `paintDeferredDraws`: the old ones of the view rendering in place,
     * still in the frame until its entries are spliced.
     */
    var deferredSkipStart:Int = 0;

    var deferredSkipEnd:Int = 0;

    function deferredDrawOrder(start:Int, end:Int):Array<Int> {
        final skipStart = deferredSkipStart;
        final skipEnd = deferredSkipEnd;
        final order = [for (i in start...end) if (i < skipStart || i >= skipEnd) i];
        final draws = nextFrame.deferredDraws;
        // Stable sort by priority
        haxe.ds.ArraySort.sort(order, (a, b) -> {
            final pa = draws[a].priority;
            final pb = draws[b].priority;
            return pa != pb ? (pa < pb ? -1 : 1) : (a < b ? -1 : (a > b ? 1 : 0));
        });
        return order;
    }

    function prepaintDeferredDraws():Void {
        // Process deferred draws in multiple rounds to support nesting.
        // Each round processes all current deferred draws, which may push new ones.
        //
        // The draws are processed in place: prepaint ranges recorded during a
        // round (view caches, nested deferred draws) index the same array that
        // `reusePrepaint` slices on the next frame.
        var roundStart = 0;
        var depth = 0;
        final prepaintStart = scratchPrepaintIndex;
        while (true) {
            final roundEnd = nextFrame.deferredDraws.length;
            if (roundStart == roundEnd)
                break;
            // Limit maximum nesting depth to prevent infinite loops.
            if (depth >= 10)
                throw 'Exceeded maximum (10) deferred depth';
            depth++;

            for (index in deferredDrawOrder(roundStart, roundEnd)) {
                final draw = nextFrame.deferredDraws[index];
                draw.amendSerial = amending ? amendSerial : -1;
                elementIdNode = draw.elementIdNode;
                textStyleStack.resize(0);
                for (style in draw.textStyleStack) textStyleStack.push(style);
                nextFrame.dispatchTree.setActiveNode(draw.parentNode);

                prepaintIndexInto(prepaintStart);
                final element = draw.element;
                if (element != null) {
                    beginRenderedView(draw.currentView, false);
                    remSizeOverrideStack.push(draw.remSize);
                    pushAbsoluteElementOffset(draw.absoluteOffset);
                    element.prepaint(this, app);
                    popElementOffset();
                    Stacks.drop(remSizeOverrideStack);
                    endRenderedView();
                }
                else {
                    reusePrepaint(draw.prepaintStart, draw.prepaintEnd);
                }
                prepaintIndexInto(draw.prepaintEnd);
                draw.prepaintStart.copyFrom(prepaintStart);
            }

            elementIdNode = elementIdRoot;
            textStyleStack.resize(0);
            roundStart = roundEnd;
        }
    }

    function paintDeferredDraws():Void {
        // Paint all deferred draws in priority order.
        // Since prepaint has already processed nested deferreds, we just paint them all.
        final draws = nextFrame.deferredDraws;
        if (draws.length == 0)
            return;
        final paintStart = scratchPaintIndex;
        for (index in deferredDrawOrder(0, draws.length)) {
            final draw = draws[index];
            elementIdNode = draw.elementIdNode;
            nextFrame.dispatchTree.setActiveNode(draw.parentNode);

            paintIndexInto(paintStart);
            final element = draw.element;
            if (element != null) {
                beginRenderedView(draw.currentView, false);
                if (draw.contentMask != null) pushContentMask(draw.contentMask);
                remSizeOverrideStack.push(draw.remSize);
                element.paint(this, app);
                Stacks.drop(remSizeOverrideStack);
                if (draw.contentMask != null) popContentMask();
                endRenderedView();
            }
            else {
                reusePaint(draw.paintStart, draw.paintEnd);
            }
            paintIndexInto(draw.paintEnd);
            draw.paintStart.copyFrom(paintStart);
        }
        elementIdNode = elementIdRoot;
    }

/// In place rendering (port, not in GPUI: see `renderInPlace`)

    /**
     * Whether a view that is dirty only because of its own reads (a tracked
     * field it read changed, `cx.notify()`, `Component.notify()`) and whose bounds
     * do not change is rendered again alone, in place, without rendering
     * its ancestors (see `renderInPlace`). On by default
     * (`defaultInPlaceRendering`); the frames drawn are the same either way.
     */
    public var inPlaceRendering:Bool = defaultInPlaceRendering;

    /**
     * The default of `inPlaceRendering`.
     */
    public static var defaultInPlaceRendering:Bool = true;

    /**
     * Number of views rendered in place during the last frame (0 when the
     * last frame was drawn whole), for tests and benchmarks.
     */
    public var inPlaceViewCount(default, null):Int = 0;

    /**
     * Number of frames drawn in place since the window was opened, for
     * tests and benchmarks.
     */
    public var inPlaceFrameCount(default, null):Int = 0;

    /**
     * Number of frames drawn in place by every window since the start, for
     * tests and benchmarks.
     */
    public static var inPlaceFramesDrawn(default, null):Int = 0;

    /**
     * Number of in place renderings that gave way to a full frame (the
     * view's bounds changed...) since the window was opened, for tests.
     */
    public var inPlaceFallbackCount(default, null):Int = 0;

    /** Above this number of dirty views, a full frame is drawn (see `renderInPlace`) */
    static inline final MAX_IN_PLACE_VIEWS = 16;

    /** The time of the last position recorded (see `PrepaintStateIndex.time`) */
    var captureClock:Float = 0;

    /** Number of full frames drawn (`Frame.serial`) */
    var frameSerial:Int = 0;

    /** While `drawFrame` collects the dirty views (see `markViewDirty`) */
    var collectingDirtyViews:Bool = false;

    /** The views dirty themselves at the start of this draw */
    final dirtyRootIds:Array<Int> = [];

    final dirtyRootSet:IntMap<Bool> = new IntMap();

    /**
     * Views that requested an animation frame since the last draw, and
     * those that did before it (consulted by the draw). An animated view
     * renders with its ancestors, like in GPUI: code written for GPUI often
     * animates a parent from what its animated children do (a stack of
     * toasts following its entering toast), relying on the parent rendering
     * on each frame of the child's animation.
     */
    var animationViews:IntMap<Bool> = new IntMap();

    var drawnAnimationViews:IntMap<Bool> = new IntMap();

    /** The dirty views to render in place (outermost ones), in tree order */
    final inPlaceRoots:Array<Int> = [];

    /** While a view renders in place: the frame being drawn is the last frame (`nextFrame == renderedFrame`) */
    @:allow(glaze)
    var amending:Bool = false;

    /**
     * The view elements that requested their layout inside the view
     * rendering in place (their `layoutAccessed*` fields index the amended
     * frame): when the render is handed to a full frame, they follow the
     * element states it accessed (see `ViewElement.takePreRendered`).
     */
    @:allow(glaze)
    final amendLayoutElements:Array<ViewElement> = [];

    /** Number of in place renderings so far (`ViewElementState.amendSerial`) */
    var amendSerial:Int = 0;

    /** The view states recorded by the current in place rendering */
    final amendStates:Array<ViewElement.ViewElementState> = [];

    /** The views rendered by the current in place rendering */
    final amendRenderedIds:Array<Int> = [];

    /** The views notified while the current in place rendering renders */
    final amendPendingIds:Array<Int> = [];

    /** What the views rendered in place in this frame accessed before */
    final amendOldAccessed:Array<Int> = [];

    /** The views rendered in place in this frame */
    final inPlaceRenderedIds:Array<Int> = [];

    final amendedViews:IntMap<Bool> = new IntMap();

    /** The views that were drawn inside the replaced ranges (their trackers stop if they are not drawn anymore) */
    final inPlaceOldViews:Array<Int> = [];

    /** Whether an in place rendering of this frame dropped element states */
    var inPlaceDroppedStates:Bool = false;

    /** The entities accessed outside of any view during the last frame */
    final lastFrameAccessed:AccessedEntities = new AccessedEntities();

    /**
     * While a view paints in place, into `inPlaceScene` and `inPlaceTabStops`:
     * the frame's scene and tab order, which the ranges of the views it
     * reuses index.
     */
    var sceneSource:Null<Scene> = null;

    var tabStopsSource:Null<TabStopMap> = null;

    /**
     * What to subtract from an index recorded by a view to get its place in
     * `sceneSource` and `tabStopsSource`: the ranges of the views follow the
     * views rendered in place before in this frame, the sources are the
     * scene and the tab order as they were when the frame started (see
     * `inPlaceNewScene`).
     */
    var sceneSourceShift:Int = 0;

    var tabStopsSourceShift:Int = 0;

    /**
     * The scene of a frame drawn in place is made again once, whatever the
     * number of views rendered: each view replays the operations of the
     * frame's scene from the end of the previous view (`inPlaceSceneCursor`,
     * an index of the frame's scene, which stays as it was until the last
     * view is done) up to its own range, then its own operations, into this
     * scene (the spare frame's); the last view replays the rest. Null until
     * a view needs the scene made again. Meanwhile the indices recorded by
     * the views are those of the scene being made: `inPlaceSceneShift` is
     * what the views rendered so far added to the indices after them.
     * `flushInPlaceScene` ends it early (a full frame takes over).
     */
    var inPlaceNewScene:Null<Scene> = null;

    var inPlaceSceneCursor:Int = 0;

    var inPlaceSceneShift:Int = 0;

    /** Same as `inPlaceNewScene`, for the tab order */
    var inPlaceNewTabs:Null<TabStopMap> = null;

    var inPlaceTabsCursor:Int = 0;

    var inPlaceTabsShift:Int = 0;

    /**
     * For tests: the scene and the tab order are made again after each
     * view rendered in place (one replay of the scene per view), which is
     * also what a view whose ranges do not follow those of the previous
     * one gets (see `amendView`). The frames drawn are the same.
     */
    @:noCompletion
    public static var inPlaceReplayPerView:Bool = false;

    #if glaze_debug_counters
    /**
     * Number of primitives replayed to make the scene again around the
     * views rendered in place during the last frame drawn in place (those
     * of the scene and those the views painted; what is painted after the
     * tree is not replayed), for tests (`glaze_debug_counters`).
     */
    public var inPlaceReplayedPrimitives(default, null):Int = 0;
    #end

    /** What the view rendered in place paints (then replayed in the frame's scene and tab order) */
    final inPlaceScene:Scene = new Scene();

    final inPlaceTabStops:TabStopMap = new TabStopMap();

    /** The focus when the frame drawn in place started */
    var inPlaceFocusAtStart:Null<FocusHandle> = null;

    /** The capture time when the current in place rendering started */
    var amendStartTime:Float = 0;

    /** A view rendered by an in place rendering that gave way to a full frame */
    var preRenderedView:Null<ViewElement.PreRenderedView> = null;

    // The splices of an in place rendering, one per array (see `FrameSplice`)
    final spliceHitboxes:FrameSplice = new FrameSplice();
    final spliceTooltips:FrameSplice = new FrameSplice();
    final spliceDeferred:FrameSplice = new FrameSplice();
    final spliceNodes:FrameSplice = new FrameSplice();
    final spliceAccessed:FrameSplice = new FrameSplice();
    final spliceMouse:FrameSplice = new FrameSplice();
    final spliceInput:FrameSplice = new FrameSplice();
    final spliceRegions:FrameSplice = new FrameSplice();
    final spliceCursors:FrameSplice = new FrameSplice();
    final spliceScene:FrameSplice = new FrameSplice();
    final spliceTabs:FrameSplice = new FrameSplice();
    final spliceLines:FrameSplice = new FrameSplice();
    final spliceWrappedLines:FrameSplice = new FrameSplice();
    final spliceLinesByHash:FrameSplice = new FrameSplice();
    final spliceWrappedLinesByHash:FrameSplice = new FrameSplice();

    final hitboxScratch:Array<Hitbox> = [];
    final tooltipScratch:Array<TooltipRequest> = [];
    final deferredScratch:Array<DeferredDraw> = [];
    final accessedScratch:Array<ElementStateBox<Dynamic>> = [];
    final mouseScratch:Array<MouseListenerEntry> = [];
    final inputScratch:Array<Null<PlatformInputHandler>> = [];
    final regionScratch:Array<TextInputRegion> = [];
    final cursorScratch:Array<CursorStyleRequest> = [];

    /** The ranges of the view rendered in place, as recorded in the frame */
    final amendOldPrepaintStart:PrepaintStateIndex = new PrepaintStateIndex();
    final amendOldPrepaintEnd:PrepaintStateIndex = new PrepaintStateIndex();
    final amendOldPaintStart:PaintIndex = new PaintIndex();
    final amendOldPaintEnd:PaintIndex = new PaintIndex();

    /** Whether the view rendering in place is the last one of the frame (see `amendView`) */
    var amendLast:Bool = false;

    /**
     * With the last view rendered in place: where what is drawn after the
     * tree (deferred draws, tooltip) starts and ends in the entries
     * appended to the frame.
     */
    final amendTailPrepaintStart:PrepaintStateIndex = new PrepaintStateIndex();
    final amendTailPrepaintEnd:PrepaintStateIndex = new PrepaintStateIndex();
    final amendTailPaintStart:PaintIndex = new PaintIndex();
    final amendTailPaintEnd:PaintIndex = new PaintIndex();

    /**
     * The capture time when the tooltip requests were spliced (before what
     * is drawn after the tree): the indices captured later are final.
     */
    var amendTooltipsTime:Float = 0;

    /** Where the line layouts used by the view rendered in place start, and their count */
    final amendLineBase:LineLayoutIndex = new LineLayoutIndex();
    final amendLineEnd:LineLayoutIndex = new LineLayoutIndex();

    final droppedStateCandidates:Array<ElementStateBox<Dynamic>> = [];

    /** Fills the accessed element states of a full frame drawn after an in place rendering gave way (`handOffInPlace`) */
    final unusedStateBox:ElementStateBox<Dynamic> = @:privateAccess new ElementStateBox<Dynamic>(GlobalElementId.root(), -1, null);

    var stateMark:Int = 0;

    /**
     * Depth of the shared contexts being drawn. An element that hands its
     * descendants something outside of the window's stacks (an app global
     * they read while they prepaint or paint, like gpui-kit's text view
     * state, table cell or text selection scope) enters one around them
     * (`enterSharedContext`, `exitSharedContext`): the views drawn inside
     * are never rendered alone, in place, since their ancestor's prepaint
     * and paint must run around them (see `renderInPlace`).
     */
    static var sharedContextDepth:Int = 0;

    /** Enters a shared context (see `sharedContextDepth`) */
    public static inline function enterSharedContext():Void {
        sharedContextDepth++;
    }

    /** Exits a shared context (see `sharedContextDepth`) */
    public static inline function exitSharedContext():Void {
        sharedContextDepth--;
    }

    /** Whether a shared context is being drawn (see `sharedContextDepth`) */
    @:allow(glaze)
    static inline function inSharedContext():Bool {
        return sharedContextDepth > 0;
    }

    /** A new capture time (see `PrepaintStateIndex.time`) */
    @:allow(glaze)
    inline function captureTime():Float {
        return ++captureClock;
    }

    /**
     * The layout frame whose view caches can be reused: the previous one,
     * or while a view renders in place, the frame it renders in.
     */
    @:allow(glaze)
    inline function reusableFrame():Int {
        return amending ? layoutFrame() : layoutFrame() - 1;
    }

    /**
     * Records that the ranges of a view's cache state index the frame being
     * drawn (see `Frame.viewStates`).
     */
    @:allow(glaze)
    function registerViewState(state:ViewElement.ViewElementState):Void {
        final frame = nextFrame;
        if (state.registeredSerial != frame.serial) {
            state.registeredSerial = frame.serial;
            frame.viewStates.push(state);
        }
        if (amending && state.amendSerial != amendSerial) {
            state.amendSerial = amendSerial;
            amendStates.push(state);
        }
        final model = state.model;
        if (model != null) {
            var tracker = state.tracker;
            if (tracker == null || @:privateAccess tracker.destroyed || tracker.viewId != model.entityId || tracker.window != this) {
                tracker = trackers.get(model.entityId);
                state.tracker = tracker;
            }
            if (tracker != null) {
                if (tracker.stateSerial != frame.serial) {
                    tracker.stateSerial = frame.serial;
                    tracker.stateCount = 1;
                    tracker.state = state;
                }
                else if (tracker.state != state) {
                    // Drawn twice in the frame
                    tracker.stateCount++;
                    tracker.state = state;
                }
            }
        }
    }

    /** A view was drawn without view caching (it renders on every frame) */
    @:allow(glaze)
    inline function markUncachedViewDrawn():Void {
        nextFrame.hasUncachedViews = true;
    }

    /**
     * Moves the element states accessed at `start...end` of the frame being
     * drawn to its end (the slots left hold `unusedStateBox`): the element
     * states a pre-rendered view accessed, recorded before the frame's
     * other entries, take their place in the ranges of its ancestors.
     */
    @:allow(glaze)
    function moveAccessedElementStates(start:Int, end:Int):Void {
        final list = nextFrame.accessedElementStates;
        for (i in start...end) {
            list.push(list[i]);
            list[i] = unusedStateBox;
        }
    }

    /**
     * The render of the given view made by an in place rendering that gave
     * way to this full frame, if it is drawn at the same place.
     */
    @:allow(glaze)
    function takePreRenderedView(viewId:Int, stateId:Null<GlobalElementId>):Null<ViewElement.PreRenderedView> {
        final preRendered = preRenderedView;
        if (preRendered == null || preRendered.viewId != viewId) {
            return null;
        }
        preRenderedView = null;
        if (preRendered.stateId != stateId) {
            // Drawn somewhere else: it renders again
            return null;
        }
        if (!renderedViews.exists(viewId)) {
            renderedViews.set(viewId, true);
            renderedViewCount++;
        }
        return preRendered;
    }

    /**
     * Renders the dirty views alone, in place, when they all can (see
     * `canRenderViewInPlace`). Returns false when nothing was done (a full
     * frame must be drawn); true when the frame is drawn, in place, or
     * whole when a view's bounds changed (the view does not render twice).
     *
     * GPUI renders the ancestors of a dirty view again (`mark_view_dirty`,
     * window.rs:1395): one changed row of a long list renders the list,
     * which walks all its cached rows. Here, a view dirty only because of
     * its own reads is rendered, laid out (its subtree, at its bounds),
     * prepainted and painted again alone, in the context its ancestors gave
     * it in the last frame, and its new entries replace its old ones in each
     * array of the last frame (hitboxes, dispatch nodes, listeners, element
     * states, line layouts...), keeping their place in drawing and hit test
     * order (see `FrameSplice`). The scene and the tab order are made again
     * around it (replayed). The frame is the one a full frame would draw: the
     * ancestors would only render the same elements again (a view renders
     * the same while what it read is unchanged, what `glaze_verify_cache`
     * checks). When its bounds change, or anything else makes the frame
     * depend on more than the view (see the conditions), a full frame is
     * drawn, like in GPUI.
     */
    function renderInPlace():Bool {
        if (!canRenderInPlace()) {
            return false;
        }
        final tree = renderedFrame.dispatchTree;
        final roots = inPlaceRoots;
        roots.resize(0);
        final ids = dirtyRootIds;
        for (i in 0...ids.length) {
            final viewId = ids[i];
            // A view not drawn in the last frame has no place, and a view
            // inside another dirty view renders with it
            if (tree.viewNodeId(viewId) != -1 && !hasDirtyAncestor(viewId)) {
                roots.push(viewId);
            }
        }
        // Many views, or views drawing most of the frame: a full frame
        // costs the same or less (each view rendered in place moves the
        // entries drawn after it; the scene is made again once)
        if (roots.length == 0 || roots.length > MAX_IN_PLACE_VIEWS) {
            return false;
        }
        var covered = 0;
        for (i in 0...roots.length) {
            if (!canRenderViewInPlace(roots[i])) {
                return false;
            }
            final state = trackers.get(roots[i]).state;
            covered += state.prepaintEnd.dispatchTreeIndex - state.prepaintStart.dispatchTreeIndex;
        }
        if (covered * 2 > tree.len()) {
            return false;
        }
        if (!deferredDrawsReplaceable(roots)) {
            return false;
        }
        // In tree order (dispatch nodes are in tree order)
        for (i in 1...roots.length) {
            final viewId = roots[i];
            final node = trackers.get(viewId).state.dispatchNode;
            var j = i - 1;
            while (j >= 0 && trackers.get(roots[j]).state.dispatchNode > node) {
                roots[j + 1] = roots[j];
                j--;
            }
            roots[j + 1] = viewId;
        }

        dirty = false;
        #if glaze_verify_cache
        clearHoverLog();
        #end
        renderedViews.clear();
        renderedViewCount = 0;
        reusedViewCount = 0;
        inPlaceViewCount = 0;
        requestedAutoscroll = null;
        restorePlatformInputHandler();
        // The dirty views themselves, not their ancestors
        for (i in 0...ids.length) {
            dirtyViews.set(ids[i], true);
        }
        final previousFocusPath = renderedFrame.focusPath();
        final previousWindowActive = renderedFrame.windowActive;
        inPlaceFocusAtStart = _focus;
        inPlaceRenderedIds.resize(0);
        amendedViews.clear();
        inPlaceOldViews.resize(0);
        amendOldAccessed.resize(0);
        inPlaceDroppedStates = false;
        resetInPlaceScene();
        #if glaze_debug_counters
        inPlaceReplayedPrimitives = 0;
        #end

        // The deferred draws of the frame are drawn again by the views
        // rendered (see `deferredDrawsReplaceable`): their elements are
        // gone with the frame that drew them
        final frame = renderedFrame;
        final hadDeferredDraws = frame.deferredDraws.length > 0;
        for (draw in frame.deferredDraws) {
            draw.element = null;
        }
        // What the first views paint under, when several render: the
        // deferred draws of the last frame (those of this frame are
        // prepainted once, with the last view)
        final several = roots.length > 1;
        final hitboxesAbove = several ? deferredHitTestEffect(frame, frame.deferredPrepaintStart.hitboxesIndex) : 0;

        for (i in 0...roots.length) {
            if (!amendView(roots[i], i == roots.length - 1)) {
                // A full frame (its ancestors render), where the view uses
                // the render it just made
                inPlaceFallbackCount++;
                // The scene made so far is completed: the full frame reuses
                // its ranges
                flushInPlaceScene();
                dirtyViews.clear();
                // The deferred draws of the views rendered so far are not
                // drawn yet (they are with the last view): these views
                // render again with the frame
                final renderAgain = hadDeferredDraws || frame.deferredDraws.length > 0;
                for (j in 0...ids.length) {
                    if (renderAgain || !amendedViews.exists(ids[j])) {
                        markViewDirty(ids[j]);
                    }
                }
                drawFullFrame(false);
                return true;
            }
        }
        if (several && deferredHitTestEffect(frame, frame.deferredPrepaintStart.hitboxesIndex) != hitboxesAbove) {
            // The deferred draws hide the mouse from the tree, or show it,
            // unlike those the first views were painted under: a full
            // frame, where every view rendered paints with the hit test of
            // the frame
            inPlaceFallbackCount++;
            dirtyViews.clear();
            for (j in 0...ids.length) {
                markViewDirty(ids[j]);
            }
            drawFullFrame(false);
            return true;
        }
        finishInPlaceFrame(previousFocusPath, previousWindowActive);
        return true;
    }

    /**
     * Whether the deferred draws of the last frame can be drawn again by
     * the views to render in place alone: each one was deferred by one of
     * these views (their ranges cover the whole list), none was deferred by
     * another deferred draw (nested), and nothing else was drawn after the
     * tree. The deferred draws are then prepainted and painted again as a
     * whole, once, after the tree, in the order of a full frame (see
     * `amendView`). Anything else: a full frame.
     */
    function deferredDrawsReplaceable(roots:Array<Int>):Bool {
        final frame = renderedFrame;
        final prepaintStart = frame.deferredPrepaintStart;
        final paintEnd = frame.deferredPaintEnd;
        // What the deferred draws recorded ends the frame's arrays
        if (frame.deferredPrepaintEnd.hitboxesIndex != frame.hitboxes.length || frame.deferredPrepaintEnd.tooltipsIndex != frame.tooltipRequests.length
            || frame.deferredPrepaintEnd.dispatchTreeIndex != frame.dispatchTree.len() || frame.deferredPrepaintEnd.deferredDrawsIndex != frame.deferredDraws.length
            || paintEnd.sceneIndex != frame.scene.paintIndex() || paintEnd.mouseListenersIndex != frame.mouseListeners.length
            || paintEnd.inputHandlersIndex != frame.inputHandlers.length || paintEnd.textInputRegionsIndex != frame.textInputRegions.length
            || paintEnd.cursorStylesIndex != frame.cursorStyles.length || paintEnd.tabHandleIndex != frame.tabStops.paintIndex()) {
            return false;
        }
        final count = frame.deferredDraws.length;
        if (count == 0) {
            return true;
        }
        // No nested deferred draw (deferred after the tree)
        if (prepaintStart.deferredDrawsIndex != count) {
            return false;
        }
        var covered = 0;
        for (i in 0...roots.length) {
            final state = trackers.get(roots[i]).state;
            final start = state.prepaintStart.deferredDrawsIndex;
            final end = state.prepaintEnd.deferredDrawsIndex;
            if (start < 0 || end < start || end > count) {
                return false;
            }
            covered += end - start;
        }
        return covered == count;
    }

    /**
     * What the hitboxes from `start` on (those of the deferred draws) do to
     * the hit test of the tree at the mouse position: 2 when they block it,
     * 1 when they end the hovered ones (`BlockMouseExceptScroll`), 0 otherwise.
     */
    function deferredHitTestEffect(frame:Frame, start:Int):Int {
        final hitboxes = frame.hitboxes;
        final position = _mousePosition;
        var effect = 0;
        var i = hitboxes.length - 1;
        while (i >= start) {
            final hitbox = hitboxes[i];
            if (hitbox.bounds.intersectContains(hitbox.contentMask.bounds, position)) {
                if (hitbox.behavior == BlockMouse) {
                    return 2;
                }
                if (hitbox.behavior == BlockMouseExceptScroll) {
                    effect = 1;
                }
            }
            i--;
        }
        return effect;
    }

    /** Whether a view of the last frame has an ancestor view that is dirty itself */
    function hasDirtyAncestor(viewId:Int):Bool {
        final tree = renderedFrame.dispatchTree;
        var nodeId = tree.node(tree.viewNodeId(viewId)).parent;
        while (nodeId != -1) {
            final node = tree.node(nodeId);
            final nodeViewId = node.viewId;
            if (nodeViewId != -1 && dirtyRootSet.exists(nodeViewId)) {
                return true;
            }
            nodeId = node.parent;
        }
        return false;
    }

    /**
     * Whether the last frame can be changed in place (nothing of the window
     * changed since, nothing drawn after the tree...).
     */
    function canRenderInPlace():Bool {
        if (!inPlaceRendering || !viewCaching || viewCachingDisabled || refreshing || drawingClean || root == null) {
            return false;
        }
        final frame = renderedFrame;
        if (frame.serial == 0 || frame.rootView != root || frame.hasUncachedViews || frame.hadRollback) {
            return false;
        }
        // Drawn after the tree: a tooltip or a dragged view depend on more
        // than the views rendered (the deferred draws are checked with the
        // views to render, see `deferredDrawsReplaceable`)
        if (tooltipBounds != null || app.activeDrag != null || frame.hadDrag) {
            return false;
        }
        if (frame.scaleFactor != _scaleFactor || renderable.sceneScale != _scaleFactor || frame.remSize != _remSize
            || frame.viewportWidth != _viewportSize.width || frame.viewportHeight != _viewportSize.height
            || frame.windowActive != _active || windowTextSystem.fontGenerationChanged()) {
            return false;
        }
        #if glaze_inspector
        if (inspector != null || isInspectorPicking(app)) {
            return false;
        }
        #end
        return true;
    }

    /**
     * Whether the given dirty view can render alone: drawn once in the last
     * frame, with default caching, outside of a view cached with a style,
     * not the root, outside of any group, in the same context in its three
     * phases.
     */
    function canRenderViewInPlace(viewId:Int):Bool {
        final tracker = trackers.get(viewId);
        if (tracker == null || !tracker.defaultCaching || drawnAnimationViews.exists(viewId)) {
            return false;
        }
        final state = tracker.state;
        final frame = renderedFrame;
        if (state == null || tracker.stateSerial != frame.serial || tracker.stateCount != 1 || state.cachedStyle) {
            return false;
        }
        final drawn = layoutFrame() - 1;
        if (state.layoutFrame != drawn || state.prepaintFrame != drawn || state.paintFrame != drawn || state.registeredSerial != frame.serial) {
            return false;
        }
        if (state.model == null || state.stateId == null || state.layoutNodes == null || state.layoutId == -1
            || layoutEngine.parentOf(state.layoutId) == -1) {
            return false;
        }
        if (state.groupHitboxes != null || state.inSharedContext || state.dispatchNode == -1 || frame.dispatchTree.viewNodeId(viewId) != state.dispatchNode) {
            return false;
        }
        if (state.bounds == null || state.contentMask == null || state.paintContentMask == null || state.elementOffset == null
            || state.textStyle == null || state.layoutTextStyle == null || state.paintTextStyle == null) {
            return false;
        }
        if (!state.textStyle.equals(state.layoutTextStyle) || !state.textStyle.equals(state.paintTextStyle)
            || state.paintRemSize != state.remSize || state.paintImageCache != state.imageCache) {
            return false;
        }
        // Its text style, as one refinement of the default one
        if (state.inPlaceTextStyle != state.textStyle
            && (state.inPlaceTextStyle == null || !state.inPlaceTextStyle.equals(state.textStyle))) {
            final refinement = state.textStyle.subtract(new TextStyleRefinement());
            final composed = new TextStyle();
            composed.refine(refinement);
            state.inPlaceTextStyle = state.textStyle;
            state.inPlaceTextStyleRefinement = composed.equals(state.textStyle) ? refinement : null;
        }
        return state.inPlaceTextStyleRefinement != null;
    }

    /**
     * Renders, lays out, prepaints and paints a view again alone, in the
     * last frame (see `renderInPlace`). Returns false when its bounds
     * changed, or when its render notified a view drawn elsewhere (GPUI
     * would draw that view in this frame): the render is kept for a full
     * frame (`preRenderedView`), nothing else was changed.
     *
     * `last`: the last view rendered in place in this frame. What a frame
     * draws after the tree is drawn with it, once: the deferred draws of
     * the frame (all deferred by the views rendered in place, see
     * `deferredDrawsReplaceable`: those the views rendered before it
     * deferred, its own, and those of the views they reuse) are prepainted
     * after its prepaint and painted after its paint, in the order of a
     * full frame, and their entries replace those of the deferred draws of
     * the last frame, removed as a whole.
     */
    function amendView(viewId:Int, last:Bool):Bool {
        final state = trackers.get(viewId).state;
        final frame = renderedFrame;
        amendLast = last;
        final tailPrepaintStart = frame.deferredPrepaintStart;
        final tailPrepaintEnd = frame.deferredPrepaintEnd;
        final tailPaintStart = frame.deferredPaintStart;
        final tailPaintEnd = frame.deferredPaintEnd;
        final newTailPrepaintStart = amendTailPrepaintStart;
        final newTailPrepaintEnd = amendTailPrepaintEnd;
        final newTailPaintStart = amendTailPaintStart;
        final newTailPaintEnd = amendTailPaintEnd;
        final spare = nextFrame;
        final tree = frame.dispatchTree;
        final engine = layoutEngine;

        // The view's ranges in the frame
        final oldPrepaintStart = amendOldPrepaintStart;
        final oldPrepaintEnd = amendOldPrepaintEnd;
        final oldPaintStart = amendOldPaintStart;
        final oldPaintEnd = amendOldPaintEnd;
        oldPrepaintStart.copyFrom(state.prepaintStart);
        oldPrepaintEnd.copyFrom(state.prepaintEnd);
        oldPaintStart.copyFrom(state.paintStart);
        oldPaintEnd.copyFrom(state.paintEnd);
        final oldLayoutAccessedStart = state.layoutAccessedStart;
        final oldLayoutAccessedEnd = state.layoutAccessedEnd;
        final oldLayoutAccessedStartTime = state.layoutAccessedStartTime;
        final oldLayoutAccessedEndTime = state.layoutAccessedEndTime;
        final oldLayoutId = state.layoutId;
        final viewNode = state.dispatchNode;
        final oldViewsStart = inPlaceOldViews.length;
        for (i in oldPrepaintStart.dispatchTreeIndex...oldPrepaintEnd.dispatchTreeIndex) {
            final nodeViewId = tree.node(i).viewId;
            if (nodeViewId != -1) {
                inPlaceOldViews.push(nodeViewId);
            }
        }
        // The views drawn by the deferred draws of the last frame (replaced
        // with the last view; those laid out inside this view are not
        // reusable after it either way, see `remapViewStates`)
        for (i in tailPrepaintStart.dispatchTreeIndex...tree.len()) {
            final nodeViewId = tree.node(i).viewId;
            if (nodeViewId != -1) {
                inPlaceOldViews.push(nodeViewId);
            }
        }

        // Its new entries are appended (see `FrameSplice`)
        final baseHitboxes = frame.hitboxes.length;
        final baseTooltips = frame.tooltipRequests.length;
        final baseDeferred = frame.deferredDraws.length;
        final baseNodes = tree.len();
        final baseAccessed = frame.accessedElementStates.length;
        final baseMouse = frame.mouseListeners.length;
        final baseInput = frame.inputHandlers.length;
        final baseRegions = frame.textInputRegions.length;
        final baseCursors = frame.cursorStyles.length;
        // One pass over the scene and the tab order for all the views (see
        // `inPlaceNewScene`) needs the ranges of this view after those of
        // the previous one, and what is drawn after the tree after them
        // all. Otherwise what was made so far is completed first, and the
        // view starts from it (one replay per view, as before)
        if (inPlaceNewScene != null || inPlaceNewTabs != null) {
            if (inPlaceReplayPerView
                || state.paintStart.sceneIndex - inPlaceSceneShift < inPlaceSceneCursor
                || state.paintStart.tabHandleIndex - inPlaceTabsShift < inPlaceTabsCursor
                || state.paintEnd.sceneIndex < state.paintStart.sceneIndex
                || state.paintEnd.tabHandleIndex < state.paintStart.tabHandleIndex
                || (last && (tailPaintStart.sceneIndex < state.paintEnd.sceneIndex || tailPaintStart.tabHandleIndex < state.paintEnd.tabHandleIndex))) {
                flushInPlaceScene();
            }
        }
        // The frame's scene and tab order, as they were when the frame
        // started (unless completed above); the lengths and the indices of
        // the views are those of the scene and tab order being made
        final sceneShift = inPlaceSceneShift;
        final tabsShift = inPlaceTabsShift;
        final oldScene = frame.scene;
        final oldTabs = frame.tabStops;
        final oldSceneLength = oldScene.paintIndex() + sceneShift;
        final oldTabsLength = oldTabs.paintIndex() + tabsShift;

        amending = true;
        frame.dispatchTree.amending = true;
        amendStartTime = captureClock;
        amendSerial++;
        amendStates.resize(0);
        amendRenderedIds.resize(0);
        amendPendingIds.resize(0);
        amendLayoutElements.resize(0);
        nextFrame = frame;
        engine.beginAmend();
        windowTextSystem.beginAmend();
        windowTextSystem.layoutIndexInto(amendLineBase);

        // The context its ancestors gave it
        final imageCache = state.imageCache;
        remSizeOverrideStack.push(state.remSize);
        if (imageCache != null) {
            imageCacheStack.push(imageCache);
        }

        // 1: the view paints into a scene of its own; 2: what is drawn
        // after the tree paints into the scene made again
        var scenesSwapped = 0;
        // Whether this rendering added to the scene or the tab order being
        // made (they cannot be completed anymore if it throws)
        var replayed = false;
        try {
            // Render and layout of its subtree, its nodes adopted
            elementIdNode = state.stateId;
            pushTextStyle(state.inPlaceTextStyleRefinement);
            final element = ViewElement.forInPlace(state);
            final reference = engine.beginViewChanges(oldLayoutId);
            final layoutId = element.renderInPlace(state, this, app);
            popTextStyle();
            elementIdNode = elementIdRoot;
            if (layoutId != oldLayoutId) {
                engine.replaceViewRoot(oldLayoutId, layoutId);
            }
            // In place when every change settles inside the view (its root
            // lays out the same for its parent) and its bounds are the same
            var inPlace = engine.processViewChanges(layoutId, oldLayoutId, reference, this, app);
            var bounds:Null<Bounds> = null;
            if (inPlace) {
                engine.forgetSubtreeBounds(layoutId);
                elementOffsetStack.push(state.elementOffset);
                bounds = layoutBounds(layoutId);
                elementOffsetStack.pop();
                inPlace = bounds.equals(state.bounds) && !notifiedElsewhere(viewNode, oldPrepaintEnd.dispatchTreeIndex);
            }
            if (!inPlace) {
                handOffInPlace(viewId, element, baseAccessed, spare, imageCache);
                return false;
            }
            #if glaze_verify_layout
            engine.verifySubtreeLayout(layoutId);
            #end

            // Prepaint, in its bounds
            elementIdNode = state.stateId;
            pushTextStyle(state.inPlaceTextStyleRefinement);
            contentMaskStack.push(state.contentMask);
            elementOffsetStack.push(state.elementOffset);
            final savedPrepaintOpacity = prepaintOpacity;
            prepaintOpacity = state.prepaintOpacity;
            tree.setActiveNode(viewNode);
            element.prepaintInPlace(state, bounds, this, app);
            tree.resetStacks();
            prepaintOpacity = savedPrepaintOpacity;
            elementOffsetStack.pop();
            contentMaskStack.pop();
            popTextStyle();
            elementIdNode = elementIdRoot;

            // The tooltip requests in place (the tooltip reads them; with
            // the last view, those of the deferred draws of the last frame
            // go), then what a frame draws after the tree, once, with the
            // last view: the deferred draws and the tooltip
            final tooltipsLength = frame.tooltipRequests.length;
            spliceTooltips.reset(baseTooltips);
            spliceTooltips.addRange(oldPrepaintStart.tooltipsIndex, oldPrepaintEnd.tooltipsIndex, oldPrepaintStart.time, oldPrepaintEnd.time,
                state.prepaintStart.tooltipsIndex, state.prepaintEnd.tooltipsIndex, state.prepaintStart.time, state.prepaintEnd.time);
            if (last) {
                spliceTooltips.addRange(tailPrepaintStart.tooltipsIndex, baseTooltips, tailPrepaintStart.time, tailPrepaintEnd.time,
                    tooltipsLength, tooltipsLength, -1, -1);
            }
            spliceTooltips.prepare(tooltipsLength);
            FrameSplice.apply(frame.tooltipRequests, spliceTooltips, tooltipScratch);
            amendTooltipsTime = captureClock;
            var tooltipElement:Null<AnyElement> = null;
            if (last) {
                deferredSkipStart = oldPrepaintStart.deferredDrawsIndex;
                deferredSkipEnd = oldPrepaintEnd.deferredDrawsIndex;
                prepaintIndexInto(newTailPrepaintStart);
                prepaintDeferredDraws();
                tooltipElement = prepaintTooltip();
                prepaintIndexInto(newTailPrepaintEnd);
            }
            spliceHitboxes.reset(baseHitboxes);
            spliceHitboxes.addRange(oldPrepaintStart.hitboxesIndex, oldPrepaintEnd.hitboxesIndex, oldPrepaintStart.time, oldPrepaintEnd.time,
                state.prepaintStart.hitboxesIndex, state.prepaintEnd.hitboxesIndex, state.prepaintStart.time, state.prepaintEnd.time);
            if (last) {
                spliceHitboxes.addRange(tailPrepaintStart.hitboxesIndex, baseHitboxes, tailPrepaintStart.time, tailPrepaintEnd.time,
                    newTailPrepaintStart.hitboxesIndex, newTailPrepaintEnd.hitboxesIndex, newTailPrepaintStart.time, newTailPrepaintEnd.time);
            }
            spliceHitboxes.prepare(frame.hitboxes.length);
            // The views rendered before the last one paint under the
            // deferred draws of the last frame (see `renderInPlace`)
            mouseHitTest = hitTestInPlace(_mousePosition, frame.hitboxes, spliceHitboxes, last ? tailPrepaintStart.hitboxesIndex : baseHitboxes);

            // Paint, into a scene and a tab order of its own (replayed below)
            final viewScene = inPlaceScene;
            final viewTabs = inPlaceTabStops;
            frame.scene = viewScene;
            frame.tabStops = viewTabs;
            sceneSource = oldScene;
            tabStopsSource = oldTabs;
            sceneSourceShift = sceneShift;
            tabStopsSourceShift = tabsShift;
            scenesSwapped = 1;
            elementIdNode = state.stateId;
            pushTextStyle(state.inPlaceTextStyleRefinement);
            contentMaskStack.push(state.paintContentMask);
            final savedOpacity = elementOpacity;
            elementOpacity = state.paintOpacity;
            tree.setActiveNode(viewNode);
            element.paintInPlace(state, this, app);
            tree.resetStacks();
            elementOpacity = savedOpacity;
            contentMaskStack.pop();
            popTextStyle();
            elementIdNode = elementIdRoot;

            // The scene is made again around its operations (replayed, so
            // draw orders are computed as in a full frame), unless no view
            // had or has any so far (out of view); the tab order only when
            // the tab operations of a view changed. Once for the frame: this
            // view continues what the views before it started (see
            // `inPlaceNewScene`), from where they stopped in the frame's
            // scene to its own range, then its operations
            // With the last view, the rest of the tree follows; the tree
            // ends where the deferred draws of the last frame start: they
            // are left out, what is drawn after the tree in this frame is
            // painted after it
            final viewOps = viewScene.paintIndex();
            final treeSceneEnd = last ? tailPaintStart.sceneIndex : oldSceneLength;
            final treeTabsEnd = last ? tailPaintStart.tabHandleIndex : oldTabsLength;
            final paintsAfter = last && (tooltipElement != null || frame.deferredDraws.length > deferredSkipEnd - deferredSkipStart);
            replayed = true;
            var scene = inPlaceNewScene;
            if (scene == null && (viewOps > 0 || oldPaintEnd.sceneIndex > oldPaintStart.sceneIndex || treeSceneEnd < oldSceneLength || paintsAfter)) {
                scene = spare.scene;
                inPlaceNewScene = scene;
                inPlaceSceneCursor = 0;
            }
            if (scene != null) {
                #if glaze_debug_counters
                final primitivesBefore = scene.len();
                #end
                scene.replay(inPlaceSceneCursor, oldPaintStart.sceneIndex - sceneShift, oldScene);
                scene.replay(0, viewOps, viewScene);
                inPlaceSceneCursor = oldPaintEnd.sceneIndex - sceneShift;
                if (last) {
                    scene.replay(inPlaceSceneCursor, treeSceneEnd - sceneShift, oldScene);
                }
                #if glaze_debug_counters
                inPlaceReplayedPrimitives += scene.len() - primitivesBefore;
                #end
            }
            inPlaceSceneShift = sceneShift + viewOps - (oldPaintEnd.sceneIndex - oldPaintStart.sceneIndex);
            final viewTabOps = viewTabs.paintIndex();
            var tabs = inPlaceNewTabs;
            if (tabs == null && (treeTabsEnd < oldTabsLength || paintsAfter
                || !sameTabOperations(viewTabs, oldTabs, oldPaintStart.tabHandleIndex - tabsShift, oldPaintEnd.tabHandleIndex - tabsShift))) {
                tabs = spare.tabStops;
                inPlaceNewTabs = tabs;
                inPlaceTabsCursor = 0;
            }
            if (tabs != null) {
                tabs.replayRange(oldTabs, inPlaceTabsCursor, oldPaintStart.tabHandleIndex - tabsShift);
                tabs.replayRange(viewTabs, 0, viewTabOps);
                inPlaceTabsCursor = oldPaintEnd.tabHandleIndex - tabsShift;
                if (last) {
                    tabs.replayRange(oldTabs, inPlaceTabsCursor, treeTabsEnd - tabsShift);
                }
            }
            inPlaceTabsShift = tabsShift + viewTabOps - (oldPaintEnd.tabHandleIndex - oldPaintStart.tabHandleIndex);
            viewScene.clear();
            viewTabs.clear();

            var newSceneLength = oldSceneLength + inPlaceSceneShift - sceneShift;
            var newTabsLength = oldTabsLength + inPlaceTabsShift - tabsShift;
            if (last) {
                // Drawn after the tree, into the scene and the tab order
                // made again (the deferred draws reused with a view index
                // the previous ones, still the sources)
                frame.scene = scene != null ? scene : oldScene;
                frame.tabStops = tabs != null ? tabs : oldTabs;
                scenesSwapped = 2;
                paintIndexInto(newTailPaintStart);
                paintDeferredDraws();
                if (tooltipElement != null) {
                    tooltipElement.paint(this, app);
                }
                paintIndexInto(newTailPaintEnd);
                deferredSkipStart = 0;
                deferredSkipEnd = 0;
                sceneSource = null;
                tabStopsSource = null;
                // The frame's scene and tab order are the ones made again
                if (scene != null) {
                    spare.scene = oldScene;
                    oldScene.clear();
                }
                if (tabs != null) {
                    spare.tabStops = oldTabs;
                    oldTabs.clear();
                }
                resetInPlaceScene();
                scenesSwapped = 0;
                replayed = false;
                if (scene != null) {
                    scene.finish();
                }
                newSceneLength = frame.scene.paintIndex();
                newTabsLength = frame.tabStops.paintIndex();
            }
            else {
                // Until the last view: the frame keeps its scene and tab
                // order, the sources of the views rendered next
                frame.scene = oldScene;
                frame.tabStops = oldTabs;
                sceneSource = null;
                tabStopsSource = null;
                scenesSwapped = 0;
            }

            // The new entries in place of the old ones
            spliceInPlace(state, baseDeferred, baseNodes, baseAccessed, baseMouse, baseInput, baseRegions, baseCursors,
                oldLayoutAccessedStart, oldLayoutAccessedEnd, oldLayoutAccessedStartTime, oldLayoutAccessedEndTime,
                oldSceneLength, viewOps, newSceneLength, oldTabsLength, viewTabOps, newTabsLength, oldViewsStart);
            replayed = false;
        }
        catch (e:haxe.Exception) {
            deferredSkipStart = 0;
            deferredSkipEnd = 0;
            if (scenesSwapped != 0) {
                inPlaceScene.clear();
                inPlaceTabStops.clear();
                frame.scene = oldScene;
                frame.tabStops = oldTabs;
                sceneSource = null;
                tabStopsSource = null;
            }
            abortInPlace(spare, imageCache, baseHitboxes, baseTooltips, baseDeferred, baseNodes, baseAccessed, baseMouse, baseInput, baseRegions, baseCursors);
            if (replayed) {
                // The scene being made holds a part of this rendering
                discardInPlaceScene();
            }
            else {
                // What the views rendered before made is completed
                flushInPlaceScene();
            }
            throw glaze.util.Exceptions.rethrow(e);
        }
        endInPlace(spare, imageCache, true);
        for (i in 0...amendRenderedIds.length) {
            final renderedId = amendRenderedIds[i];
            amendedViews.set(renderedId, true);
            inPlaceRenderedIds.push(renderedId);
        }
        inPlaceViewCount++;
        return true;
    }

    inline function resetInPlaceScene():Void {
        inPlaceNewScene = null;
        inPlaceSceneCursor = 0;
        inPlaceSceneShift = 0;
        inPlaceNewTabs = null;
        inPlaceTabsCursor = 0;
        inPlaceTabsShift = 0;
        sceneSourceShift = 0;
        tabStopsSourceShift = 0;
    }

    /**
     * Completes the scene and the tab order being made by the views
     * rendered in place so far (see `inPlaceNewScene`) with the rest of the
     * frame's, which they replace: the indices recorded by the views are
     * those of the frame's scene and tab order again. Called between two
     * views (the frame being drawn is the spare one): before a full frame
     * takes over, or before a view that cannot continue the pass.
     */
    function flushInPlaceScene():Void {
        final frame = renderedFrame;
        final spare = nextFrame;
        final scene = inPlaceNewScene;
        if (scene != null) {
            final old = frame.scene;
            #if glaze_debug_counters
            final primitivesBefore = scene.len();
            #end
            scene.replay(inPlaceSceneCursor, old.paintIndex(), old);
            #if glaze_debug_counters
            inPlaceReplayedPrimitives += scene.len() - primitivesBefore;
            #end
            frame.scene = scene;
            spare.scene = old;
            old.clear();
            scene.finish();
        }
        final tabs = inPlaceNewTabs;
        if (tabs != null) {
            final old = frame.tabStops;
            tabs.replayRange(old, inPlaceTabsCursor, old.paintIndex());
            frame.tabStops = tabs;
            spare.tabStops = old;
            old.clear();
        }
        resetInPlaceScene();
    }

    /**
     * An in place rendering threw after it added to the scene or the tab
     * order being made (see `inPlaceNewScene`): they are dropped, the frame
     * keeps the ones it had when it started. When views were rendered in
     * place before in this frame, the indices of the views do not match
     * them anymore: no view of the frame is reused (the next frame is drawn
     * whole, see `abortInPlace`).
     */
    function discardInPlaceScene():Void {
        if (inPlaceNewScene != null) {
            inPlaceNewScene.clear();
        }
        if (inPlaceNewTabs != null) {
            inPlaceNewTabs.clear();
        }
        if (inPlaceViewCount > 0) {
            for (other in renderedFrame.viewStates) {
                invalidateViewState(other);
            }
        }
        resetInPlaceScene();
    }

    /**
     * Whether the render of the view rendering in place notified a view
     * drawn after it in the last frame (GPUI would render that view in this
     * frame; a view drawn before renders in the next frame either way).
     */
    function notifiedElsewhere(viewNode:Int, rangeEnd:Int):Bool {
        final tree = renderedFrame.dispatchTree;
        for (i in 0...amendPendingIds.length) {
            final node = tree.viewNodeId(amendPendingIds[i]);
            if (node != -1 && node >= rangeEnd) {
                return true;
            }
        }
        return false;
    }

    /** Whether the tab operations of `view` are those of `tabs` from `start` to `end` */
    static function sameTabOperations(view:TabStopMap, tabs:TabStopMap, start:Int, end:Int):Bool {
        final ops = view.insertionHistory;
        if (ops.length != end - start) {
            return false;
        }
        final history = tabs.insertionHistory;
        for (i in 0...ops.length) {
            final same = switch [ops[i], history[start + i]] {
                case [Insert(a), Insert(b)]: a == b && a.tabIndexValue == b.tabIndexValue && a.isTabStop == b.isTabStop;
                case [Group(a), Group(b)]: a == b;
                case [GroupEnd, GroupEnd]: true;
                case _: false;
            }
            if (!same) {
                return false;
            }
        }
        return true;
    }

    inline function prepareSplice(plan:FrameSplice, base:Int, oldStart:Int, oldEnd:Int, oldStartTime:Float, oldEndTime:Float,
            newStart:Int, newEnd:Int, newStartTime:Float, newEndTime:Float, length:Int):Void {
        plan.reset(base);
        plan.addRange(oldStart, oldEnd, oldStartTime, oldEndTime, newStart, newEnd, newStartTime, newEndTime);
        plan.prepare(length);
    }

    /**
     * Ends an in place rendering: the context set up for the view and the
     * amend modes.
     */
    function endInPlace(spare:Frame, imageCache:Null<AnyImageCache>, done:Bool = false):Void {
        amendLayoutElements.resize(0);
        Stacks.drop(remSizeOverrideStack);
        if (imageCache != null) {
            imageCacheStack.pop();
        }
        elementIdNode = elementIdRoot;
        renderedFrame.reusedElementStates.resize(0);
        // Drawn in place: its old nodes go now (a full frame frees them otherwise)
        layoutEngine.endAmend(done);
        windowTextSystem.endAmend();
        nextFrame = spare;
        renderedFrame.dispatchTree.amending = false;
        amending = false;
    }

    /**
     * The view rendering in place laid out differently: its render is given
     * to a full frame (`takePreRenderedView`), with the element states it
     * accessed (moved to the frame drawn next, which starts with them). Only
     * the render and the layout happened.
     */
    function handOffInPlace(viewId:Int, element:ViewElement, baseAccessed:Int, spare:Frame, imageCache:Null<AnyImageCache>):Void {
        final preRendered = element.preRendered();
        preRendered.viewId = viewId;
        if (amendLayoutElements.length > 0) {
            preRendered.nested = amendLayoutElements.copy();
            amendLayoutElements.resize(0);
        }
        preRenderedView = preRendered;
        final frame = renderedFrame;
        final accessed = frame.accessedElementStates;
        final target = spare.accessedElementStates;
        // At the same positions: the views it rendered recorded them (an
        // unused prefix in the full frame)
        for (_ in 0...baseAccessed) {
            target.push(unusedStateBox);
        }
        for (i in baseAccessed...accessed.length) {
            final box = accessed[i];
            if (box.owner == frame) {
                box.owner = spare;
                spare.elementStates.push(box);
            }
            target.push(box);
        }
        accessed.resize(baseAccessed);
        // The layouts it used stay cached: the full frame records them again
        windowTextSystem.truncateAmendedLayouts(amendLineBase);
        endInPlace(spare, imageCache);
    }

    /**
     * An in place rendering threw: its appended entries are dropped and the
     * next frame is drawn whole.
     */
    function abortInPlace(spare:Frame, imageCache:Null<AnyImageCache>, baseHitboxes:Int, baseTooltips:Int, baseDeferred:Int, baseNodes:Int,
            baseAccessed:Int, baseMouse:Int, baseInput:Int, baseRegions:Int, baseCursors:Int):Void {
        final frame = renderedFrame;
        if (frame.hitboxes.length > baseHitboxes) frame.hitboxes.resize(baseHitboxes);
        if (frame.tooltipRequests.length > baseTooltips) frame.tooltipRequests.resize(baseTooltips);
        if (frame.deferredDraws.length > baseDeferred) frame.deferredDraws.resize(baseDeferred);
        frame.dispatchTree.truncate(baseNodes);
        frame.dispatchTree.resetStacks();
        if (frame.accessedElementStates.length > baseAccessed) frame.accessedElementStates.resize(baseAccessed);
        if (frame.mouseListeners.length > baseMouse) frame.mouseListeners.resize(baseMouse);
        if (frame.inputHandlers.length > baseInput) frame.inputHandlers.resize(baseInput);
        if (frame.textInputRegions.length > baseRegions) frame.textInputRegions.resize(baseRegions);
        if (frame.cursorStyles.length > baseCursors) frame.cursorStyles.resize(baseCursors);
        windowTextSystem.truncateAmendedLayouts(amendLineBase);
        textStyleStack.resize(0);
        contentMaskStack.resize(0);
        elementOffsetStack.resize(0);
        renderedEntityStack.resize(0);
        endInPlace(spare, imageCache);
        remSizeOverrideStack.resize(0);
        imageCacheStack.resize(0);
        refreshing = true;
        dirty = true;
    }

    /**
     * Hit test of the frame as it will be once the hitboxes of the view
     * rendering in place replace its old ones (`plan`), without moving them
     * yet (the views reusing their ranges while it paints read the old ones).
     */
    function hitTestInPlace(position:Point, hitboxes:Array<Hitbox>, plan:FrameSplice, frameEnd:Int):HitTest {
        final hitTest = new HitTest();
        hitTestHoverSet = false;
        final oldStart = plan.oldStart(0);
        final oldEnd = plan.oldEnd(0);
        final blockStart = plan.blockStart(0);
        final blockEnd = plan.blockEnd(0);
        final base = plan.base;
        // Reverse order of the spliced array: the entries appended after
        // the view's, the frame after the view, the view, the frame before
        var stopped = false;
        var i = plan.length - 1;
        while (!stopped && i >= blockEnd) {
            stopped = hitTestHitbox(hitboxes[i], position, hitTest);
            i--;
        }
        i = blockStart - 1;
        while (!stopped && i >= base) {
            stopped = hitTestHitbox(hitboxes[i], position, hitTest);
            i--;
        }
        // (`frameEnd`: without the deferred draws of the last frame when
        // those of this frame, appended, replace them)
        i = frameEnd - 1;
        while (!stopped && i >= oldEnd) {
            stopped = hitTestHitbox(hitboxes[i], position, hitTest);
            i--;
        }
        i = blockEnd - 1;
        while (!stopped && i >= blockStart) {
            stopped = hitTestHitbox(hitboxes[i], position, hitTest);
            i--;
        }
        i = oldStart - 1;
        while (!stopped && i >= 0) {
            stopped = hitTestHitbox(hitboxes[i], position, hitTest);
            i--;
        }
        if (!hitTestHoverSet) {
            hitTest.hoverHitboxCount = hitTest.ids.length;
        }
        return hitTest;
    }

    var hitTestHoverSet:Bool = false;

    /** One step of `Frame.hitTest`: returns true when the hitbox blocks the ones below */
    inline function hitTestHitbox(hitbox:Hitbox, position:Point, hitTest:HitTest):Bool {
        var blocks = false;
        if (hitbox.bounds.intersectContains(hitbox.contentMask.bounds, position)) {
            hitTest.ids.push(hitbox.id);
            if (!hitTestHoverSet && hitbox.behavior == BlockMouseExceptScroll) {
                hitTest.hoverHitboxCount = hitTest.ids.length;
                hitTestHoverSet = true;
            }
            blocks = hitbox.behavior == BlockMouse;
        }
        return blocks;
    }

    /**
     * Puts the entries of the view rendered in place where its old ones
     * were, in each array of the frame, then moves the indices the views
     * recorded (see `FrameSplice`).
     */
    function spliceInPlace(state:ViewElement.ViewElementState, baseDeferred:Int, baseNodes:Int, baseAccessed:Int, baseMouse:Int, baseInput:Int,
            baseRegions:Int, baseCursors:Int, oldLayoutAccessedStart:Int, oldLayoutAccessedEnd:Int, oldLayoutAccessedStartTime:Float,
            oldLayoutAccessedEndTime:Float, oldSceneLength:Int, viewOps:Int, newSceneLength:Int, oldTabsLength:Int, viewTabOps:Int, newTabsLength:Int,
            oldViewsStart:Int):Void {
        final frame = renderedFrame;
        final tree = frame.dispatchTree;
        final oldPrepaintStart = amendOldPrepaintStart;
        final oldPrepaintEnd = amendOldPrepaintEnd;
        final oldPaintStart = amendOldPaintStart;
        final oldPaintEnd = amendOldPaintEnd;
        final newPrepaintStart = state.prepaintStart;
        final newPrepaintEnd = state.prepaintEnd;
        final newPaintStart = state.paintStart;
        final newPaintEnd = state.paintEnd;
        final ps = oldPrepaintStart.time;
        final pe = oldPrepaintEnd.time;
        final qs = oldPaintStart.time;
        final qe = oldPaintEnd.time;
        final nps = newPrepaintStart.time;
        final npe = newPrepaintEnd.time;
        final nqs = newPaintStart.time;
        final nqe = newPaintEnd.time;

        // With the last view: what the deferred draws of the last frame
        // recorded (after the tree, see `Frame.deferredPrepaintStart`) is
        // replaced by what was drawn after the tree in this rendering
        final last = amendLast;
        final tps = frame.deferredPrepaintStart;
        final tpe = frame.deferredPrepaintEnd;
        final tqs = frame.deferredPaintStart;
        final tqe = frame.deferredPaintEnd;
        final ntps = amendTailPrepaintStart;
        final ntpe = amendTailPrepaintEnd;
        final ntqs = amendTailPaintStart;
        final ntqe = amendTailPaintEnd;
        final tailHitboxesStart = tps.hitboxesIndex;
        final tailHitboxesEnd = spliceHitboxes.base;

        // Hitboxes (the plan was made for the hit test); the window control
        // areas of the old ones go
        final controls = frame.windowControlHitboxes;
        if (controls.length > 0) {
            var kept = 0;
            for (i in 0...controls.length) {
                final control = controls[i];
                var old = false;
                for (j in oldPrepaintStart.hitboxesIndex...oldPrepaintEnd.hitboxesIndex) {
                    if (frame.hitboxes[j] == control.hitbox) {
                        old = true;
                        break;
                    }
                }
                if (last && !old) {
                    for (j in tailHitboxesStart...tailHitboxesEnd) {
                        if (frame.hitboxes[j] == control.hitbox) {
                            old = true;
                            break;
                        }
                    }
                }
                if (!old) {
                    controls[kept++] = control;
                }
            }
            controls.resize(kept);
        }
        FrameSplice.apply(frame.hitboxes, spliceHitboxes, hitboxScratch);

        // Deferred draws: the view's in place of its old ones (those
        // deferred after the tree, nested, stay after them)
        prepareSplice(spliceDeferred, baseDeferred, oldPrepaintStart.deferredDrawsIndex, oldPrepaintEnd.deferredDrawsIndex, ps, pe,
            newPrepaintStart.deferredDrawsIndex, newPrepaintEnd.deferredDrawsIndex, nps, npe, frame.deferredDraws.length);
        FrameSplice.apply(frame.deferredDraws, spliceDeferred, deferredScratch);

        // Dispatch nodes (parents, focus and view ids follow)
        spliceNodes.reset(baseNodes);
        spliceNodes.addRange(oldPrepaintStart.dispatchTreeIndex, oldPrepaintEnd.dispatchTreeIndex, ps, pe,
            newPrepaintStart.dispatchTreeIndex, newPrepaintEnd.dispatchTreeIndex, nps, npe);
        if (last) {
            spliceNodes.addRange(tps.dispatchTreeIndex, baseNodes, tps.time, tpe.time, ntps.dispatchTreeIndex, ntpe.dispatchTreeIndex, ntps.time, ntpe.time);
        }
        spliceNodes.prepare(tree.len());
        tree.applySplice(spliceNodes);
        for (draw in frame.deferredDraws) {
            draw.parentNode = spliceNodes.remapEntry(draw.parentNode);
        }

        // Paint state
        spliceMouse.reset(baseMouse);
        spliceMouse.addRange(oldPaintStart.mouseListenersIndex, oldPaintEnd.mouseListenersIndex, qs, qe,
            newPaintStart.mouseListenersIndex, newPaintEnd.mouseListenersIndex, nqs, nqe);
        if (last) {
            spliceMouse.addRange(tqs.mouseListenersIndex, baseMouse, tqs.time, tqe.time, ntqs.mouseListenersIndex, ntqe.mouseListenersIndex, ntqs.time, ntqe.time);
        }
        spliceMouse.prepare(frame.mouseListeners.length);
        FrameSplice.apply(frame.mouseListeners, spliceMouse, mouseScratch);
        spliceInput.reset(baseInput);
        spliceInput.addRange(oldPaintStart.inputHandlersIndex, oldPaintEnd.inputHandlersIndex, qs, qe,
            newPaintStart.inputHandlersIndex, newPaintEnd.inputHandlersIndex, nqs, nqe);
        if (last) {
            spliceInput.addRange(tqs.inputHandlersIndex, baseInput, tqs.time, tqe.time, ntqs.inputHandlersIndex, ntqe.inputHandlersIndex, ntqs.time, ntqe.time);
        }
        spliceInput.prepare(frame.inputHandlers.length);
        FrameSplice.apply(frame.inputHandlers, spliceInput, inputScratch);
        spliceRegions.reset(baseRegions);
        spliceRegions.addRange(oldPaintStart.textInputRegionsIndex, oldPaintEnd.textInputRegionsIndex, qs, qe,
            newPaintStart.textInputRegionsIndex, newPaintEnd.textInputRegionsIndex, nqs, nqe);
        if (last) {
            spliceRegions.addRange(tqs.textInputRegionsIndex, baseRegions, tqs.time, tqe.time, ntqs.textInputRegionsIndex, ntqe.textInputRegionsIndex, ntqs.time, ntqe.time);
        }
        spliceRegions.prepare(frame.textInputRegions.length);
        FrameSplice.apply(frame.textInputRegions, spliceRegions, regionScratch);
        spliceCursors.reset(baseCursors);
        spliceCursors.addRange(oldPaintStart.cursorStylesIndex, oldPaintEnd.cursorStylesIndex, qs, qe,
            newPaintStart.cursorStylesIndex, newPaintEnd.cursorStylesIndex, nqs, nqe);
        if (last) {
            spliceCursors.addRange(tqs.cursorStylesIndex, baseCursors, tqs.time, tqe.time, ntqs.cursorStylesIndex, ntqe.cursorStylesIndex, ntqs.time, ntqe.time);
        }
        spliceCursors.prepare(frame.cursorStyles.length);
        FrameSplice.apply(frame.cursorStyles, spliceCursors, cursorScratch);

        // Element states: its three ranges (render and layout, prepaint,
        // paint); the states it accessed before and nobody accesses now go
        final accessed = frame.accessedElementStates;
        final plan = spliceAccessed;
        plan.reset(baseAccessed);
        plan.addRange(oldLayoutAccessedStart, oldLayoutAccessedEnd, oldLayoutAccessedStartTime, oldLayoutAccessedEndTime,
            state.layoutAccessedStart, state.layoutAccessedEnd, state.layoutAccessedStartTime, state.layoutAccessedEndTime);
        plan.addRange(oldPrepaintStart.accessedElementStatesIndex, oldPrepaintEnd.accessedElementStatesIndex, ps, pe,
            newPrepaintStart.accessedElementStatesIndex, newPrepaintEnd.accessedElementStatesIndex, nps, npe);
        if (last) {
            // After the prepaint of the tree, before its paint
            plan.addRange(tps.accessedElementStatesIndex, tpe.accessedElementStatesIndex, tps.time, tpe.time,
                ntps.accessedElementStatesIndex, ntpe.accessedElementStatesIndex, ntps.time, ntpe.time);
        }
        plan.addRange(oldPaintStart.accessedElementStatesIndex, oldPaintEnd.accessedElementStatesIndex, qs, qe,
            newPaintStart.accessedElementStatesIndex, newPaintEnd.accessedElementStatesIndex, nqs, nqe);
        if (last) {
            plan.addRange(tqs.accessedElementStatesIndex, tqe.accessedElementStatesIndex, tqs.time, tqe.time,
                ntqs.accessedElementStatesIndex, ntqe.accessedElementStatesIndex, ntqs.time, ntqe.time);
        }
        plan.prepare(accessed.length);
        final mark = ++stateMark;
        for (i in baseAccessed...accessed.length) {
            accessed[i].inPlaceMark = mark;
        }
        final candidates = droppedStateCandidates;
        candidates.resize(0);
        for (k in 0...plan.count) {
            for (i in plan.oldStart(k)...plan.oldEnd(k)) {
                final box = accessed[i];
                if (box.inPlaceMark != mark && box.inPlaceMark != -mark) {
                    box.inPlaceMark = -mark;
                    candidates.push(box);
                }
            }
        }
        if (candidates.length > 0) {
            // Accessed elsewhere in the frame: kept
            var k = 0;
            var i = 0;
            while (i < baseAccessed) {
                if (k < plan.count && i == plan.oldStart(k)) {
                    i = plan.oldEnd(k);
                    k++;
                    continue;
                }
                final box = accessed[i];
                if (box.inPlaceMark == -mark) {
                    box.inPlaceMark = mark;
                }
                i++;
            }
        }
        FrameSplice.apply(accessed, plan, accessedScratch);
        for (box in candidates) {
            if (box.inPlaceMark == -mark && box.owner == frame) {
                Frame.dropState(box);
                inPlaceDroppedStates = true;
            }
        }
        candidates.resize(0);

        // Line layouts: its prepaint and paint ranges
        windowTextSystem.layoutIndexInto(amendLineEnd);
        final base = amendLineBase;
        final end = amendLineEnd;
        final ops = oldPrepaintStart.lineLayoutIndex;
        final ope = oldPrepaintEnd.lineLayoutIndex;
        final oqs = oldPaintStart.lineLayoutIndex;
        final oqe = oldPaintEnd.lineLayoutIndex;
        final nlps = newPrepaintStart.lineLayoutIndex;
        final nlpe = newPrepaintEnd.lineLayoutIndex;
        final nlqs = newPaintStart.lineLayoutIndex;
        final nlqe = newPaintEnd.lineLayoutIndex;
        spliceLines.reset(base.linesIndex, false, true);
        spliceLines.addRange(ops.linesIndex, ope.linesIndex, ps, pe, nlps.linesIndex, nlpe.linesIndex, nps, npe);
        if (last) spliceLines.addRange(tps.lineLayoutIndex.linesIndex, tpe.lineLayoutIndex.linesIndex, tps.time, tpe.time, ntps.lineLayoutIndex.linesIndex, ntpe.lineLayoutIndex.linesIndex, ntps.time, ntpe.time);
        spliceLines.addRange(oqs.linesIndex, oqe.linesIndex, qs, qe, nlqs.linesIndex, nlqe.linesIndex, nqs, nqe);
        if (last) spliceLines.addRange(tqs.lineLayoutIndex.linesIndex, tqe.lineLayoutIndex.linesIndex, tqs.time, tqe.time, ntqs.lineLayoutIndex.linesIndex, ntqe.lineLayoutIndex.linesIndex, ntqs.time, ntqe.time);
        spliceLines.prepare(end.linesIndex);
        spliceWrappedLines.reset(base.wrappedLinesIndex, false, true);
        spliceWrappedLines.addRange(ops.wrappedLinesIndex, ope.wrappedLinesIndex, ps, pe, nlps.wrappedLinesIndex, nlpe.wrappedLinesIndex, nps, npe);
        if (last) spliceWrappedLines.addRange(tps.lineLayoutIndex.wrappedLinesIndex, tpe.lineLayoutIndex.wrappedLinesIndex, tps.time, tpe.time, ntps.lineLayoutIndex.wrappedLinesIndex, ntpe.lineLayoutIndex.wrappedLinesIndex, ntps.time, ntpe.time);
        spliceWrappedLines.addRange(oqs.wrappedLinesIndex, oqe.wrappedLinesIndex, qs, qe, nlqs.wrappedLinesIndex, nlqe.wrappedLinesIndex, nqs, nqe);
        if (last) spliceWrappedLines.addRange(tqs.lineLayoutIndex.wrappedLinesIndex, tqe.lineLayoutIndex.wrappedLinesIndex, tqs.time, tqe.time, ntqs.lineLayoutIndex.wrappedLinesIndex, ntqe.lineLayoutIndex.wrappedLinesIndex, ntqs.time, ntqe.time);
        spliceWrappedLines.prepare(end.wrappedLinesIndex);
        spliceLinesByHash.reset(base.linesByHashIndex, false, true);
        spliceLinesByHash.addRange(ops.linesByHashIndex, ope.linesByHashIndex, ps, pe, nlps.linesByHashIndex, nlpe.linesByHashIndex, nps, npe);
        if (last) spliceLinesByHash.addRange(tps.lineLayoutIndex.linesByHashIndex, tpe.lineLayoutIndex.linesByHashIndex, tps.time, tpe.time, ntps.lineLayoutIndex.linesByHashIndex, ntpe.lineLayoutIndex.linesByHashIndex, ntps.time, ntpe.time);
        spliceLinesByHash.addRange(oqs.linesByHashIndex, oqe.linesByHashIndex, qs, qe, nlqs.linesByHashIndex, nlqe.linesByHashIndex, nqs, nqe);
        if (last) spliceLinesByHash.addRange(tqs.lineLayoutIndex.linesByHashIndex, tqe.lineLayoutIndex.linesByHashIndex, tqs.time, tqe.time, ntqs.lineLayoutIndex.linesByHashIndex, ntqe.lineLayoutIndex.linesByHashIndex, ntqs.time, ntqe.time);
        spliceLinesByHash.prepare(end.linesByHashIndex);
        spliceWrappedLinesByHash.reset(base.wrappedLinesByHashIndex, false, true);
        spliceWrappedLinesByHash.addRange(ops.wrappedLinesByHashIndex, ope.wrappedLinesByHashIndex, ps, pe, nlps.wrappedLinesByHashIndex, nlpe.wrappedLinesByHashIndex, nps, npe);
        if (last) spliceWrappedLinesByHash.addRange(tps.lineLayoutIndex.wrappedLinesByHashIndex, tpe.lineLayoutIndex.wrappedLinesByHashIndex, tps.time, tpe.time, ntps.lineLayoutIndex.wrappedLinesByHashIndex, ntpe.lineLayoutIndex.wrappedLinesByHashIndex, ntps.time, ntpe.time);
        spliceWrappedLinesByHash.addRange(oqs.wrappedLinesByHashIndex, oqe.wrappedLinesByHashIndex, qs, qe, nlqs.wrappedLinesByHashIndex, nlqe.wrappedLinesByHashIndex, nqs, nqe);
        if (last) spliceWrappedLinesByHash.addRange(tqs.lineLayoutIndex.wrappedLinesByHashIndex, tqe.lineLayoutIndex.wrappedLinesByHashIndex, tqs.time, tqe.time, ntqs.lineLayoutIndex.wrappedLinesByHashIndex, ntqe.lineLayoutIndex.wrappedLinesByHashIndex, ntqs.time, ntqe.time);
        spliceWrappedLinesByHash.prepare(end.wrappedLinesByHashIndex);
        windowTextSystem.spliceUsedLayouts(spliceLines, spliceWrappedLines, spliceLinesByHash, spliceWrappedLinesByHash);

        // Scene and tab order, made again: plans for the indices only (the
        // view's were recorded in its own scene and tab order, from 0)
        spliceScene.reset(oldSceneLength, true);
        spliceScene.addRange(oldPaintStart.sceneIndex, oldPaintEnd.sceneIndex, qs, qe, newPaintStart.sceneIndex, newPaintEnd.sceneIndex, nqs, nqe);
        if (last) {
            // Painted in place, after the tree
            spliceScene.addRange(tqs.sceneIndex, oldSceneLength, tqs.time, tqe.time, ntqs.sceneIndex, ntqe.sceneIndex, ntqs.time, ntqe.time);
        }
        spliceScene.prepare(newSceneLength);
        spliceTabs.reset(oldTabsLength, true);
        spliceTabs.addRange(oldPaintStart.tabHandleIndex, oldPaintEnd.tabHandleIndex, qs, qe, newPaintStart.tabHandleIndex, newPaintEnd.tabHandleIndex, nqs, nqe);
        if (last) {
            spliceTabs.addRange(tqs.tabHandleIndex, oldTabsLength, tqs.time, tqe.time, ntqs.tabHandleIndex, ntqe.tabHandleIndex, ntqs.time, ntqe.time);
        }
        spliceTabs.prepare(newTabsLength);

        remapViewStates(state, oldLayoutAccessedStartTime, oldLayoutAccessedEndTime, oldViewsStart);

        // Where the deferred draws are in the frame now
        remapOldPrepaintIndex(tps);
        remapOldPrepaintIndex(tpe);
        remapOldPaintIndex(tqs);
        remapOldPaintIndex(tqe);
        if (last) {
            // Spliced before they were drawn, and appended after the tree
            tpe.tooltipsIndex = frame.tooltipRequests.length;
            tpe.deferredDrawsIndex = frame.deferredDraws.length;
        }
    }

    /**
     * Moves the indices recorded by the views after the splices of an in
     * place rendering: the views of the frame (only when an array of the
     * frame changed length; those drawn inside the view's old ranges and
     * not again are invalidated), the views recorded by the rendering (their
     * capture times move into the view's old ones, so that the order of
     * times stays the order of positions), and the deferred draws.
     */
    function remapViewStates(state:ViewElement.ViewElementState, oldLayoutStartTime:Float, oldLayoutEndTime:Float, oldViewsStart:Int):Void {
        final frame = renderedFrame;
        final serial = amendSerial;
        final layoutWindowStart = oldLayoutStartTime;
        final layoutWindowEnd = oldLayoutEndTime;
        final prepaintWindowStart = amendOldPrepaintStart.time;
        final prepaintWindowEnd = amendOldPrepaintEnd.time;
        final paintWindowStart = amendOldPaintStart.time;
        final paintWindowEnd = amendOldPaintEnd.time;
        final changed = !(spliceHitboxes.framePartUnchanged() && spliceTooltips.framePartUnchanged() && spliceDeferred.framePartUnchanged()
            && spliceNodes.framePartUnchanged() && spliceAccessed.framePartUnchanged() && spliceMouse.framePartUnchanged()
            && spliceInput.framePartUnchanged() && spliceRegions.framePartUnchanged() && spliceCursors.framePartUnchanged()
            && spliceScene.framePartUnchanged() && spliceTabs.framePartUnchanged() && spliceLines.framePartUnchanged()
            && spliceWrappedLines.framePartUnchanged() && spliceLinesByHash.framePartUnchanged() && spliceWrappedLinesByHash.framePartUnchanged());
        // With the last view: the deferred draws of the last frame are
        // replaced too (see `spliceInPlace`)
        final last = amendLast;
        final tailPrepaintWindowStart = frame.deferredPrepaintStart.time;
        final tailPrepaintWindowEnd = frame.deferredPrepaintEnd.time;
        final tailPaintWindowStart = frame.deferredPaintStart.time;
        final tailPaintWindowEnd = frame.deferredPaintEnd.time;
        inline function inside(time:Float, start:Float, end:Float):Bool {
            return time > start && time < end;
        }
        inline function stale(other:ViewElement.ViewElementState):Bool {
            return inside(other.prepaintStart.time, prepaintWindowStart, prepaintWindowEnd)
                || inside(other.paintStart.time, paintWindowStart, paintWindowEnd)
                || (last && (inside(other.prepaintStart.time, tailPrepaintWindowStart, tailPrepaintWindowEnd)
                    || inside(other.paintStart.time, tailPaintWindowStart, tailPaintWindowEnd)));
        }
        // Laid out inside the view and drawn outside of it, by a deferred
        // draw of the last frame that the last view draws again: its
        // prepaint and paint ranges still index the frame until then (a
        // view retained by the layout of this rendering reuses them when
        // its deferred draw is prepainted), it is not reusable beyond
        inline function laidOutInside(other:ViewElement.ViewElementState):Bool {
            return inside(other.layoutAccessedStartTime, layoutWindowStart, layoutWindowEnd);
        }
        inline function drawnDeferred(other:ViewElement.ViewElementState):Bool {
            return !last && inside(other.prepaintStart.time, tailPrepaintWindowStart, tailPrepaintWindowEnd)
                && inside(other.paintStart.time, tailPaintWindowStart, tailPaintWindowEnd);
        }
        if (changed) {
            for (other in frame.viewStates) {
                if (other.amendSerial == serial || other.prepaintFrame == -1) {
                    continue;
                }
                if (stale(other) || (laidOutInside(other) && !drawnDeferred(other))) {
                    invalidateViewState(other);
                }
                else if (laidOutInside(other)) {
                    other.layoutFrame = -1;
                    remapOldPrepaintIndex(other.prepaintStart);
                    remapOldPrepaintIndex(other.prepaintEnd);
                    remapOldPaintIndex(other.paintStart);
                    remapOldPaintIndex(other.paintEnd);
                    if (!spliceNodes.framePartUnchanged() && other.dispatchNode != -1) {
                        other.dispatchNode = spliceNodes.remapEntry(other.dispatchNode);
                    }
                }
                else {
                    remapOldViewState(other);
                }
            }
        }
        else {
            // Only the views drawn inside the view, or by the deferred
            // draws, can be stale
            for (i in oldViewsStart...inPlaceOldViews.length) {
                final tracker = trackers.get(inPlaceOldViews[i]);
                final other = tracker != null ? tracker.state : null;
                if (other != null && other.amendSerial != serial && other.registeredSerial == frame.serial && other.prepaintFrame != -1) {
                    if (stale(other) || (laidOutInside(other) && !drawnDeferred(other))) {
                        invalidateViewState(other);
                    }
                    else if (laidOutInside(other)) {
                        other.layoutFrame = -1;
                    }
                }
            }
        }

        // The views recorded by the rendering: their positions, then their times
        final layoutStart = state.layoutAccessedStartTime;
        final layoutEnd = state.layoutAccessedEndTime;
        final prepaintStart = state.prepaintStart.time;
        final prepaintEnd = state.prepaintEnd.time;
        final paintStart = state.paintStart.time;
        final paintEnd = state.paintEnd.time;
        final tailPrepaintStart = amendTailPrepaintStart.time;
        final tailPrepaintEnd = amendTailPrepaintEnd.time;
        final tailPaintStart = amendTailPaintStart.time;
        final tailPaintEnd = amendTailPaintEnd.time;
        inline function mapTime(time:Float):Float {
            return if (time >= layoutStart && time <= layoutEnd) {
                layoutWindowStart + (layoutWindowEnd - layoutWindowStart) * (time - layoutStart) / (layoutEnd - layoutStart);
            }
            else if (time >= prepaintStart && time <= prepaintEnd) {
                prepaintWindowStart + (prepaintWindowEnd - prepaintWindowStart) * (time - prepaintStart) / (prepaintEnd - prepaintStart);
            }
            else if (time >= paintStart && time <= paintEnd) {
                paintWindowStart + (paintWindowEnd - paintWindowStart) * (time - paintStart) / (paintEnd - paintStart);
            }
            else if (last && time >= tailPrepaintStart && time <= tailPrepaintEnd) {
                // Drawn after the tree (deferred draws, tooltip): where the
                // deferred draws were in the frame
                tailPrepaintWindowStart + (tailPrepaintWindowEnd - tailPrepaintWindowStart) * (time - tailPrepaintStart) / (tailPrepaintEnd - tailPrepaintStart);
            }
            else if (last && time >= tailPaintStart && time <= tailPaintEnd) {
                tailPaintWindowStart + (tailPaintWindowEnd - tailPaintWindowStart) * (time - tailPaintStart) / (tailPaintEnd - tailPaintStart);
            }
            else {
                time;
            }
        }
        final startTime = amendStartTime;
        for (other in amendStates) {
            if (other.prepaintStart.time <= startTime || other.paintStart.time <= startTime || other.layoutAccessedStartTime <= startTime) {
                // Not drawn whole by this rendering (no paint...): not reusable
                invalidateViewState(other);
                continue;
            }
            remapNewPrepaintIndex(other.prepaintStart);
            remapNewPrepaintIndex(other.prepaintEnd);
            remapNewPaintIndex(other.paintStart);
            remapNewPaintIndex(other.paintEnd);
            final layoutTime = other.layoutAccessedStartTime;
            final layoutEndTime = other.layoutAccessedEndTime;
            other.layoutAccessedStart = spliceAccessed.remapNew(other.layoutAccessedStart, layoutTime);
            other.layoutAccessedEnd = spliceAccessed.remapNew(other.layoutAccessedEnd, layoutEndTime);
            other.dispatchNode = spliceNodes.remapEntry(other.dispatchNode);
            other.prepaintStart.time = mapTime(other.prepaintStart.time);
            other.prepaintEnd.time = mapTime(other.prepaintEnd.time);
            other.paintStart.time = mapTime(other.paintStart.time);
            other.paintEnd.time = mapTime(other.paintEnd.time);
            other.layoutAccessedStartTime = mapTime(layoutTime);
            other.layoutAccessedEndTime = mapTime(layoutEndTime);
        }
        for (draw in frame.deferredDraws) {
            if (draw.amendSerial == serial) {
                // Drawn by this rendering (with the last view)
                remapNewPrepaintIndex(draw.prepaintStart);
                remapNewPrepaintIndex(draw.prepaintEnd);
                remapNewPaintIndex(draw.paintStart);
                remapNewPaintIndex(draw.paintEnd);
                draw.prepaintStart.time = mapTime(draw.prepaintStart.time);
                draw.prepaintEnd.time = mapTime(draw.prepaintEnd.time);
                draw.paintStart.time = mapTime(draw.paintStart.time);
                draw.paintEnd.time = mapTime(draw.paintEnd.time);
            }
            else if (draw.element == null) {
                // Drawn in the last frame (reused with a view, drawn again
                // with the last view): its ranges index the frame
                remapOldPrepaintIndex(draw.prepaintStart);
                remapOldPrepaintIndex(draw.prepaintEnd);
                remapOldPaintIndex(draw.paintStart);
                remapOldPaintIndex(draw.paintEnd);
            }
        }
        amendStates.resize(0);
    }

    /** A view state whose ranges are gone: never reused again */
    inline function invalidateViewState(state:ViewElement.ViewElementState):Void {
        state.prepaintFrame = -1;
        state.paintFrame = -1;
        state.layoutFrame = -1;
    }

    function remapOldViewState(state:ViewElement.ViewElementState):Void {
        remapOldPrepaintIndex(state.prepaintStart);
        remapOldPrepaintIndex(state.prepaintEnd);
        remapOldPaintIndex(state.paintStart);
        remapOldPaintIndex(state.paintEnd);
        if (!spliceAccessed.framePartUnchanged()) {
            state.layoutAccessedStart = spliceAccessed.remapOld(state.layoutAccessedStart, state.layoutAccessedStartTime);
            state.layoutAccessedEnd = spliceAccessed.remapOld(state.layoutAccessedEnd, state.layoutAccessedEndTime);
        }
        if (!spliceNodes.framePartUnchanged() && state.dispatchNode != -1) {
            state.dispatchNode = spliceNodes.remapEntry(state.dispatchNode);
        }
    }

    function remapOldPrepaintIndex(index:PrepaintStateIndex):Void {
        final time = index.time;
        if (!spliceHitboxes.framePartUnchanged()) index.hitboxesIndex = spliceHitboxes.remapOld(index.hitboxesIndex, time);
        if (!spliceTooltips.framePartUnchanged()) index.tooltipsIndex = spliceTooltips.remapOld(index.tooltipsIndex, time);
        if (!spliceDeferred.framePartUnchanged()) index.deferredDrawsIndex = spliceDeferred.remapOld(index.deferredDrawsIndex, time);
        if (!spliceNodes.framePartUnchanged()) index.dispatchTreeIndex = spliceNodes.remapOld(index.dispatchTreeIndex, time);
        if (!spliceAccessed.framePartUnchanged()) index.accessedElementStatesIndex = spliceAccessed.remapOld(index.accessedElementStatesIndex, time);
        remapOldLineLayoutIndex(index.lineLayoutIndex, time);
    }

    function remapOldPaintIndex(index:PaintIndex):Void {
        final time = index.time;
        if (!spliceScene.framePartUnchanged()) index.sceneIndex = spliceScene.remapOld(index.sceneIndex, time);
        if (!spliceMouse.framePartUnchanged()) index.mouseListenersIndex = spliceMouse.remapOld(index.mouseListenersIndex, time);
        if (!spliceInput.framePartUnchanged()) index.inputHandlersIndex = spliceInput.remapOld(index.inputHandlersIndex, time);
        if (!spliceRegions.framePartUnchanged()) index.textInputRegionsIndex = spliceRegions.remapOld(index.textInputRegionsIndex, time);
        if (!spliceCursors.framePartUnchanged()) index.cursorStylesIndex = spliceCursors.remapOld(index.cursorStylesIndex, time);
        if (!spliceAccessed.framePartUnchanged()) index.accessedElementStatesIndex = spliceAccessed.remapOld(index.accessedElementStatesIndex, time);
        if (!spliceTabs.framePartUnchanged()) index.tabHandleIndex = spliceTabs.remapOld(index.tabHandleIndex, time);
        remapOldLineLayoutIndex(index.lineLayoutIndex, time);
    }

    inline function remapOldLineLayoutIndex(index:LineLayoutIndex, time:Float):Void {
        if (!spliceLines.framePartUnchanged()) index.linesIndex = spliceLines.remapOld(index.linesIndex, time);
        if (!spliceWrappedLines.framePartUnchanged()) index.wrappedLinesIndex = spliceWrappedLines.remapOld(index.wrappedLinesIndex, time);
        if (!spliceLinesByHash.framePartUnchanged()) index.linesByHashIndex = spliceLinesByHash.remapOld(index.linesByHashIndex, time);
        if (!spliceWrappedLinesByHash.framePartUnchanged()) index.wrappedLinesByHashIndex = spliceWrappedLinesByHash.remapOld(index.wrappedLinesByHashIndex, time);
    }

    function remapNewPrepaintIndex(index:PrepaintStateIndex):Void {
        final time = index.time;
        index.hitboxesIndex = spliceHitboxes.remapNew(index.hitboxesIndex, time);
        // (spliced before what is drawn after the tree: final from then on)
        if (time <= amendTooltipsTime) {
            index.tooltipsIndex = spliceTooltips.remapNew(index.tooltipsIndex, time);
        }
        index.deferredDrawsIndex = spliceDeferred.remapNew(index.deferredDrawsIndex, time);
        index.dispatchTreeIndex = spliceNodes.remapNew(index.dispatchTreeIndex, time);
        index.accessedElementStatesIndex = spliceAccessed.remapNew(index.accessedElementStatesIndex, time);
        remapNewLineLayoutIndex(index.lineLayoutIndex, time);
    }

    function remapNewPaintIndex(index:PaintIndex):Void {
        final time = index.time;
        index.sceneIndex = spliceScene.remapNew(index.sceneIndex, time);
        index.mouseListenersIndex = spliceMouse.remapNew(index.mouseListenersIndex, time);
        index.inputHandlersIndex = spliceInput.remapNew(index.inputHandlersIndex, time);
        index.textInputRegionsIndex = spliceRegions.remapNew(index.textInputRegionsIndex, time);
        index.cursorStylesIndex = spliceCursors.remapNew(index.cursorStylesIndex, time);
        index.accessedElementStatesIndex = spliceAccessed.remapNew(index.accessedElementStatesIndex, time);
        index.tabHandleIndex = spliceTabs.remapNew(index.tabHandleIndex, time);
        remapNewLineLayoutIndex(index.lineLayoutIndex, time);
    }

    inline function remapNewLineLayoutIndex(index:LineLayoutIndex, time:Float):Void {
        index.linesIndex = spliceLines.remapNew(index.linesIndex, time);
        index.wrappedLinesIndex = spliceWrappedLines.remapNew(index.wrappedLinesIndex, time);
        index.linesByHashIndex = spliceLinesByHash.remapNew(index.linesByHashIndex, time);
        index.wrappedLinesByHashIndex = spliceWrappedLinesByHash.remapNew(index.wrappedLinesByHashIndex, time);
    }

    /**
     * Ends a frame drawn in place: what the end of a full frame does for
     * the views rendered (input handler, trackers, accessed entities, focus
     * events, cursor), without swapping frames.
     */
    function finishInPlaceFrame(previousFocusPath:Array<Int>, previousWindowActive:Bool):Void {
        final frame = renderedFrame;
        dirtyViews.clear();
        registerPlatformInputHandler(frame);
        renderable.scene = frame.scene;

        // The views drawn inside the replaced ranges and drawn nowhere now stop reacting
        final tree = frame.dispatchTree;
        var stopped = false;
        for (i in 0...inPlaceOldViews.length) {
            final oldViewId = inPlaceOldViews[i];
            if (!renderedViews.exists(oldViewId) && !tree.containsView(oldViewId)) {
                final tracker = trackers.get(oldViewId);
                if (tracker != null) {
                    // What it accessed may not be tracked anymore
                    amendOldAccessed.push(oldViewId);
                    for (accessed in tracker.accessed.ids) {
                        amendOldAccessed.push(accessed);
                    }
                    dropTracker(oldViewId);
                    stopped = true;
                }
            }
        }
        if (stopped) {
            final ids = trackerIds;
            var kept = 0;
            for (i in 0...ids.length) {
                if (trackers.exists(ids[i])) {
                    ids[kept++] = ids[i];
                }
            }
            ids.resize(kept);
        }
        inPlaceOldViews.resize(0);
        if (inPlaceDroppedStates) {
            frame.compactElementStates();
            elementIdRoot.trie.endFrame(elementIdRoot);
        }

        AnyElement.clearArena();
        drawCount++;
        inPlaceFrameCount++;
        inPlaceFramesDrawn++;

        // The focused node may be new or gone
        final focus = _focus;
        frame.focus = focus != null && tree.focusableNodeId(focus.id) != -1 ? focus : null;
        var focusBeforeListeners = _focus;
        focusBeforeListeners = dispatchFocusChanges(previousFocusPath, previousWindowActive, focusBeforeListeners);

        updateLiveEntitiesInPlace();
        resetCursorStyle();
        refreshing = false;
        focusMovedWhileDrawing = _focus != focusBeforeListeners;

        #if glaze_verify_cache
        // Compared with a full frame, unless something changed while it
        // drew (a view notified, a scroll handle moved...): a second render
        // would show that change, the frame drawn shows it next frame
        if (verifyCache && pendingDirtyViewIds.length == 0 && !dirty && !viewDependencies.anyChanged() && _focus == inPlaceFocusAtStart) {
            verifyInPlaceFrame();
        }
        #end
    }

    /**
     * `recordEntitiesAccessed` for a frame drawn in place: the entities the
     * views rendered access now are tracked, those they accessed before and
     * nothing accesses anymore are not.
     */
    function updateLiveEntitiesInPlace():Void {
        final live = liveEntities;
        final rendered = inPlaceRenderedIds;
        inline function track(entityId:Int):Void {
            if (!live.contains(entityId)) {
                live.add(entityId);
                app.addWindowInvalidator(entityId, id, this);
            }
        }
        for (i in 0...rendered.length) {
            final viewId = rendered[i];
            track(viewId);
            final tracker = trackers.get(viewId);
            if (tracker != null) {
                for (accessed in tracker.accessed.ids) {
                    track(accessed);
                }
            }
        }
        for (accessed in frameAccessed.ids) {
            track(accessed);
            lastFrameAccessed.add(accessed);
        }
        frameAccessed.clear();
        final candidates = amendOldAccessed;
        for (i in 0...candidates.length) {
            final entityId = candidates[i];
            if (live.contains(entityId) && !stillAccessed(entityId)) {
                live.remove(entityId);
                app.removeWindowInvalidator(entityId, id);
            }
        }
        candidates.resize(0);
        inPlaceRenderedIds.resize(0);
    }

    /** Whether a view of this window or the last frame outside of views accessed the entity */
    inline function stillAccessed(entityId:Int):Bool {
        // `readersByEntity` mirrors the accessed sets of every live tracker
        return trackers.exists(entityId) || lastFrameAccessed.contains(entityId) || readersByEntity.exists(entityId);
    }


    #if glaze_verify_cache
    /**
     * Whether a view must not render for real in place of its reuse to be
     * checked (`verifyCache`): during the full frame checking a frame drawn
     * in place, the views rendered in place are reused (rendering them a
     * second time in a draw would show what their first render changed).
     */
    @:allow(glaze)
    inline function exemptFromVerification(viewId:Int):Bool {
        return inPlaceOracle && amendedViews.exists(viewId);
    }

    /**
     * Number of frames drawn in place that were compared with a full frame
     * since the start (`glaze_verify_cache`).
     */
    public static var inPlaceVerifications:Int = 0;

    /** Number of frames drawn in place that differed from the full frame */
    public static var inPlaceVerificationFailures:Int = 0;

    /** While the full frame checking a frame drawn in place is drawn */
    var inPlaceOracle:Bool = false;
    #end

    /**
     * Whether the frame being drawn is the full frame `glaze_verify_cache`
     * draws right after a frame drawn in place, to compare them (see
     * `verifyInPlaceFrame`). Always false without the define. Bookkeeping
     * that follows the paint order of a frame (the kit's text selection
     * participants) leaves this frame out: the views rendered in place are
     * reused in it, so what it paints is not the order of a frame an
     * application draws.
     */
    public inline function isVerificationFrame():Bool {
        #if glaze_verify_cache
        return inPlaceOracle;
        #else
        return false;
        #end
    }

    #if glaze_verify_cache

    /** Whether a view drawn in this frame saw other hover answers than in its last frame */
    @:allow(glaze)
    var hoverChangedInFrame:Bool = false;

    final inPlaceOracleNames:Array<String> = [];

    /**
     * `glaze_verify_cache`: right after a frame drawn in place, a full frame
     * is drawn the usual way (every view renders, see `verifyCache`, except
     * the views rendered in place, reused) and must be the frame drawn in
     * place: scene (operations and draw orders),
     * hitboxes, dispatch tree, listeners, cursor styles, tab order, element
     * states and tracked entities. The full frame is the one kept. A
     * difference is reported like a cached rendering that differs.
     */
    function verifyInPlaceFrame():Void {
        inPlaceOracleNames.resize(0);
        for (i in 0...inPlaceRoots.length) {
            final tracker = trackers.get(inPlaceRoots[i]);
            final state = tracker != null ? tracker.state : null;
            final model = state != null ? state.model : null;
            inPlaceOracleNames.push(model == null ? 'view' : Std.isOfType(model, ComponentBuilder.ComponentHost)
                ? Type.getClassName(Type.getClass((cast model : ComponentBuilder.ComponentHost).instance))
                : Type.getClassName(Type.getClass(model)));
        }
        final live = liveEntities.ids.copy();
        // Accessed outside of any view by the frame drawn in place (its
        // focus listeners): the full frame dispatches no focus change
        final outsideViews = lastFrameAccessed.ids.copy();
        final views = inPlaceViewCount;
        inPlaceInputHandlers = inputHandlerCount(renderedFrame);
        inPlaceOracle = true;
        try {
            drawFullFrame(false);
        }
        catch (e:haxe.Exception) {
            inPlaceOracle = false;
            throw glaze.util.Exceptions.rethrow(e);
        }
        inPlaceOracle = false;
        // One draw for the caller
        drawCount--;
        inPlaceViewCount = views;
        if (!hoverChangedInFrame) {
            // The views rendered in place are reused by the full frame: those
            // they rendered without drawing (measured, like the first item
            // of a uniform list) are tracked in place only
            final extra = [for (entityId in live) if (!liveEntities.contains(entityId) && !amendedViews.exists(entityId) && outsideViews.indexOf(entityId) == -1) entityId];
            final missing = [for (entityId in liveEntities.ids) if (live.indexOf(entityId) == -1) entityId];
            if (extra.length > 0 || missing.length > 0) {
                reportInPlaceDifference('tracked entities: only in place $extra, only in the full frame $missing');
            }
        }
    }

    var inPlaceInputHandlers:Int = 0;

    /** The input handlers of a frame, with the one given to the platform */
    function inputHandlerCount(frame:Frame):Int {
        var count = platformInputHandler != null ? 1 : 0;
        for (handler in frame.inputHandlers) {
            if (handler != null) count++;
        }
        return count;
    }

    function reportInPlaceDifference(difference:String):Void {
        inPlaceVerificationFailures++;
        cacheVerificationFailures++;
        onCacheVerificationFailure('In place rendering of ${inPlaceOracleNames.join(', ')} differs from a full frame ($difference)');
    }

    /** Compares the frame drawn in place with the full frame drawn after it */
    function compareInPlaceFrame(amended:Frame, full:Frame):Void {
        inPlaceVerifications++;
        if (hoverChangedInFrame) {
            // GPUI keeps the hover a view was drawn with until a mouse move notifies it
            return;
        }
        final difference = inPlaceFrameDifference(amended, full);
        if (difference != null) {
            reportInPlaceDifference(difference);
        }
    }

    function inPlaceFrameDifference(a:Frame, b:Frame):Null<String> {
        if (a.hitboxes.length != b.hitboxes.length) {
            return 'hitboxes: ${a.hitboxes.length} in place, ${b.hitboxes.length} in the full frame';
        }
        for (i in 0...a.hitboxes.length) {
            final x = a.hitboxes[i];
            final y = b.hitboxes[i];
            if (!x.bounds.equals(y.bounds) || !x.contentMask.equals(y.contentMask) || x.behavior != y.behavior) {
                return 'hitbox $i: ${x.bounds} in place, ${y.bounds} in the full frame';
            }
        }
        if (a.cursorStyles.length != b.cursorStyles.length) {
            return 'cursor styles: ${a.cursorStyles.length} in place, ${b.cursorStyles.length} in the full frame';
        }
        for (i in 0...a.cursorStyles.length) {
            final x = a.cursorStyles[i];
            final y = b.cursorStyles[i];
            if (x.style != y.style || (x.hitboxId == -1) != (y.hitboxId == -1)) {
                return 'cursor style $i';
            }
        }
        if (a.mouseListeners.length != b.mouseListeners.length) {
            return 'mouse listeners: ${a.mouseListeners.length} in place, ${b.mouseListeners.length} in the full frame';
        }
        for (i in 0...a.mouseListeners.length) {
            if (a.mouseListeners[i].kind != b.mouseListeners[i].kind) {
                return 'mouse listener $i';
            }
        }
        if (a.tooltipRequests.length != b.tooltipRequests.length) {
            return 'tooltips: ${a.tooltipRequests.length} in place, ${b.tooltipRequests.length} in the full frame';
        }
        if (a.deferredDraws.length != b.deferredDraws.length) {
            return 'deferred draws: ${a.deferredDraws.length} in place, ${b.deferredDraws.length} in the full frame';
        }
        if (a.textInputRegions.length != b.textInputRegions.length) {
            return 'text input regions: ${a.textInputRegions.length} in place, ${b.textInputRegions.length} in the full frame';
        }
        // Counted before the full frame (reused ranges move them), with the
        // one given to the platform
        final fullHandlers = inputHandlerCount(b);
        if (inPlaceInputHandlers != fullHandlers) {
            return 'input handlers: $inPlaceInputHandlers in place, $fullHandlers in the full frame';
        }
        final ta = a.dispatchTree;
        final tb = b.dispatchTree;
        if (ta.len() != tb.len()) {
            return 'dispatch nodes: ${ta.len()} in place, ${tb.len()} in the full frame';
        }
        for (i in 0...ta.len()) {
            final x = ta.node(i);
            final y = tb.node(i);
            final contexts = x.context == null ? y.context == null : y.context != null && x.context.equals(y.context);
            if (x.parent != y.parent || x.focusId != y.focusId || x.viewId != y.viewId || !contexts
                || x.keyListeners.length != y.keyListeners.length || x.actionListeners.length != y.actionListeners.length
                || x.modifiersChangedListeners.length != y.modifiersChangedListeners.length) {
                return 'dispatch node $i: parent ${x.parent} focus ${x.focusId} view ${x.viewId} in place, parent ${y.parent} focus ${y.focusId} view ${y.viewId} in the full frame';
            }
            if (x.focusId != -1 && ta.focusableNodeId(x.focusId) != tb.focusableNodeId(x.focusId)) {
                return 'focusable node of $i';
            }
            if (x.viewId != -1 && ta.viewNodeId(x.viewId) != tb.viewNodeId(x.viewId)) {
                return 'view node of $i';
            }
        }
        if ((a.focus == null ? -1 : a.focus.id) != (b.focus == null ? -1 : b.focus.id)) {
            return 'focus';
        }
        final ha = a.tabStops.insertionHistory;
        final hb = b.tabStops.insertionHistory;
        if (!sameTabOperations(a.tabStops, b.tabStops, 0, hb.length) || ha.length != hb.length) {
            return 'tab operations: ${ha.length} in place, ${hb.length} in the full frame';
        }
        final sa = a.scene;
        final sb = b.scene;
        final sceneDifference = sa.rangeDifference(0, sa.paintIndex(), sb, 0, sb.paintIndex());
        if (sceneDifference != null) {
            return 'scene: $sceneDifference';
        }
        final pa = @:privateAccess sa.opPrimitives;
        final pb = @:privateAccess sb.opPrimitives;
        for (i in 0...pa.length) {
            if (pa[i] != null && pa[i].order != pb[i].order) {
                return 'draw order of paint operation $i: ${pa[i].order} in place, ${pb[i].order} in the full frame';
            }
        }
        inline function accessedCount(frame:Frame):Int {
            var count = 0;
            for (box in frame.accessedElementStates) {
                if (box != unusedStateBox) count++;
            }
            return count;
        }
        if (accessedCount(a) != accessedCount(b)) {
            return 'accessed element states: ${accessedCount(a)} in place, ${accessedCount(b)} in the full frame';
        }
        final mark = ++stateMark;
        for (box in a.accessedElementStates) {
            box.inPlaceMark = mark;
        }
        for (box in b.accessedElementStates) {
            if (box != unusedStateBox && box.inPlaceMark != mark) {
                return 'element state ${box.node.toString()} accessed only by the full frame';
            }
        }
        return null;
    }
    #end

    /**
     * Checks the ranges recorded by the views of the last frame against its
     * arrays (debugging of in place rendering): returns the first problem.
     */
    @:noCompletion
    public function debugCheckViewRanges(maxCheckedHeight:Float):Null<String> {
        final frame = renderedFrame;
        final tree = frame.dispatchTree;
        final drawn = layoutFrame() - 1;
        for (state in frame.viewStates) {
            if (state.prepaintFrame != drawn || state.paintFrame != drawn || state.model == null) {
                continue;
            }
            final name = Type.getClassName(Type.getClass(state.model)) + ' ' + state.model.entityId;
            final node = state.dispatchNode;
            if (node < 0 || node >= tree.len() || tree.node(node).viewId != state.model.entityId) {
                return '$name: dispatch node $node is not its node';
            }
            final start = state.prepaintStart.dispatchTreeIndex;
            final end = state.prepaintEnd.dispatchTreeIndex;
            if (start > end || end > tree.len() || start != node + 1) {
                return '$name: dispatch range $start..$end after node $node';
            }
            if (end > start && tree.node(start).parent != node) {
                return '$name: first node $start has parent ${tree.node(start).parent}, not $node';
            }
            if (state.prepaintEnd.hitboxesIndex > frame.hitboxes.length || state.prepaintStart.hitboxesIndex > state.prepaintEnd.hitboxesIndex) {
                return '$name: hitboxes ${state.prepaintStart.hitboxesIndex}..${state.prepaintEnd.hitboxesIndex} of ${frame.hitboxes.length}';
            }
            // Content drawn outside of the view's bounds (scrolled, or
            // moved by the anchored element of a deferred draw) is not checked
            final drawnDeferred = state.paintStart.time > frame.deferredPaintStart.time && state.paintStart.time < frame.deferredPaintEnd.time;
            final contained = state.bounds.size.height <= maxCheckedHeight && !drawnDeferred;
            for (i in state.prepaintStart.hitboxesIndex...state.prepaintEnd.hitboxesIndex) {
                if (!contained) break;
                final b = frame.hitboxes[i].bounds;
                if (b.origin.x < state.bounds.origin.x - 0.01 || b.origin.y < state.bounds.origin.y - 0.01
                    || b.origin.x + b.size.width > state.bounds.origin.x + state.bounds.size.width + 0.01
                    || b.origin.y + b.size.height > state.bounds.origin.y + state.bounds.size.height + 0.01) {
                    return '$name: hitbox $i ${b} outside its bounds ${state.bounds}';
                }
            }
            final scene = frame.scene;
            if (state.paintEnd.sceneIndex > scene.paintIndex() || state.paintStart.sceneIndex > state.paintEnd.sceneIndex) {
                return '$name: scene ${state.paintStart.sceneIndex}..${state.paintEnd.sceneIndex} of ${scene.paintIndex()}';
            }
            final primitives = @:privateAccess scene.opPrimitives;
            final scale = _scaleFactor;
            for (i in state.paintStart.sceneIndex...state.paintEnd.sceneIndex) {
                if (!contained) break;
                final p = primitives[i];
                if (p == null) continue;
                final x = p.boundsX / scale;
                final y = p.boundsY / scale;
                if (x < state.bounds.origin.x - 2 || y < state.bounds.origin.y - 2
                    || x > state.bounds.origin.x + state.bounds.size.width + 2 || y > state.bounds.origin.y + state.bounds.size.height + 2) {
                    return '$name: paint operation $i at $x,$y outside its bounds ${state.bounds}';
                }
            }
            if (state.paintEnd.accessedElementStatesIndex > frame.accessedElementStates.length
                || state.layoutAccessedEnd > frame.accessedElementStates.length) {
                return '$name: accessed ranges past the end';
            }
            // The element states of its ranges are its own (paths under its element id)
            final accessed = frame.accessedElementStates;
            inline function under(node:GlobalElementId):Bool {
                var current = node;
                while (current != null && current.depth > state.stateId.depth) {
                    current = current.parent;
                }
                return current == state.stateId;
            }
            for (range in [
                [state.layoutAccessedStart, state.layoutAccessedEnd],
                [state.prepaintStart.accessedElementStatesIndex, state.prepaintEnd.accessedElementStatesIndex],
                [state.paintStart.accessedElementStatesIndex, state.paintEnd.accessedElementStatesIndex]
            ]) {
                for (i in range[0]...range[1]) {
                    if (accessed[i] != unusedStateBox && !under(accessed[i].node)) {
                        return '$name: accessed state $i ${accessed[i].node.toString()} in its range ${range[0]}..${range[1]} is not under ${state.stateId.toString()}';
                    }
                }
            }
            // And every accessed state under its element id is in its ranges
            // (a copy may stay outside: a retained view that renders again
            // in prepaint accesses its states again)
            inline function inRanges(i:Int):Bool {
                return (i >= state.layoutAccessedStart && i < state.layoutAccessedEnd)
                    || (i >= state.prepaintStart.accessedElementStatesIndex && i < state.prepaintEnd.accessedElementStatesIndex)
                    || (i >= state.paintStart.accessedElementStatesIndex && i < state.paintEnd.accessedElementStatesIndex);
            }
            function copiedInRanges(box:ElementStateBox<Dynamic>):Bool {
                for (j in 0...accessed.length) {
                    if (accessed[j] == box && inRanges(j)) {
                        return true;
                    }
                }
                return false;
            }
            // (what its deferred draws access is recorded after the tree)
            inline function deferredRanges(i:Int):Bool {
                return (i >= frame.deferredPrepaintStart.accessedElementStatesIndex && i < frame.deferredPrepaintEnd.accessedElementStatesIndex)
                    || (i >= frame.deferredPaintStart.accessedElementStatesIndex && i < frame.deferredPaintEnd.accessedElementStatesIndex);
            }
            for (i in 0...accessed.length) {
                if (under(accessed[i].node) && accessed[i].node != state.stateId && !inRanges(i) && !deferredRanges(i) && !copiedInRanges(accessed[i])) {
                    return '$name: accessed state $i ${accessed[i].node.toString()} under it is outside its ranges ${state.layoutAccessedStart}..${state.layoutAccessedEnd}, ${state.prepaintStart.accessedElementStatesIndex}..${state.prepaintEnd.accessedElementStatesIndex}, ${state.paintStart.accessedElementStatesIndex}..${state.paintEnd.accessedElementStatesIndex}';
                }
            }
        }
        return null;
    }

/// View caching (Rust `prepaint_index`, `reuse_prepaint`, `paint_index`, `reuse_paint`)

    /**
     * Writes the current position in the prepaint state of the next frame into `index`.
     */
    @:allow(glaze)
    function prepaintIndexInto(index:PrepaintStateIndex):Void {
        final frame = nextFrame;
        index.time = ++captureClock;
        index.hitboxesIndex = frame.hitboxes.length;
        index.tooltipsIndex = frame.tooltipRequests.length;
        index.deferredDrawsIndex = frame.deferredDraws.length;
        index.dispatchTreeIndex = frame.dispatchTree.len();
        index.accessedElementStatesIndex = frame.accessedElementStates.length;
        windowTextSystem.layoutIndexInto(index.lineLayoutIndex);
    }

    /**
     * Copies the prepaint state recorded between `start` and `end` during the
     * last frame into the next one: hitboxes, tooltips, accessed element
     * states, line layouts, dispatch nodes (under the active node) and
     * deferred draws (reused as well when drawn).
     */
    @:allow(glaze)
    function reusePrepaint(start:PrepaintStateIndex, end:PrepaintStateIndex):Void {
        final rendered = renderedFrame;
        final next = nextFrame;
        for (i in start.hitboxesIndex...end.hitboxesIndex) {
            next.hitboxes.push(rendered.hitboxes[i]);
        }
        for (i in start.tooltipsIndex...end.tooltipsIndex) {
            next.tooltipRequests.push(rendered.tooltipRequests[i]);
        }
        for (i in start.accessedElementStatesIndex...end.accessedElementStatesIndex) {
            final key = rendered.accessedElementStates[i];
            next.accessedElementStates.push(key);
            next.reusedElementStates.push(key);
        }
        windowTextSystem.reuseLayouts(start.lineLayoutIndex, end.lineLayoutIndex);

        final oldStart = start.dispatchTreeIndex;
        final newStart = next.dispatchTree.reuseSubtree(oldStart, end.dispatchTreeIndex, rendered.dispatchTree, focusId());
        if (next.dispatchTree.reusedSubtreeContainsFocus) {
            next.focus = _focus;
        }

        for (i in start.deferredDrawsIndex...end.deferredDrawsIndex) {
            final source = rendered.deferredDraws[i];
            final draw = new DeferredDraw();
            draw.currentView = source.currentView;
            draw.parentNode = source.parentNode - oldStart + newStart;
            draw.elementIdNode = source.elementIdNode;
            draw.textStyleStack = source.textStyleStack;
            draw.contentMask = source.contentMask;
            draw.remSize = source.remSize;
            draw.priority = source.priority;
            draw.element = null;
            draw.absoluteOffset = source.absoluteOffset;
            draw.prepaintStart.copyFrom(source.prepaintStart);
            draw.prepaintEnd.copyFrom(source.prepaintEnd);
            draw.paintStart.copyFrom(source.paintStart);
            draw.paintEnd.copyFrom(source.paintEnd);
            next.deferredDraws.push(draw);
        }
    }

    /**
     * Number of element states accessed so far during this frame.
     */
    @:allow(glaze)
    inline function accessedElementStatesIndex():Int {
        return nextFrame.accessedElementStates.length;
    }

    @:allow(glaze)
    inline function reusedElementStatesIndex():Int {
        return nextFrame.reusedElementStates.length;
    }

    /**
     * Forgets the element states copied by `reuseAccessedElementStates` at
     * `start...end` (and from `reusedStart` in the reused list) for a
     * retained view that renders again after all: it accesses what it uses
     * again, and a state it no longer uses is dropped like after a render
     * (a copy left in its ancestors' ranges would keep it alive).
     */
    @:allow(glaze)
    function forgetReusedElementStates(start:Int, end:Int, reusedStart:Int):Void {
        final next = nextFrame;
        final accessed = next.accessedElementStates;
        final reused = next.reusedElementStates;
        for (i in start...end) {
            accessed[i] = unusedStateBox;
            final j = reusedStart + (i - start);
            if (reusedStart >= 0 && j < reused.length) {
                reused[j] = unusedStateBox;
            }
        }
    }

    /**
     * Marks the element states accessed between `start` and `end` during the
     * last frame as accessed again (they are kept for the next frame).
     */
    @:allow(glaze)
    function reuseAccessedElementStates(start:Int, end:Int):Void {
        final rendered = renderedFrame;
        final next = nextFrame;
        for (i in start...end) {
            final key = rendered.accessedElementStates[i];
            next.accessedElementStates.push(key);
            next.reusedElementStates.push(key);
        }
    }

    /**
     * Writes the current position in the paint state of the next frame into `index`.
     */
    @:allow(glaze)
    function paintIndexInto(index:PaintIndex):Void {
        final frame = nextFrame;
        index.time = ++captureClock;
        index.sceneIndex = frame.scene.paintIndex();
        index.mouseListenersIndex = frame.mouseListeners.length;
        index.inputHandlersIndex = frame.inputHandlers.length;
        index.textInputRegionsIndex = frame.textInputRegions.length;
        index.cursorStylesIndex = frame.cursorStyles.length;
        index.accessedElementStatesIndex = frame.accessedElementStates.length;
        index.tabHandleIndex = frame.tabStops.paintIndex();
        windowTextSystem.layoutIndexInto(index.lineLayoutIndex);
    }

    /**
     * Copies the paint state recorded between `start` and `end` during the
     * last frame into the next one: cursor styles, input handlers, mouse
     * listeners, accessed element states, tab stops, line layouts and the
     * scene paint operations (replayed).
     */
    @:allow(glaze)
    function reusePaint(start:PaintIndex, end:PaintIndex):Void {
        final rendered = renderedFrame;
        final next = nextFrame;
        for (i in start.cursorStylesIndex...end.cursorStylesIndex) {
            next.cursorStyles.push(rendered.cursorStyles[i]);
        }
        for (i in start.inputHandlersIndex...end.inputHandlersIndex) {
            next.inputHandlers.push(rendered.inputHandlers[i]);
            rendered.inputHandlers[i] = null;
        }
        for (i in start.mouseListenersIndex...end.mouseListenersIndex) {
            next.mouseListeners.push(rendered.mouseListeners[i]);
        }
        for (i in start.textInputRegionsIndex...end.textInputRegionsIndex) {
            next.textInputRegions.push(rendered.textInputRegions[i]);
        }
        for (i in start.accessedElementStatesIndex...end.accessedElementStatesIndex) {
            final key = rendered.accessedElementStates[i];
            next.accessedElementStates.push(key);
            next.reusedElementStates.push(key);
        }
        // While a view renders in place, the frame's scene and tab order
        // are being made again: the ranges index the previous ones
        // (as they were when the frame started: the indices are moved back
        // by what the views rendered in place before added, see
        // `sceneSourceShift`)
        final tabsSource = tabStopsSource;
        if (tabsSource != null) {
            next.tabStops.replayRange(tabsSource, start.tabHandleIndex - tabStopsSourceShift, end.tabHandleIndex - tabStopsSourceShift);
        }
        else {
            next.tabStops.replayRange(rendered.tabStops, start.tabHandleIndex, end.tabHandleIndex);
        }
        windowTextSystem.reuseLayouts(start.lineLayoutIndex, end.lineLayoutIndex);
        final source = sceneSource;
        if (source != null) {
            next.scene.replay(start.sceneIndex - sceneSourceShift, end.sceneIndex - sceneSourceShift, source);
        }
        else {
            next.scene.replay(start.sceneIndex, end.sceneIndex, rendered.scene);
        }
    }

/// View caching: debugging

    /**
     * Debug check of the view cache, compiled in with the define
     * `glaze_verify_cache` (off by default; this switch has no effect
     * without it). A view or persistent component that would be reused from
     * the cache renders for real instead, and what it draws (its scene
     * primitives, hitboxes and cursor styles) is compared with what the
     * reuse would have drawn, the ranges of the last frame. A difference
     * means its rendering changed while nothing invalidated it: it is
     * reported with `onCacheVerificationFailure`. The real rendering is the
     * one displayed. Tests set it to `false` around code that counts renders.
     */
    public static var verifyCache:Bool = #if glaze_verify_cache true #else false #end;

    /**
     * Number of renderings found different from their cached rendering
     * since the start (`glaze_verify_cache`).
     */
    public static var cacheVerificationFailures:Int = 0;

    /**
     * Number of cached renderings compared since the start
     * (`glaze_verify_cache`).
     */
    public static var cacheVerifications:Int = 0;

    /**
     * Called with the message of each rendering found different from its
     * cached rendering (`glaze_verify_cache`). Logs a warning by default.
     */
    public static var onCacheVerificationFailure:(message:String) -> Void = defaultOnCacheVerificationFailure;

    static function defaultOnCacheVerificationFailure(message:String):Void {
        ceramic.Shortcuts.log.warning(message);
    }

    #if glaze_verify_cache
    /** The views drawn for real that are painting, outermost first (see `beginVerifyScope`) */
    final verifyScopes:Array<CacheVerification.VerifyScope> = [];

    final verifyScopePool:Array<CacheVerification.VerifyScope> = [];

    /**
     * A view with a cache state starts painting for real (`glaze_verify_cache`):
     * opens its scope, where the views painted for real inside it record
     * themselves (`endVerifyScope`). `old` holds the ranges the view drew
     * in the last frame, `null` when it drew none (a view the frame did
     * not draw).
     */
    @:allow(glaze)
    function beginVerifyScope(entityId:Int, old:Null<CacheVerification>, state:ViewElement.ViewElementState, dirty:Bool):CacheVerification.VerifyScope {
        final scope = verifyScopePool.length > 0 ? verifyScopePool.pop() : new CacheVerification.VerifyScope();
        scope.entityId = entityId;
        scope.old = old;
        scope.state = state;
        scope.dirty = dirty;
        verifyScopes.push(scope);
        return scope;
    }

    /**
     * A view without a cache was drawn for real: the views around it cannot
     * compare their ranges (its share of them is unknown in the last frame).
     */
    @:allow(glaze)
    function cacheVerificationUnverifiable():Void {
        for (scope in verifyScopes) {
            scope.unverifiable = true;
        }
    }

    /**
     * The view of `scope` painted (`glaze_verify_cache`). When `compare`
     * (its cache was reusable and it was rendered for real instead), what it
     * drew is compared with its cached ranges, the ranges of the views
     * drawn for real inside it left out of both sides (`cachedRenderingDifference`):
     * a view notified inside it changes its drawing legitimately, and a
     * stale view inside it is reported on its own. A view drawn inside it
     * that the last frame did not draw is a change of its own render, and is
     * reported. The scope is then recorded in the enclosing view's scope.
     */
    @:allow(glaze)
    function endVerifyScope(scope:CacheVerification.VerifyScope, compare:Bool, name:String, path:Null<GlobalElementId>):Void {
        final popped = verifyScopes.pop();
        if (popped != scope) {
            throw 'Unbalanced verify scopes';
        }
        if (compare && !scope.unverifiable) {
            cacheVerifications++;
            var difference = scope.newViewInside ? 'it draws a view the last frame did not draw' : null;
            if (difference == null) {
                difference = cachedRenderingDifference(scope);
            }
            if (difference != null) {
                cacheVerificationFailures++;
                final where = path != null ? ' (element ${path.toString()})' : '';
                onCacheVerificationFailure('$name$where rendered differently from its cached rendering without being notified: notify() probably missing, or a read the tracker does not see ($difference)');
            }
        }
        final parent = verifyScopes.length > 0 ? verifyScopes[verifyScopes.length - 1] : null;
        if (parent != null) {
            if (scope.old == null) {
                if (renderedFrame.dispatchTree.viewNodeId(scope.entityId) == -1) {
                    // Not drawn in the last frame: the view around it changed
                    parent.newViewInside = true;
                }
                else if (scope.dirty) {
                    // Drawn in the last frame inside a reused range, so its
                    // own ranges were not recorded since: what it drew then
                    // cannot be left out of the comparison
                    parent.unverifiable = true;
                }
                // Otherwise it draws the same as in the last frame (not
                // dirty, not moved), at the same place in its parent's range
            }
            if (scope.unverifiable) {
                parent.unverifiable = true;
            }
            // Its ranges are left out of the comparison of the views around
            // it (it is the one that changed, or it is reported itself)
            parent.nested.push(scope);
        }
        else {
            recycleVerifyScope(scope);
        }
    }

    function recycleVerifyScope(scope:CacheVerification.VerifyScope):Void {
        for (nested in scope.nested) {
            recycleVerifyScope(nested);
        }
        scope.reset();
        verifyScopePool.push(scope);
    }

    /** Clears the verify scopes left open by a draw that threw */
    function resetVerifyScopes():Void {
        while (verifyScopes.length > 0) {
            recycleVerifyScope(verifyScopes.pop());
        }
    }

    final verifyKeptOld:Array<Int> = [];
    final verifyKeptNew:Array<Int> = [];
    final verifySubsOld:Array<Int> = [];
    final verifySubsNew:Array<Int> = [];

    /**
     * Fills `verifyKeptOld` and `verifyKeptNew` with the indices of
     * `oldStart...oldEnd` and `newStart...newEnd` outside of the ranges of the
     * nested views (`verifySubsOld`, `verifySubsNew`: pairs of start and end,
     * in any order). Returns a description when the counts differ.
     */
    function keptIndices(what:String, oldStart:Int, oldEnd:Int, newStart:Int, newEnd:Int):Null<String> {
        inline function fill(kept:Array<Int>, start:Int, end:Int, subs:Array<Int>):Void {
            kept.resize(0);
            var i = start;
            while (i < end) {
                var inside = false;
                var k = 0;
                while (k < subs.length) {
                    if (i >= subs[k] && i < subs[k + 1]) {
                        inside = true;
                        i = subs[k + 1];
                        break;
                    }
                    k += 2;
                }
                if (!inside) {
                    kept.push(i);
                    i++;
                }
            }
        }
        fill(verifyKeptOld, oldStart, oldEnd, verifySubsOld);
        fill(verifyKeptNew, newStart, newEnd, verifySubsNew);
        if (verifyKeptOld.length != verifyKeptNew.length) {
            final inside = verifySubsOld.length > 0 ? ' (views inside left out)' : '';
            return '$what: ${verifyKeptOld.length} cached, ${verifyKeptNew.length} rendered$inside';
        }
        return null;
    }

    /**
     * The first difference between the ranges of the last frame kept in
     * `scope.old` and those of this frame in `scope.state`, the ranges of
     * the views drawn for real inside the view left out, `null` when they
     * draw the same. Compares the hitboxes, the cursor styles and the paint
     * operations, and the counts of dispatch nodes, tooltip requests,
     * deferred draws, mouse listeners, input handlers, text input regions
     * and tab stops.
     */
    function cachedRenderingDifference(scope:CacheVerification.VerifyScope):Null<String> {
        final verification = scope.old;
        final state = scope.state;
        final old = renderedFrame;
        final next = nextFrame;
        final nested = scope.nested;
        final subsOld = verifySubsOld;
        final subsNew = verifySubsNew;

        // A nested view without ranges of the last frame (drawn inside a
        // reused range since its parent last rendered) draws the same on
        // both sides: it is compared with the rest
        inline function prepaintSubs(get:(PrepaintStateIndex) -> Int):Void {
            subsOld.resize(0);
            subsNew.resize(0);
            for (n in nested) {
                if (n.old != null) {
                    subsOld.push(get(n.old.prepaintStart));
                    subsOld.push(get(n.old.prepaintEnd));
                    subsNew.push(get(n.state.prepaintStart));
                    subsNew.push(get(n.state.prepaintEnd));
                }
            }
        }
        inline function paintSubs(get:(PaintIndex) -> Int):Void {
            subsOld.resize(0);
            subsNew.resize(0);
            for (n in nested) {
                if (n.old != null) {
                    subsOld.push(get(n.old.paintStart));
                    subsOld.push(get(n.old.paintEnd));
                    subsNew.push(get(n.state.paintStart));
                    subsNew.push(get(n.state.paintEnd));
                }
            }
        }

        prepaintSubs(i -> i.hitboxesIndex);
        var problem = keptIndices('hitboxes', verification.prepaintStart.hitboxesIndex, verification.prepaintEnd.hitboxesIndex, state.prepaintStart.hitboxesIndex, state.prepaintEnd.hitboxesIndex);
        if (problem != null) return problem;
        for (i in 0...verifyKeptNew.length) {
            final a = old.hitboxes[verifyKeptOld[i]];
            final b = next.hitboxes[verifyKeptNew[i]];
            if (!a.bounds.equals(b.bounds) || !a.contentMask.equals(b.contentMask) || a.behavior != b.behavior) {
                return 'hitbox $i: ${a.bounds} cached, ${b.bounds} rendered';
            }
        }

        prepaintSubs(i -> i.dispatchTreeIndex);
        problem = keptIndices('dispatch nodes', verification.prepaintStart.dispatchTreeIndex, verification.prepaintEnd.dispatchTreeIndex, state.prepaintStart.dispatchTreeIndex, state.prepaintEnd.dispatchTreeIndex);
        if (problem != null) return problem;
        prepaintSubs(i -> i.tooltipsIndex);
        problem = keptIndices('tooltip requests', verification.prepaintStart.tooltipsIndex, verification.prepaintEnd.tooltipsIndex, state.prepaintStart.tooltipsIndex, state.prepaintEnd.tooltipsIndex);
        if (problem != null) return problem;
        prepaintSubs(i -> i.deferredDrawsIndex);
        problem = keptIndices('deferred draws', verification.prepaintStart.deferredDrawsIndex, verification.prepaintEnd.deferredDrawsIndex, state.prepaintStart.deferredDrawsIndex, state.prepaintEnd.deferredDrawsIndex);
        if (problem != null) return problem;

        paintSubs(i -> i.cursorStylesIndex);
        problem = keptIndices('cursor styles', verification.paintStart.cursorStylesIndex, verification.paintEnd.cursorStylesIndex, state.paintStart.cursorStylesIndex, state.paintEnd.cursorStylesIndex);
        if (problem != null) return problem;
        for (i in 0...verifyKeptNew.length) {
            final a = old.cursorStyles[verifyKeptOld[i]];
            final b = next.cursorStyles[verifyKeptNew[i]];
            if (a.style != b.style || (a.hitboxId == -1) != (b.hitboxId == -1)) {
                return 'cursor style $i: ${a.style} cached, ${b.style} rendered';
            }
        }
        paintSubs(i -> i.mouseListenersIndex);
        problem = keptIndices('mouse listeners', verification.paintStart.mouseListenersIndex, verification.paintEnd.mouseListenersIndex, state.paintStart.mouseListenersIndex, state.paintEnd.mouseListenersIndex);
        if (problem != null) return problem;
        paintSubs(i -> i.inputHandlersIndex);
        problem = keptIndices('input handlers', verification.paintStart.inputHandlersIndex, verification.paintEnd.inputHandlersIndex, state.paintStart.inputHandlersIndex, state.paintEnd.inputHandlersIndex);
        if (problem != null) return problem;
        paintSubs(i -> i.textInputRegionsIndex);
        problem = keptIndices('text input regions', verification.paintStart.textInputRegionsIndex, verification.paintEnd.textInputRegionsIndex, state.paintStart.textInputRegionsIndex, state.paintEnd.textInputRegionsIndex);
        if (problem != null) return problem;
        paintSubs(i -> i.tabHandleIndex);
        problem = keptIndices('tab stops', verification.paintStart.tabHandleIndex, verification.paintEnd.tabHandleIndex, state.paintStart.tabHandleIndex, state.paintEnd.tabHandleIndex);
        if (problem != null) return problem;

        paintSubs(i -> i.sceneIndex);
        problem = keptIndices('paint operations', verification.paintStart.sceneIndex, verification.paintEnd.sceneIndex, state.paintStart.sceneIndex, state.paintEnd.sceneIndex);
        if (problem != null) return problem;
        final oldScene = sceneSource != null ? sceneSource : old.scene;
        if (sceneSource != null && sceneSourceShift != 0) {
            // (see `sceneSourceShift`)
            for (i in 0...verifyKeptOld.length) {
                verifyKeptOld[i] -= sceneSourceShift;
            }
        }
        return next.scene.indexedDifference(verifyKeptNew, oldScene, verifyKeptOld);
    }
    #end

    /**
     * Number of layout runs (a layout root computed by taffy) since the
     * window was opened, for tests and benchmarks.
     */
    public function layoutRunCount():Int {
        return layoutEngine.runCount;
    }

    /**
     * Number of changed layout nodes checked by the incremental layout, and
     * how many of them laid out like the nodes they replaced (so that their
     * parents were not laid out again), since the window was opened, for
     * tests and benchmarks (see `TaffyLayoutEngine`).
     */
    @:noCompletion
    public function layoutNodeCount():Int {
        return layoutEngine.nodeCount();
    }

    @:noCompletion
    public function layoutChangeCounts():{checked:Int, matched:Int} {
        return {checked: layoutEngine.changesChecked, matched: layoutEngine.changesMatched};
    }

    /**
     * A text summary of the last frame besides its scene (hitboxes, mouse
     * listeners, cursor styles, tooltips, deferred draws, input handlers,
     * dispatch nodes with their contexts, focus and view ids, tab order),
     * independent of hitbox ids: two windows drawing the same views, one with
     * view caching and one without, must give the same summary. For tests.
     */
    public function debugFrameSummary():String {
        final frame = renderedFrame;
        final buf = new StringBuf();
        buf.add('hitboxes ${frame.hitboxes.length}\n');
        for (hitbox in frame.hitboxes) {
            buf.add('  ${hitbox.bounds} ${hitbox.contentMask.bounds} ${hitbox.behavior}\n');
        }
        buf.add('mouse listeners ${frame.mouseListeners.length}\n');
        for (entry in frame.mouseListeners) {
            buf.add('  ${entry.kind}\n');
        }
        buf.add('cursor styles ${frame.cursorStyles.length}\n');
        for (request in frame.cursorStyles) {
            buf.add('  ${request.style} ${request.hitboxId == -1 ? 'window' : 'hitbox'}\n');
        }
        buf.add('tooltips ${frame.tooltipRequests.length}\n');
        buf.add('deferred draws ${frame.deferredDraws.length}\n');
        var handlers = 0;
        for (handler in frame.inputHandlers) {
            if (handler != null) handlers++;
        }
        if (platformInputHandler != null) handlers++;
        buf.add('input handlers $handlers\n');
        final tree = frame.dispatchTree;
        buf.add('dispatch nodes ${tree.len()}\n');
        for (i in 0...tree.len()) {
            final node = tree.node(i);
            buf.add('  ${node.parent} ctx=${node.context != null ? node.context.toString() : ''} focus=${node.focusId} view=${node.viewId} keys=${node.keyListeners.length} actions=${node.actionListeners.length} mods=${node.modifiersChangedListeners.length}\n');
        }
        buf.add('focus ${frame.focus != null ? frame.focus.id : -1}\n');
        buf.add('tab stops ${frame.tabStops.tabStopCount()}\n');
        var handle = frame.tabStops.next(-1);
        final first = handle;
        var count = 0;
        while (handle != null && count < 1000) {
            buf.add('  ${handle.id}\n');
            handle = frame.tabStops.next(handle.id);
            if (handle == first) break;
            count++;
        }
        return buf.toString();
    }

/// View caching: layout

    /**
     * The layout engine frame number (see `TaffyLayoutEngine.retain`).
     */
    @:allow(glaze)
    inline function layoutFrame():Int {
        return layoutEngine.currentFrame();
    }

    /**
     * Retains the layout subtree a cached view recorded during the last frame.
     */
    @:allow(glaze)
    inline function retainLayout(layoutId:LayoutId, recordedFrame:Int):Bool {
        return layoutEngine.retain(layoutId, recordedFrame);
    }

    /**
     * Starts recording the layout nodes a view requests while it renders,
     * adopting `adopt` (its retained nodes) when they match (see
     * `TaffyLayoutEngine.beginViewNodes`).
     */
    @:allow(glaze)
    inline function beginViewLayoutNodes(adopt:Null<Array<Int>>, checked:Bool = false):Void {
        layoutEngine.beginViewNodes(adopt, checked);
    }

    /**
     * Ends `beginViewLayoutNodes()`: the nodes the view requested, in order.
     */
    @:allow(glaze)
    inline function endViewLayoutNodes():Array<Int> {
        return layoutEngine.endViewNodes();
    }

    /**
     * Whether the last `endViewLayoutNodes()` adopted every node it was given.
     */
    @:allow(glaze)
    inline function viewLayoutNodesAdopted():Bool {
        return layoutEngine.lastViewNodesAdopted;
    }

    /**
     * Replaces a retained layout subtree by the subtree of the same view
     * rendered again (see `TaffyLayoutEngine.replaceRetained`).
     */
    @:allow(glaze)
    inline function replaceRetainedLayout(oldRoot:LayoutId, newRoot:LayoutId):Bool {
        return layoutEngine.replaceRetained(oldRoot, newRoot);
    }

    /**
     * Marks a view dirty for the next frame (used when a cache turns out to be stale).
     */
    @:allow(glaze)
    function invalidateViewForNextFrame(viewId:Int):Void {
        addPendingDirtyView(viewId);
        dirty = true;
    }

    /**
     * The image cache on top of the image cache stack, or null.
     */
    @:allow(glaze)
    inline function currentImageCache():Null<AnyImageCache> {
        return imageCacheStack.length > 0 ? imageCacheStack[imageCacheStack.length - 1] : null;
    }

    /**
     * The layout engine of this window.
     */
    @:allow(glaze)
    inline function layoutEngineInstance():TaffyLayoutEngine {
        return layoutEngine;
    }

/// Hitboxes and mouse state

    /**
     * This method should be called during `prepaint`. You can use
     * the returned `Hitbox` during `paint` or in an event handler
     * to determine whether the inserted hitbox was the topmost.
     */
    public function insertHitbox(bounds:Bounds, behavior:HitboxBehavior):Hitbox {
        final hitbox = new Hitbox(nextHitboxId, bounds, contentMask(), behavior);
        nextHitboxId++;
        nextFrame.hitboxes.push(hitbox);
        return hitbox;
    }

    /**
     * Checks if the hitbox with this id is currently hovered. Returns `false` during keyboard
     * input modality so that keyboard navigation suppresses hover highlights.
     * (Rust `HitboxId::is_hovered`.)
     */
    public function isHitboxIdHovered(hitboxId:Int):Bool {
        // If this hitbox has captured the pointer, it's always considered hovered
        if (_capturedHitbox == hitboxId) {
            return logHover(true);
        }
        if (lastInputWasKeyboard()) {
            return logHover(false);
        }
        return logHover(hitboxHitTest(hitboxId));
    }

    /**
     * Checks if the hitbox with this id is currently hovered, regardless of the last
     * input modality used.
     */
    public function isHitboxIdHoveredIgnoringLastInput(hitboxId:Int):Bool {
        if (_capturedHitbox == hitboxId) {
            return logHover(true);
        }
        return logHover(hitboxHitTest(hitboxId));
    }

    /**
     * `glaze_verify_cache`: the answers of the hover tests made while the
     * window draws, in order. A view whose drawing got other answers than
     * in the frame it was cached from is not compared: GPUI leaves the hover
     * of a cached view as it was until a mouse move notifies the view.
     */
    #if glaze_verify_cache
    final hoverLog:Array<Bool> = [];
    #end

    inline function logHover(hovered:Bool):Bool {
        #if glaze_verify_cache
        if (drawing) {
            hoverLog.push(hovered);
        }
        #end
        return hovered;
    }

    #if glaze_verify_cache
    @:allow(glaze)
    inline function hoverLogMark():Int {
        return hoverLog.length;
    }

    @:allow(glaze)
    function hoverLogSegment(start:Int, end:Int):String {
        final buf = new StringBuf();
        for (i in start...end) {
            buf.add(hoverLog[i] ? '1' : '0');
        }
        return buf.toString();
    }

    function clearHoverLog():Void {
        hoverLog.resize(0);
    }
    #end

    function hitboxHitTest(hitboxId:Int):Bool {
        final hitTest = mouseHitTest;
        for (i in 0...hitTest.hoverHitboxCount) {
            if (hitTest.ids[i] == hitboxId) {
                return true;
            }
        }
        return false;
    }

    /**
     * Checks if the hitbox with this id contains the mouse and should handle scroll events.
     */
    public function shouldHitboxIdHandleScroll(hitboxId:Int):Bool {
        return mouseHitTest.ids.indexOf(hitboxId) != -1;
    }

    /**
     * Checks whether the hitbox would be hovered at `position`, regardless of the current input
     * modality or mouse position.
     */
    public function isHitboxIdHoveredAt(hitboxId:Int, position:Point):Bool {
        final hitTest = renderedFrame.hitTest(position);
        for (i in 0...hitTest.hoverHitboxCount) {
            if (hitTest.ids[i] == hitboxId) {
                return true;
            }
        }
        return false;
    }

    /**
     * The position of the mouse relative to the window.
     */
    public inline function mousePosition():Point {
        return _mousePosition;
    }

    /**
     * Captures the pointer for the given hitbox. While captured, all mouse move and mouse up
     * events will be routed to listeners that check this hitbox's `isHovered` status,
     * regardless of actual hit testing. This enables drag operations that continue
     * even when the pointer moves outside the element's bounds.
     *
     * The capture is automatically released on mouse up.
     */
    public function capturePointer(hitboxId:Int):Void {
        _capturedHitbox = hitboxId;
    }

    /**
     * Releases any active pointer capture.
     */
    public function releasePointer():Void {
        _capturedHitbox = -1;
    }

    /**
     * Returns the hitbox that has captured the pointer, or -1.
     */
    public inline function capturedHitbox():Int {
        return _capturedHitbox;
    }

    /**
     * The current state of the keyboard's modifiers.
     */
    public inline function modifiers():Modifiers {
        return _modifiers;
    }

    /**
     * Returns true if the last input event was keyboard-based (key press, tab navigation, etc.).
     * This is used for focus-visible styling to show focus indicators only for keyboard navigation.
     */
    public inline function lastInputWasKeyboard():Bool {
        return lastInputModality == Keyboard;
    }

    /**
     * Returns true if the last input event was a touch.
     */
    public inline function lastInputWasTouch():Bool {
        return lastInputModality == Touch;
    }

    /**
     * The current state of the keyboard's capslock.
     */
    public inline function capslock():Bool {
        return _capslock;
    }

    /**
     * Prevent the default behavior of this event.
     */
    public inline function preventDefault():Void {
        _defaultPrevented = true;
    }

    /**
     * Obtain whether default has been prevented for the event currently being dispatched
     * (Rust `default_prevented`).
     */
    public inline function defaultPrevented():Bool {
        return _defaultPrevented;
    }

    /**
     * Returns whether this window is focused by the operating system (receiving key events).
     */
    public inline function isWindowActive():Bool {
        return _active;
    }

    /**
     * Activates or deactivates the window (the platform window gaining or losing focus).
     */
    public function setActive(active:Bool):Void {
        if (_active == active)
            return;
        _active = active;
        activationObservers.retain(0, callback -> callback(this, app));
        boundsChanged();
        refresh();
    }

/// Appearance

    var _appearance:WindowAppearance = Light;

    /**
     * Returns the appearance of the current window (Rust `appearance`): read
     * from the platform window when the window opens and when the platform
     * reports a change.
     */
    public inline function appearance():WindowAppearance {
        return _appearance;
    }

    /** The appearance of the platform window (`Light` without platform operations, like a test window). */
    function platformAppearance():WindowAppearance {
        return platformOperations != null ? platformOperations.appearance() : Light;
    }

    /**
     * Rust: the `on_appearance_changed` callback of `Window::new`, which
     * defers the update on the foreground executor (changing the appearance
     * may be reported while the app is updating).
     */
    function handleSystemAppearanceChange(_:ceramic.SystemAppearance):Void {
        if (destroyed)
            return;
        app.foregroundExecutor().spawn(() -> {
            if (!destroyed)
                app.update(cx -> appearanceChanged(cx));
            return null;
        });
    }

    /**
     * Reads the appearance of the platform window again and runs the
     * appearance observers (Rust `appearance_changed`).
     */
    @:allow(glaze)
    function appearanceChanged(cx:App):Void {
        _appearance = platformAppearance();
        appearanceObservers.retain(0, callback -> callback(this, cx));
    }

    /**
     * Registers a callback to be invoked when the window appearance changes
     * (Rust `observe_window_appearance`).
     */
    public function observeWindowAppearance(callback:(Window, App) -> Void):Subscription {
        final subscriber = appearanceObservers.insert(0, (window, cx) -> {
            callback(window, cx);
            return true;
        });
        subscriber.activate();
        return subscriber.subscription;
    }

    /**
     * Registers a callback called when the window appearance changes
     * (Rust `window.appearance_observers.insert`).
     */
    @:allow(glaze)
    function newAppearanceObserver(callback:(Window, App) -> Bool):{subscription:Subscription, activate:() -> Void} {
        final subscriber = appearanceObservers.insert(0, callback);
        return {subscription: subscriber.subscription, activate: subscriber.activate};
    }

/// Platform window

    var _isResizable:Bool = true;

    var _isMinimizable:Bool = true;

    var _clientInset:Null<Pixels> = null;

    var _removed:Bool = false;

    /**
     * The native window operations Ceramic does not expose yet (minimize,
     * zoom, interactive move and resize, window menu, title bar double click).
     * Null by default: the requests are ignored, like GPUI's headless windows.
     */
    public var platformOperations:Null<PlatformWindowOperations> = null;

    /**
     * The resize zones of a client-decorated window in window coordinates,
     * flat as `x, y, width, height, kind` (`ceramic.WindowHitKind`), set by
     * the element that draws the window border (gpui-kit's WindowBorder) and
     * published to the native window with the drag areas of the window
     * controls (see `CeramicWindowOperations.hitRegions`). Port addition:
     * GPUI starts native resizes from `startWindowResize`, which SDL cannot
     * do, so the operating system needs the zones up front.
     */
    public var nativeResizeZones:Null<Array<Float>> = null;

    /** The window whose hit regions the native window currently uses. */
    static var hitRegionsOwner:Null<Window> = null;

    /** The hit regions this window published last (flat, screen coordinates). */
    var publishedHitRegions:Array<Float> = [];

    final hitRegionPoint = new ceramic.Point();

    /**
     * Publishes the drag and resize regions of this window to the native
     * window after a frame (see `CeramicWindowOperations.hitRegions`), when
     * they changed. A window without any gives the native window back to the
     * one that had them last only if it was this one.
     */
    function publishHitRegions():Void {
        if (!Std.isOfType(platformOperations, glaze.platform.CeramicWindowOperations))
            return;
        final regions = glaze.platform.CeramicWindowOperations.hitRegions(this, hitRegionPoint);
        if (regions.length == 0 && hitRegionsOwner != this)
            return;
        var same = hitRegionsOwner == this && regions.length == publishedHitRegions.length;
        if (same) {
            for (i in 0...regions.length) {
                if (regions[i] != publishedHitRegions[i]) {
                    same = false;
                    break;
                }
            }
        }
        if (same)
            return;
        publishedHitRegions = regions;
        hitRegionsOwner = regions.length > 0 ? this : null;
        ceramic.App.app.screen.setWindowHitRegions(regions);
    }

    /**
     * The decorations the platform gives the window (Rust
     * `PlatformWindow::window_decorations`). The port's windows are server
     * decorated; tests can set `Client` to check client side decorations.
     */
    public var platformDecorations:Decorations = Server;

    /**
     * The window controls the platform supports (Rust
     * `PlatformWindow::window_controls`, everything by default).
     */
    public var platformControls:WindowControls = new WindowControls();

    /**
     * Returns whether the title bar window controls need to be rendered by the application (Wayland and X11)
     */
    public inline function windowDecorations():Decorations {
        return platformDecorations;
    }

    /**
     * Returns the controls supported by the platform.
     */
    public inline function windowControls():WindowControls {
        return platformControls;
    }

    /**
     * When using client side decorations, set this to the width of the invisible decorations (Wayland and X11)
     */
    public function setClientInset(inset:Pixels):Void {
        // The port has no client side decorations: the inset is only kept.
        _clientInset = inset;
    }

    /**
     * Returns the client_inset value by `setClientInset`.
     */
    public inline function clientInset():Null<Pixels> {
        return _clientInset;
    }

    /**
     * Returns whether this window is resizable.
     */
    public inline function isResizable():Bool {
        return _isResizable;
    }

    /**
     * Returns whether this window is minimizable.
     */
    public inline function isMinimizable():Bool {
        return _isMinimizable;
    }

    /**
     * Check if the platform window is maximized.
     */
    public function isMaximized():Bool {
        return platformOperations != null && platformOperations.isMaximized();
    }

    /**
     * Returns whether or not the window is currently fullscreen (Ceramic's
     * `settings.fullscreen`, the state of the app window).
     */
    public function isFullscreen():Bool {
        return ceramic.App.app.settings.fullscreen;
    }

    /**
     * Toggle full screen status on the current window at the platform level
     * (through Ceramic's `settings.fullscreen`).
     */
    public function toggleFullscreen():Void {
        final settings = ceramic.App.app.settings;
        settings.fullscreen = !settings.fullscreen;
    }

    /**
     * Bring the window to the front and give it the keyboard focus (Rust
     * `activate_window`): through `platformOperations`, the Ceramic app
     * window by default (see `CeramicWindowOperations.activate`).
     */
    public function activateWindow():Void {
        if (platformOperations != null) platformOperations.activate();
    }

    /**
     * Minimize the window at the platform level.
     */
    public function minimizeWindow():Void {
        if (platformOperations != null) platformOperations.minimize();
    }

    /**
     * Zoom the window at the platform level (maximize or restore).
     */
    public function zoomWindow():Void {
        if (platformOperations != null) platformOperations.zoom();
    }

    /**
     * Tells the compositor to take control of window movement (Wayland and X11).
     */
    public function startWindowMove():Void {
        // The operating system moves the window through the hit regions
        // (see CeramicWindowOperations)
        if (platformOperations != null) platformOperations.startWindowMove();
    }

    /**
     * Tells the compositor to take control of window resize (Wayland and X11), when the window is resizable.
     */
    public function startWindowResize(edge:ResizeEdge):Void {
        if (_isResizable) {
            // The operating system resizes the window through the hit regions
            // (see CeramicWindowOperations)
            if (platformOperations != null) platformOperations.startWindowResize(edge);
        }
    }

    /**
     * Opens the native title bar context menu, useful when implementing client side decorations (Wayland and X11)
     */
    public function showWindowMenu(position:Point):Void {
        if (platformOperations != null) platformOperations.showWindowMenu(position);
    }

    /**
     * Performs the system action of a title bar double click (macOS).
     */
    public function titlebarDoubleClick():Void {
        if (platformOperations != null) platformOperations.titlebarDoubleClick(_isResizable, _isMinimizable);
    }

    /**
     * Close this window at the end of the current update (GPUI sets
     * `removed` and the app closes it once the update returns).
     */
    public function removeWindow():Void {
        if (_removed) return;
        _removed = true;
        app.defer(_ -> destroy());
    }

    /**
     * Returns a conservative rectangle avoiding platform-known obscured
     * content. Ceramic reports no system insets nor visual viewport, so it
     * is the whole viewport.
     */
    public function fullyVisibleBounds():Bounds {
        return new Bounds(new Point(0., 0.), viewportSize());
    }

    /**
     * Records the hitbox of an element acting as a window control area
     * (Rust `insert_window_control_hitbox`).
     */
    public function insertWindowControlHitbox(area:WindowControlArea, hitbox:Hitbox):Void {
        nextFrame.windowControlHitboxes.push(new WindowControlHitbox(area, hitbox));
    }

    /**
     * The window control areas of the last drawn frame.
     */
    public inline function windowControlHitboxes():Array<WindowControlHitbox> {
        return renderedFrame.windowControlHitboxes;
    }

    /**
     * Returns whether the mouse cursor is over this window.
     */
    public inline function isWindowHovered():Bool {
        return hovered;
    }

    /**
     * Updates the cursor style at the platform level. This method should only be called
     * during the paint phase of element drawing.
     */
    public function setCursorStyle(style:CursorStyle, hitbox:Hitbox):Void {
        nextFrame.cursorStyles.push(new CursorStyleRequest(hitbox.id, style));
    }

    /**
     * Updates the cursor style for the entire window at the platform level. A cursor
     * style using this method will have precedence over any cursor style set using
     * `setCursorStyle`.
     */
    public function setWindowCursorStyle(style:CursorStyle):Void {
        nextFrame.cursorStyles.push(new CursorStyleRequest(-1, style));
    }

    /**
     * The cursor style of the last frame for the current mouse position.
     */
    public inline function cursorStyle():CursorStyle {
        return currentCursorStyle;
    }

    @:allow(glaze)
    function resetCursorStyle():Void {
        final style = renderedFrame.cursorStyle(this);
        currentCursorStyle = style != null ? style : Arrow;
        // Set the cursor only if we're the hovered window.
        if (hovered) {
            GlazeInput.setCursor(currentCursorStyle);
        }
    }

    /**
     * Sets a tooltip to be rendered for the upcoming frame. This method should only be called
     * during the paint phase of element drawing.
     */
    public function setTooltip(tooltip:AnyTooltip):Int {
        final id = nextTooltipId++;
        nextFrame.tooltipRequests.push(new TooltipRequest(id, tooltip));
        return id;
    }

    /**
     * Checks if the tooltip with the given id is currently hovered (Rust `TooltipId::is_hovered`).
     */
    public function isTooltipHovered(tooltipId:Int):Bool {
        return tooltipBounds != null && tooltipBounds.id == tooltipId && tooltipBounds.bounds.contains(_mousePosition);
    }

    /**
     * Request that the given bounds be scrolled into view by the nearest scrollable ancestor.
     */
    public function requestAutoscroll(bounds:Bounds):Void {
        requestedAutoscroll = bounds;
    }

    /**
     * Take the requested autoscroll bounds, if any.
     */
    public function takeAutoscroll():Null<Bounds> {
        final bounds = requestedAutoscroll;
        requestedAutoscroll = null;
        return bounds;
    }

/// Listeners (paint phase)

    /**
     * Register a mouse event listener on the window for the next frame. The type of event
     * is given by `kind`. When the next frame is rendered the listener will be cleared.
     *
     * This is a fairly low-level method, so prefer using event handlers on elements unless you have
     * a specific need to register a global listener.
     */
    public function onMouseEvent(kind:PlatformInputKind, listener:(PlatformInput, DispatchPhase, Window, App) -> Void):Void {
        nextFrame.mouseListeners.push(new MouseListenerEntry(kind, listener, null, null));
    }

    /** Registers a mouse listener entry for the next frame (internal) */
    @:allow(glaze)
    function addMouseListenerEntry(entry:MouseListenerEntry):Void {
        nextFrame.mouseListeners.push(entry);
    }

    /**
     * The hover listener of an element (see `Interactivity.paintMouseListeners`),
     * without a closure. `paintedHovered`: -1 when not tracked, else 0 or 1.
     */
    @:allow(glaze)
    function onElementHover(hitbox:Hitbox, hoverState:Null<Interactivity.ElementHoverState>, currentView:Int, paintedHovered:Int):Void {
        nextFrame.mouseListeners.push(new HoverListenerEntry(hitbox, hoverState, currentView, paintedHovered));
    }

    /**
     * Like `onMouseEvent()`, for a listener of an element called with its
     * hitbox (the same as registering `(e, p, w, cx) -> listener(e, p, hitbox, w, cx)`).
     */
    @:allow(glaze)
    function onElementMouseEvent(kind:PlatformInputKind, listener:Interactivity.ElementMouseListener, hitbox:Hitbox):Void {
        nextFrame.mouseListeners.push(new MouseListenerEntry(kind, null, listener, hitbox));
    }

    /**
     * Register a key event listener on this node for the next frame. The listener gets every
     * keyboard event (key down, key up, modifiers changed): check `event.kind`.
     */
    public function onKeyEvent(listener:(PlatformInput, DispatchPhase, Window, App) -> Void):Void {
        nextFrame.dispatchTree.onKeyEvent(listener);
    }

    /**
     * Register a modifiers changed event listener on the window for the next frame.
     */
    public function onModifiersChanged(listener:(ModifiersChangedEvent, Window, App) -> Void):Void {
        nextFrame.dispatchTree.onModifiersChanged(listener);
    }

    /**
     * Register an action listener on this node for the next frame, for actions of exactly
     * the given class.
     */
    public function onAction(actionType:Class<Dynamic>, listener:(Action, DispatchPhase, Window, App) -> Void):Void {
        nextFrame.dispatchTree.onAction(actionType, listener);
    }

    /** `onAction()` with a listener entry, kept as is (no wrapper per frame) */
    @:allow(glaze)
    function onActionEntry(entry:DispatchTree.DispatchActionListener):Void {
        nextFrame.dispatchTree.onActionEntry(entry);
    }

    /**
     * Sets the key context for the current element. This context will be used to translate
     * keybindings into actions.
     */
    public function setKeyContext(context:KeyContext):Void {
        nextFrame.dispatchTree.setKeyContext(context);
    }

    /**
     * Sets the focus handle for the current element. This handle will be used to manage focus state
     * and keyboard event dispatch for the element.
     *
     * This method should only be called as part of the prepaint phase of element drawing.
     */
    public function setFocusHandle(focusHandle:FocusHandle, cx:App):Void {
        if (focusHandle.isFocused(this)) {
            nextFrame.focus = focusHandle;
        }
        nextFrame.dispatchTree.setFocusId(focusHandle.id);
    }

    /**
     * Sets the view id for the current element.
     */
    public function setViewId(viewId:Int):Void {
        nextFrame.dispatchTree.setViewId(viewId);
    }

    /**
     * Executes the given closure within a tab group of the given index (no group when `null`).
     */
    public function withTabGroup<R>(index:Null<Int>, f:(Window) -> R):R {
        if (index != null) {
            nextFrame.tabStops.beginGroup(index);
            final result = f(this);
            nextFrame.tabStops.endGroup();
            return result;
        }
        return f(this);
    }

    /**
     * Inserts the given focus handle in the tab order of the next frame.
     */
    public function insertTabStop(focusHandle:FocusHandle):Void {
        nextFrame.tabStops.insert(focusHandle);
    }

    /**
     * The focus handle of the next frame, when an element painted so far is focused.
     */
    @:allow(glaze)
    inline function nextFrameFocus():Null<FocusHandle> {
        return nextFrame.focus;
    }

    @:allow(glaze)
    inline function nextFrameDispatchTree():DispatchTree {
        return nextFrame.dispatchTree;
    }

/// Focus

    /**
     * Obtain the currently focused `FocusHandle`. If no elements are focused, returns `null`.
     */
    public inline function focused(?cx:App):Null<FocusHandle> {
        return _focus;
    }

    /**
     * The id of the focused handle, -1 if nothing is focused.
     */
    public inline function focusId():Int {
        return _focus != null ? _focus.id : -1;
    }

    /**
     * Whether the focus handle `parent` contains `child` (or is `child`) in the most recently
     * rendered frame (Rust `FocusId::contains`).
     */
    public function focusContains(parent:Int, child:Int):Bool {
        return renderedFrame.dispatchTree.focusContains(parent, child);
    }

    /**
     * Move focus to the element associated with the given `FocusHandle`.
     */
    public function focus(handle:FocusHandle, ?cx:App):Void {
        if (!focusEnabled || (_focus != null && _focus.id == handle.id)) {
            return;
        }

        _focus = handle;
        focusGeneration++;
        clearPendingKeystrokes();

        refresh();
    }

    /**
     * Remove focus from all elements within this context's window.
     */
    public function blur(?cx:App):Void {
        clearPendingKeystrokes();

        if (!focusEnabled) {
            return;
        }

        if (_focus != null) {
            focusGeneration++;
        }
        _focus = null;
        refresh();
    }

    /**
     * Blur the window and don't allow anything in it to be focused again.
     */
    public function disableFocus(?cx:App):Void {
        blur(cx);
        focusEnabled = false;
    }

    /**
     * Move focus to next tab stop.
     */
    public function focusNext(?cx:App):Void {
        if (!focusEnabled) {
            return;
        }

        final handle = renderedFrame.tabStops.next(focusId());
        if (handle != null) {
            focus(handle, cx);
        }
    }

    /**
     * Move focus to previous tab stop.
     */
    public function focusPrev(?cx:App):Void {
        if (!focusEnabled) {
            return;
        }

        final handle = renderedFrame.tabStops.prev(focusId());
        if (handle != null) {
            focus(handle, cx);
        }
    }

    /**
     * While focus-lost listeners are being dispatched, returns the closest ancestor of the
     * previously focused element that can still receive focus. Returns `null` at all other times.
     * Handles are not kept by id here: it returns the focus id, or -1.
     */
    public function focusLostRestoreTargetId():Int {
        if (focusLostPath.length == 0)
            return -1;
        var i = focusLostPath.length - 2;
        while (i >= 0) {
            final id = focusLostPath[i];
            if (renderedFrame.dispatchTree.focusableNodeId(id) != -1) {
                return id;
            }
            i--;
        }
        return -1;
    }

    /**
     * Registers a focus listener (called after each frame whose focus path changed).
     * Returns the subscription and the function activating it.
     */
    @:allow(glaze)
    function newFocusListener(listener:(WindowFocusEvent, Window, App) -> Bool):{subscription:Subscription, activate:() -> Void} {
        final subscriber = focusListeners.insert(0, listener);
        return {subscription: subscriber.subscription, activate: subscriber.activate};
    }

    /**
     * Registers a callback called when the bounds of the window change
     * (Rust `window.bounds_observers.insert`).
     */
    @:allow(glaze)
    function newBoundsObserver(callback:(Window, App) -> Bool):{subscription:Subscription, activate:() -> Void} {
        final subscriber = boundsObservers.insert(0, callback);
        return {subscription: subscriber.subscription, activate: subscriber.activate};
    }

    /**
     * Registers a callback called when the window is activated or deactivated
     * (Rust `window.activation_observers.insert`).
     */
    @:allow(glaze)
    function newActivationObserver(callback:(Window, App) -> Bool):{subscription:Subscription, activate:() -> Void} {
        final subscriber = activationObservers.insert(0, callback);
        return {subscription: subscriber.subscription, activate: subscriber.activate};
    }

    /**
     * Registers a listener called when the focus is lost (the focus path becomes empty).
     */
    @:allow(glaze)
    function newFocusLostListener(listener:(Window, App) -> Bool):{subscription:Subscription, activate:() -> Void} {
        final subscriber = focusLostListeners.insert(0, listener);
        return {subscription: subscriber.subscription, activate: subscriber.activate};
    }

    /**
     * Register a listener to be called when the given focus handle or one of its descendants receives focus.
     * This does not fire if the given focus handle - or one of its descendants - was previously focused.
     */
    public function onFocusIn(handle:FocusHandle, cx:App, listener:(Window, App) -> Void):Subscription {
        final focusId = handle.id;
        final result = newFocusListener((event, window, cx) -> {
            if (event.isFocusIn(focusId)) {
                listener(window, cx);
            }
            return true;
        });
        cx.defer(_ -> result.activate());
        return result.subscription;
    }

    /**
     * Register a listener to be called when the given focus handle or one of its descendants loses focus.
     */
    public function onFocusOut(handle:FocusHandle, cx:App, listener:(FocusOutEvent, Window, App) -> Void):Subscription {
        final focusId = handle.id;
        final result = newFocusListener((event, window, cx) -> {
            final blurredId = event.previousLast();
            if (blurredId != -1 && event.isFocusOut(focusId)) {
                listener(new FocusOutEvent(blurredId), window, cx);
            }
            return true;
        });
        cx.defer(_ -> result.activate());
        return result.subscription;
    }

    /**
     * Register a callback called when the pending input (multi-stroke keystrokes) changes.
     */
    public function observePendingInput(cx:App, callback:(Window, App) -> Void):Subscription {
        final subscriber = pendingInputObservers.insert(0, (window, cx) -> {
            callback(window, cx);
            return true;
        });
        subscriber.activate();
        return subscriber.subscription;
    }

/// Text input

    /**
     * Sets an input handler, such as `ElementInputHandler`, which interfaces with the
     * platform to receive textual input with proper integration with concerns such
     * as IME interactions. This handler will be active for the upcoming frame until
     * the following frame is rendered. Only registered when `focusHandle` is focused.
     *
     * This method should only be called as part of the paint phase of element drawing.
     */
    public function handleInput(focusHandle:FocusHandle, inputHandler:InputHandler, ?cx:App):Void {
        if (cx == null) cx = app;
        // Port addition: where text inputs are, so that a platform which can
        // only show its virtual keyboard from inside the tap that asks for it
        // (the web) can tell, before the tap reaches GPUI, whether it lands
        // on a text input. GPUI's web platform dispatches the tap first, then
        // checks the focused input's bounds (events.rs:357-370).
        final elementBounds = inputHandler.elementBounds(this, cx);
        if (elementBounds != null) {
            final visible = elementBounds.intersect(contentMask().bounds);
            if (visible.size.width > 0 && visible.size.height > 0) {
                nextFrame.textInputRegions.push(new TextInputRegion(visible, inputHandler));
            }
        }
        if (focusHandle.isFocused(this)) {
            nextFrame.inputHandlers.push(new PlatformInputHandler(this, cx, inputHandler).withFocus(focusHandle.id));
        }
    }

    /**
     * The topmost text input painted in the last frame whose visible bounds
     * contain `position` (window coordinates), if it accepts text input
     * (port addition: lets the web platform decide, inside the tap that
     * focuses an input, whether to open the virtual keyboard).
     */
    public function textInputRegionAt(position:Point, ?cx:App):Null<TextInputRegion> {
        if (cx == null) cx = app;
        final regions = renderedFrame.textInputRegions;
        var i = regions.length - 1;
        while (i >= 0) {
            final region = regions[i];
            if (region.bounds.contains(position)) {
                return region.handler.acceptsTextInput(this, cx) ? region : null;
            }
            i--;
        }
        return null;
    }

    /**
     * Takes the input handler registered by the last frame, if any (Rust
     * `PlatformWindow::take_input_handler`). Give it back with `setInputHandler()`.
     */
    public function takeInputHandler():Null<PlatformInputHandler> {
        final inputHandler = platformInputHandler;
        platformInputHandler = null;
        return inputHandler;
    }

    /**
     * The input handler registered by the last frame, without taking it.
     */
    public inline function peekInputHandler():Null<PlatformInputHandler> {
        return platformInputHandler;
    }

    /**
     * Gives an input handler (back) to the platform slot (Rust
     * `PlatformWindow::set_input_handler`).
     */
    public function setInputHandler(inputHandler:PlatformInputHandler):Void {
        platformInputHandler = inputHandler;
    }

    /**
     * Notifies native text services that the focused component's text changed.
     *
     * Text components should call this after application-driven edits, in addition
     * to notifying GPUI to redraw. Unfocused or unregistered components are ignored.
     */
    public function notifyTextInputChanged(focusHandle:FocusHandle):Void {
        if (focusedTextInput == focusHandle.id && focusHandle.isFocused(this) && textInputPlatform != null) {
            textInputPlatform.textInputStateChanged(ContentChanged);
        }
    }

    /**
     * Notifies native text services that the focused component's selection changed.
     *
     * Text components should call this after application-driven selection changes,
     * in addition to notifying GPUI to redraw.
     */
    public function notifyTextSelectionChanged(focusHandle:FocusHandle):Void {
        if (focusedTextInput == focusHandle.id && focusHandle.isFocused(this) && textInputPlatform != null) {
            textInputPlatform.textInputStateChanged(SelectionChanged);
        }
    }

    /**
     * Forwards the focused input handler's `TextInputConfiguration` to the platform
     * when it differs from the last forwarded value. With no input handler the
     * default configuration applies, so a field's preferences don't outlive its focus.
     */
    function applyTextInputConfiguration(cx:App):Void {
        final inputHandler = takeInputHandler();
        var configuration:TextInputConfiguration;
        if (inputHandler != null) {
            configuration = inputHandler.textInputConfiguration(this, cx);
            setInputHandler(inputHandler);
        }
        else {
            configuration = TextInputConfiguration.defaultValue();
        }
        if (lastTextInputConfiguration == null || !lastTextInputConfiguration.equals(configuration)) {
            if (textInputPlatform != null) {
                textInputPlatform.setTextInputConfiguration(configuration);
            }
            lastTextInputConfiguration = configuration;
        }
    }

    /**
     * Whether the focused element registered an input handler accepting text input
     * at the last draw (the platform text input session is active).
     */
    public inline function hasFocusedTextInput():Bool {
        return focusedTextInput != -1;
    }

    /**
     * Updates the IME panel position suggestions for languages like japanese, chinese.
     */
    public function invalidateCharacterCoordinates():Void {
        onNextFrame((window, cx) -> {
            final inputHandler = window.takeInputHandler();
            if (inputHandler != null) {
                final bounds = inputHandler.selectedBounds(window, cx);
                if (bounds != null && window.textInputPlatform != null) {
                    window.textInputPlatform.updateImePosition(bounds);
                }
                window.setInputHandler(inputHandler);
            }
        });
    }

    /**
     * Requests the software keyboard (no-op: Ceramic's native backends show
     * it with text editing, and on the web the tap that focuses a text input
     * opens it from inside the browser's touch handler, see `GlazeInput`).
     */
    public function requestVirtualKeyboard():Void {}

    /**
     * Shows the system character palette (no-op on Ceramic).
     */
    public function showCharacterPalette():Void {}

    /**
     * Plays the system bell (no-op on Ceramic).
     */
    public function playSystemBell():Void {}

/// Event dispatch

    /**
     * Dispatch a mouse or keyboard event on the window (Rust `dispatch_event`). Runs inside an
     * app update with tracker capture disabled: handlers never subscribe a view.
     */
    public function dispatchEvent(event:PlatformInput, ?cx:App):DispatchEventResult {
        if (cx == null) cx = app;
        cx.startUpdate();
        tracker.Autorun.unobserve();
        var result:DispatchEventResult;
        try {
            result = dispatchEventInner(event, cx);
        }
        catch (e:haxe.Exception) {
            tracker.Autorun.reobserve();
            @:privateAccess cx.pendingUpdates--;
            throw glaze.util.Exceptions.rethrow(e);
        }
        tracker.Autorun.reobserve();
        cx.finishUpdate();
        return result;
    }

    function dispatchEventInner(event:PlatformInput, cx:App):DispatchEventResult {
        // Track input modality for focus-visible styling and hover suppression.
        // Hover is suppressed during keyboard modality so that keyboard navigation
        // doesn't show hover highlights on the item under the mouse cursor.
        final oldModality = lastInputModality;
        switch event.kind {
            case KeyDown: lastInputModality = Keyboard;
            case MouseMove | MouseDown: lastInputModality = Mouse;
            case Touch: lastInputModality = Touch;
            case _:
        }
        if (lastInputModality != oldModality) {
            refresh();
        }

        // Handlers may set this to false by calling `stopPropagation`.
        cx.propagateEvent = true;
        // Handlers may set this to true by calling `preventDefault`.
        _defaultPrevented = false;

        switch event.kind {
            case MouseMove:
                final e:MouseMoveEvent = cast event;
                _mousePosition = e.position;
                _modifiers = e.modifiers;
            case MouseDown:
                final e:MouseDownEvent = cast event;
                _mousePosition = e.position;
                _modifiers = e.modifiers;
            case MouseUp:
                final e:MouseUpEvent = cast event;
                _mousePosition = e.position;
                _modifiers = e.modifiers;
            case MouseExited:
                final e:MouseExitEvent = cast event;
                _modifiers = e.modifiers;
            case ModifiersChanged:
                final e:ModifiersChangedEvent = cast event;
                _modifiers = e.modifiers;
                _capslock = e.capslock;
            case Scroll:
                final e:ScrollEvent = cast event;
                _mousePosition = e.position;
                _modifiers = e.modifiers;
            case Touch:
            case LongPress:
                final e:LongPressEvent = cast event;
                _mousePosition = e.phase == Started ? e.startPosition : e.position;
                if (e.phase == Started) {
                    longPressCapture = -1;
                }
            case TouchDrag:
                final e:TouchDragEvent = cast event;
                _mousePosition = e.startPosition;
            case KeyDown | KeyUp:
        }

        if (event.kind.isMouseEvent()) {
            dispatchMouseEvent(event, cx);
        }
        else if (event.kind == Touch) {
            dispatchTouchEvent(cast event, cx);
        }
        else {
            dispatchKeyEvent(event, cx);
        }
        if (event.kind == LongPress) {
            final e:LongPressEvent = cast event;
            switch e.phase {
                case Started if (!_defaultPrevented):
                    longPressCapture = -1;
                case Ended | Cancelled:
                    longPressCapture = -1;
                case _:
            }
        }

        return new DispatchEventResult(cx.propagateEvent, _defaultPrevented);
    }

    /**
     * Whether recognized touch pans may use the platform's predicted touch
     * positions (`TouchEvent.predictedPosition`) to compensate for input
     * latency. Defaults to true.
     */
    public inline function touchPredictionEnabled():Bool {
        return _touchPredictionEnabled;
    }

    /**
     * Sets whether recognized touch pans may use the platform's predicted
     * touch positions. Disabling drops `TouchEvent.predictedPosition` before
     * gesture recognition, so pans track only raw touch positions.
     */
    public function setTouchPredictionEnabled(enabled:Bool):Void {
        _touchPredictionEnabled = enabled;
    }

    /**
     * Routes the rest of the current long press to the given entity: call it
     * from a `LongPressEvent` listener of the started phase that claims the
     * gesture. The capture is released when the gesture ends or is
     * cancelled, or when a replacement touch begins. A listener must also
     * call `preventDefault` on the started event to claim the gesture.
     */
    public function captureLongPress<T:Model>(entity:Entity<T>):Void {
        longPressCapture = entity.entityId();
    }

    /**
     * Whether the given entity captured the current long press.
     */
    public function hasLongPressCapture<T:Model>(entity:Entity<T>):Bool {
        return longPressCapture != -1 && longPressCapture == entity.entityId();
    }

    /**
     * Runs the portable gesture recognizer over a raw touch event and
     * dispatches whatever it resolves (scroll steps, synthesized taps)
     * through the ordinary mouse-event path (Rust `dispatch_touch_event`).
     */
    function dispatchTouchEvent(event:TouchEvent, cx:App):Void {
        event = event.copy();
        if (!_touchPredictionEnabled) {
            event.predictedPosition = null;
        }
        final now = cx.backgroundExecutor().now();
        final recognizedGestures = touchGestures.handleEvent(event, now);
        if (event.phase == Started) {
            final touchDrag = touchGestures.offerTouchDrag(event.id);
            if (touchDrag != null) {
                dispatchRecognizedTouchGesture(touchDrag, cx);
            }
        }
        if (event.phase == Started && touchGestures.pendingLongPress(now) != null) {
            longPressCapture = -1;
        }
        var tapped = false;
        for (gesture in recognizedGestures) {
            if (gesture.match(Tap(_, _))) tapped = true;
            dispatchRecognizedTouchGesture(gesture, cx);
        }
        if (event.phase == Started) {
            scheduleLongPressTimer(cx);
        }
        else if (touchGestures.pendingLongPress(cx.backgroundExecutor().now()) == null) {
            cancelLongPressTimer();
        }
        // The platform's touch-release handler may inspect the input handler
        // as soon as this dispatch returns (the web platform decides virtual
        // keyboard visibility there, inside the user gesture). Input handlers
        // are registered during draw, so draw now to make them reflect any
        // focus change the tap just caused.
        if (tapped && dirty) {
            draw();
        }
        if (touchGestures.hasMomentum()) {
            scheduleTouchMomentumTick();
        }
    }

    function dispatchRecognizedTouchGesture(gesture:RecognizedTouchGesture, cx:App):Void {
        switch gesture {
            case Scroll(scroll):
                _mousePosition = scroll.position;
                cx.propagateEvent = true;
                dispatchMouseEvent(scroll, cx);
            case Tap(down, up):
                _mousePosition = up.position;
                cx.propagateEvent = true;
                dispatchMouseEvent(down, cx);
                cx.propagateEvent = true;
                dispatchMouseEvent(up, cx);
            case TouchDrag(touchDrag):
                _mousePosition = touchDrag.startPosition;
                cx.propagateEvent = true;
                _defaultPrevented = false;
                final started = touchDrag.phase == Started;
                dispatchMouseEvent(touchDrag, cx);
                if (started) {
                    touchGestures.resolveTouchDrag(_defaultPrevented);
                }
            case LongPress(longPress):
                _mousePosition = longPress.phase == Started ? longPress.startPosition : longPress.position;
                cx.propagateEvent = true;
                _defaultPrevented = false;
                final started = longPress.phase == Started;
                final ended = longPress.phase == Ended || longPress.phase == Cancelled;
                dispatchMouseEvent(longPress, cx);
                if (started) {
                    final claimed = _defaultPrevented;
                    touchGestures.resolveLongPress(claimed);
                    if (!claimed) {
                        longPressCapture = -1;
                    }
                }
                if (ended) {
                    longPressCapture = -1;
                }
        }
    }

    /**
     * Dispatches a gesture recognized outside of `dispatchEvent` (the long
     * press timer, a momentum frame): handlers never subscribe a view, like
     * in `dispatchEvent`.
     */
    function dispatchRecognizedTouchGestureLater(gesture:RecognizedTouchGesture, cx:App):Void {
        if (destroyed)
            return;
        tracker.Autorun.unobserve();
        try {
            dispatchRecognizedTouchGesture(gesture, cx);
        }
        catch (e:haxe.Exception) {
            tracker.Autorun.reobserve();
            throw glaze.util.Exceptions.rethrow(e);
        }
        tracker.Autorun.reobserve();
    }

    function cancelLongPressTimer():Void {
        final timer = longPressTimer;
        longPressTimer = null;
        if (timer != null) timer.cancel();
    }

    function scheduleLongPressTimer(cx:App):Void {
        cancelLongPressTimer();
        final pending = touchGestures.pendingLongPress(cx.backgroundExecutor().now());
        if (pending == null)
            return;
        final touchId = pending.id;
        final timer = cx.backgroundExecutor().timer(pending.remaining);
        final task = timer.then(_ -> {
            if (destroyed)
                return;
            cx.update(cx -> {
                longPressTimer = null;
                final gesture = touchGestures.offerLongPress(touchId);
                if (gesture != null) {
                    dispatchRecognizedTouchGestureLater(gesture, cx);
                }
            });
        });
        longPressTimer = task;
    }

    function scheduleTouchMomentumTick():Void {
        onNextFrame((window, cx) -> {
            final gesture = touchGestures.tickMomentum(cx.backgroundExecutor().now());
            if (gesture != null) {
                dispatchRecognizedTouchGestureLater(gesture, cx);
            }
            if (touchGestures.hasMomentum()) {
                scheduleTouchMomentumTick();
            }
        });
    }

    function dispatchMouseEvent(event:PlatformInput, cx:App):Void {
        final hitTest = renderedFrame.hitTest(_mousePosition);
        if (!hitTest.equals(mouseHitTest)) {
            if (event.kind != MouseMove && viewCaching && !drawing) {
                // Hover is painted from the hit test, and only mouse moves
                // notify the views whose hover changed: after another event
                // moved the mouse, the next frame (whenever it is drawn)
                // renders every view, like uncached views would be.
                refreshing = true;
            }
            mouseHitTest = hitTest;
            resetCursorStyle();
        }

        #if glaze_inspector
        if (isInspectorPicking(cx)) {
            handleInspectorMouseEvent(event, cx);
            // When inspector is picking, all other mouse handling is skipped.
            return;
        }
        #end

        final mouseListeners = renderedFrame.mouseListeners.copy();
        final kind = event.kind;

        // Capture phase, events bubble from back to front. Handlers for this phase are used for
        // special purposes, such as detecting events outside of a given Bounds.
        for (entry in mouseListeners) {
            if (entry.kind != kind)
                continue;
            entry.call(event, Capture, this, cx);
            if (!cx.propagateEvent) {
                break;
            }
        }

        // Bubble phase, where most normal handlers do their work.
        if (cx.propagateEvent) {
            var i = mouseListeners.length - 1;
            while (i >= 0) {
                final entry = mouseListeners[i];
                i--;
                if (entry.kind != kind)
                    continue;
                entry.call(event, Bubble, this, cx);
                if (!cx.propagateEvent) {
                    break;
                }
            }
        }

        if (cx.hasActiveDrag()) {
            if (kind == MouseMove) {
                // If this was a mouse move event, redraw the window so that the
                // active drag can follow the mouse cursor.
                refresh();
            }
            else if (kind == MouseUp) {
                // If this was a mouse up event, cancel the active drag and redraw
                // the window.
                cx.activeDrag = null;
                refresh();
            }
        }

        // Auto-release pointer capture on mouse up
        if (kind == MouseUp && _capturedHitbox != -1) {
            _capturedHitbox = -1;
        }
    }

    function dispatchKeyEvent(event:PlatformInput, cx:App):Void {
        if (dirty) {
            draw();
        }

        final nodeId = focusNodeIdInRenderedFrame(focusId());
        final dispatchPath = renderedFrame.dispatchTree.dispatchPath(nodeId);

        var keystroke:Null<Keystroke> = null;

        if (event.kind == ModifiersChanged) {
            final e:ModifiersChangedEvent = cast event;
            if (e.modifiers.numberOfModifiers() == 0
                && pendingModifierModifiers.numberOfModifiers() == 1
                && !pendingModifierSawOtherInput) {
                final m = pendingModifierModifiers;
                final key = m.shift ? 'shift' : m.control ? 'control' : m.alt ? 'alt' : m.platform ? 'platform' : m.function_ ? 'function' : null;
                if (key != null) {
                    keystroke = new Keystroke(Modifiers.none(), key, null);
                }
            }

            if (pendingModifierModifiers.numberOfModifiers() == 0 && e.modifiers.numberOfModifiers() == 1) {
                pendingModifierSawOtherInput = false;
            }
            else if (e.modifiers.numberOfModifiers() > 1) {
                pendingModifierSawOtherInput = true;
            }
            pendingModifierModifiers = e.modifiers;
        }
        else if (event.kind == KeyDown) {
            final e:KeyDownEvent = cast event;
            pendingModifierSawOtherInput = true;
            keystroke = e.keystroke;
        }

        if (keystroke == null) {
            finishDispatchKeyEvent(event, null, KeyBindings, dispatchPath, contextStack(), cx);
            return;
        }

        var inputPreference = this.inputPreference(event, cx);

        cx.propagateEvent = true;
        cx.dispatchKeystrokeInterceptors(keystroke, inputPreference, contextStack(), this);
        if (!cx.propagateEvent) {
            finishDispatchKeyEvent(event, keystroke, inputPreference, dispatchPath, contextStack(), cx);
            return;
        }

        var currentlyPending = pendingInput;
        pendingInput = null;
        if (currentlyPending == null) {
            currentlyPending = new PendingInput();
        }
        if (currentlyPending.focus != -1 && currentlyPending.focus != focusId()) {
            if (currentlyPending.timeout != null) currentlyPending.timeout.drop();
            currentlyPending = new PendingInput();
        }

        final matchResult = renderedFrame.dispatchTree.dispatchKey(currentlyPending.keystrokes, keystroke, dispatchPath);

        if (matchResult.toReplay.length > 0) {
            replayPendingInput(matchResult.toReplay, cx);
            cx.propagateEvent = true;
        }

        if (matchResult.pending.length > 0) {
            final previousTimeout = currentlyPending.timeout;
            currentlyPending.timeout = null;
            currentlyPending.keystrokes = matchResult.pending;
            currentlyPending.focus = focusId();

            var textInputRequiresTimeout = false;
            if (event.kind == KeyDown && (cast event : KeyDownEvent).keystroke.keyChar != null) {
                final inputHandler = takeInputHandler();
                if (inputHandler != null) {
                    textInputRequiresTimeout = inputHandler.acceptsTextInput(this, cx);
                    setInputHandler(inputHandler);
                }
            }

            final needsTimeout = previousTimeout != null || matchResult.pendingHasBinding || textInputRequiresTimeout;
            if (needsTimeout) {
                if (previousTimeout != null && previousTimeout.isPaused()) {
                    previousTimeout.resetDuration(PENDING_INPUT_TIMEOUT);
                    currentlyPending.timeout = previousTimeout;
                }
                else {
                    if (previousTimeout != null) previousTimeout.drop();
                    currentlyPending.timeout = newPendingInputTimeout(PENDING_INPUT_TIMEOUT, cx);
                }
            }
            else {
                currentlyPending.timeout = null;
            }
            pendingInput = currentlyPending;
            pendingInputChanged(cx);
            cx.propagateEvent = false;
            return;
        }
        else if (currentlyPending.timeout != null) {
            currentlyPending.timeout.drop();
        }

        // Interceptors or replayed actions may have changed whether the input handler accepts text.
        inputPreference = this.inputPreference(event, cx);
        if (inputPreference == KeyBindings) {
            for (binding in matchResult.bindings) {
                dispatchActionOnNode(nodeId, binding.action, cx);
                if (!cx.propagateEvent) {
                    cx.dispatchKeystrokeObservers(keystroke, inputPreference, binding.action, matchResult.contextStack, this);
                    pendingInputChanged(cx);
                    return;
                }
            }
        }

        finishDispatchKeyEvent(event, keystroke, inputPreference, dispatchPath, matchResult.contextStack, cx);
        pendingInputChanged(cx);
    }

    /**
     * If modifiers are not excessive (e.g. AltGr), and the input handler is accepting
     * text input, we prefer the text input over bindings.
     */
    function inputPreference(event:PlatformInput, cx:App):InputPreference {
        final preferCharacterInput = event.kind == KeyDown && (cast event : KeyDownEvent).preferCharacterInput;
        if (!preferCharacterInput) {
            return KeyBindings;
        }
        final inputHandler = takeInputHandler();
        if (inputHandler == null) {
            return KeyBindings;
        }
        final acceptsTextInput = inputHandler.acceptsTextInput(this, cx);
        setInputHandler(inputHandler);
        return acceptsTextInput ? CharacterInput : KeyBindings;
    }

    /** Duration after which pending input is replayed, in seconds (Rust `PENDING_INPUT_TIMEOUT`, 1s) */
    public static inline final PENDING_INPUT_TIMEOUT:Float = 1.0;

    function newPendingInputTimeout(duration:Float, cx:App):PendingInputTimeout {
        final timeout = new PendingInputTimeout(duration);
        timeout.startedAt = cx.backgroundExecutor().now();
        timeout.task = startPendingInputTimeout(duration, cx);
        return timeout;
    }

    function startPendingInputTimeout(remaining:Float, cx:App):AnyTask {
        final timer = cx.backgroundExecutor().timer(remaining);
        timer.then(_ -> {
            if (destroyed)
                return;
            cx.update(cx -> {
                final currentlyPending = pendingInput;
                if (currentlyPending == null || currentlyPending.focus != focusId()) {
                    return;
                }
                pendingInput = null;

                final nodeId = focusNodeIdInRenderedFrame(focusId());
                final dispatchPath = renderedFrame.dispatchTree.dispatchPath(nodeId);

                final toReplay = renderedFrame.dispatchTree.flushDispatch(currentlyPending.keystrokes, dispatchPath);

                pendingInputChanged(cx);
                replayPendingInput(toReplay, cx);
            });
        });
        return timer;
    }

    function finishDispatchKeyEvent(event:PlatformInput, recognizedKeystroke:Null<Keystroke>, inputPreference:InputPreference, dispatchPath:Array<Int>, contextStack:Array<KeyContext>, cx:App):Void {
        dispatchKeyDownUpEvent(event, dispatchPath, cx);
        if (!cx.propagateEvent) {
            return;
        }

        dispatchModifiersChangedEvent(event, dispatchPath, cx);
        if (!cx.propagateEvent) {
            return;
        }

        if (recognizedKeystroke != null) {
            cx.dispatchKeystrokeObservers(recognizedKeystroke, inputPreference, null, contextStack, this);
        }
    }

    @:allow(glaze)
    function pendingInputChanged(cx:App):Void {
        pendingInputObservers.retain(0, callback -> callback(this, cx));
    }

    function deferPendingInputChanged(cx:App):Void {
        // Avoid re-entrant entity updates by deferring observer notifications to the end of the
        // current effect cycle, and only for this window.
        cx.defer(cx -> {
            if (!destroyed) pendingInputChanged(cx);
        });
    }

    function dispatchKeyDownUpEvent(event:PlatformInput, dispatchPath:Array<Int>, cx:App):Void {
        final tree = renderedFrame.dispatchTree;
        // Capture phase
        for (nodeId in dispatchPath) {
            final listeners = tree.node(nodeId).keyListeners.copy();
            for (keyListener in listeners) {
                keyListener(event, Capture, this, cx);
                if (!cx.propagateEvent) {
                    return;
                }
            }
        }

        // Bubble phase
        var i = dispatchPath.length - 1;
        while (i >= 0) {
            // Handle low level key events
            final listeners = tree.node(dispatchPath[i]).keyListeners.copy();
            i--;
            for (keyListener in listeners) {
                keyListener(event, Bubble, this, cx);
                if (!cx.propagateEvent) {
                    return;
                }
            }
        }
    }

    function dispatchModifiersChangedEvent(event:PlatformInput, dispatchPath:Array<Int>, cx:App):Void {
        if (event.kind != ModifiersChanged)
            return;
        final e:ModifiersChangedEvent = cast event;
        final tree = renderedFrame.dispatchTree;
        var i = dispatchPath.length - 1;
        while (i >= 0) {
            final listeners = tree.node(dispatchPath[i]).modifiersChangedListeners.copy();
            i--;
            for (listener in listeners) {
                listener(e, this, cx);
                if (!cx.propagateEvent) {
                    return;
                }
            }
        }
    }

    /**
     * Dispatch a given keystroke as though the user had typed it.
     * You can create a keystroke with `Keystroke.parse("")`.
     * When no handler consumes it, its character (`keyChar`, filled by
     * `withSimulatedIme`) is inserted through the input handler, if any.
     * Returns `true` if the keystroke was handled.
     */
    public function dispatchKeystroke(keystroke:Keystroke, ?cx:App):Bool {
        if (cx == null) cx = app;
        final keystroke = keystroke.withSimulatedIme();
        final result = dispatchEvent(new KeyDownEvent(keystroke, false, false), cx);
        if (!result.propagate) {
            return true;
        }

        if (keystroke.keyChar != null) {
            final inputHandler = takeInputHandler();
            if (inputHandler != null) {
                final input = keystroke.keyChar;
                cx.update(cx -> inputHandler.dispatchInput(input, this, cx));
                setInputHandler(inputHandler);
                return true;
            }
        }

        return false;
    }

    /**
     * Determine whether a potential multi-stroke key binding is in progress on this window.
     */
    public function hasPendingKeystrokes():Bool {
        return pendingInputKeystrokes() != null;
    }

    /**
     * Returns the currently pending input keystrokes that might result in a multi-stroke key binding.
     * Input left over from a previous focus can never complete one.
     */
    public function pendingInputKeystrokes():Null<Array<Keystroke>> {
        if (pendingInput != null && pendingInput.focus == focusId()) {
            return pendingInput.keystrokes;
        }
        return null;
    }

    /**
     * Whether the pending input timeout is paused (`null` when there is no pending timeout).
     */
    public function isPendingInputTimeoutPaused():Null<Bool> {
        if (pendingInput != null && pendingInput.focus == focusId() && pendingInput.timeout != null) {
            return pendingInput.timeout.isPaused();
        }
        return null;
    }

    /**
     * The full duration of the pending input timeout in seconds (`null` when there is none).
     */
    public function pendingInputTimeoutDuration():Null<Float> {
        if (pendingInput != null && pendingInput.focus == focusId() && pendingInput.timeout != null) {
            return pendingInput.timeout.duration;
        }
        return null;
    }

    /**
     * Whether there is no pending input at all, even left over from a previous focus
     * (Rust test helper `pending_input_is_none`).
     */
    public inline function pendingInputIsNone():Bool {
        return pendingInput == null;
    }

    /**
     * The remaining duration of the pending input timeout in seconds (`null` when there is none).
     */
    public function pendingInputTimeoutRemaining(cx:App):Null<Float> {
        if (pendingInput != null && pendingInput.focus == focusId() && pendingInput.timeout != null) {
            final timeout = pendingInput.timeout;
            if (timeout.isPaused())
                return timeout.remaining;
            return Math.max(0, timeout.remaining - (cx.backgroundExecutor().now() - timeout.startedAt));
        }
        return null;
    }

    @:allow(glaze)
    function clearPendingKeystrokes(?cx:App):Void {
        if (pendingInput != null) {
            if (pendingInput.timeout != null) pendingInput.timeout.drop();
            pendingInput = null;
            deferPendingInputChanged(cx != null ? cx : app);
        }
    }

    function clearPendingInput():Void {
        if (pendingInput != null) {
            if (pendingInput.timeout != null) pendingInput.timeout.drop();
            pendingInput = null;
        }
    }

    /**
     * Pauses or resumes the current pending input timeout on behalf of `owner`.
     * A paused timeout resumes automatically if `owner` is released. Returns whether the timeout
     * state changed. A timeout paused by one owner cannot be resumed by another.
     */
    public function setPendingInputTimeoutPaused<T:Model>(owner:Entity<T>, paused:Bool, cx:App):Bool {
        final ownerId = owner.entityId();
        if (!paused) {
            return resumePendingInputTimeout(ownerId, cx);
        }

        if (pendingInput == null || pendingInput.focus != focusId() || pendingInput.timeout == null) {
            return false;
        }
        final timeout = pendingInput.timeout;
        if (timeout.isPaused()) {
            return false;
        }

        final releaseSubscription = cx.observeRelease(owner, (_, cx) -> {
            if (!destroyed) resumePendingInputTimeout(ownerId, cx);
        });
        final changed = timeout.pause(ownerId, releaseSubscription, cx.backgroundExecutor().now());

        if (changed) {
            deferPendingInputChanged(cx);
        }
        return changed;
    }

    function resumePendingInputTimeout(ownerId:Int, cx:App):Bool {
        if (pendingInput == null || pendingInput.timeout == null || pendingInput.timeout.pauseOwnerId != ownerId) {
            return false;
        }
        final timeout = pendingInput.timeout;
        final startedAt = cx.backgroundExecutor().now();
        final task = startPendingInputTimeout(timeout.remaining, cx);
        final changed = timeout.resume(ownerId, startedAt, task);

        if (changed) {
            deferPendingInputChanged(cx);
        }
        return changed;
    }

    function replayPendingInput(replays:Array<glaze.keymap.Replay>, cx:App):Void {
        final nodeId = focusNodeIdInRenderedFrame(focusId());
        final dispatchPath = renderedFrame.dispatchTree.dispatchPath(nodeId);

        for (replay in replays) {
            final event = new KeyDownEvent(replay.keystroke, false, true);

            cx.propagateEvent = true;
            var handled = false;
            for (binding in replay.bindings) {
                dispatchActionOnNode(nodeId, binding.action, cx);
                if (!cx.propagateEvent) {
                    cx.dispatchKeystrokeObservers(replay.keystroke, KeyBindings, binding.action, [], this);
                    handled = true;
                    break;
                }
            }
            if (handled)
                continue;

            dispatchKeyDownUpEvent(event, dispatchPath, cx);
            if (!cx.propagateEvent)
                continue;
            final input = replay.keystroke.keyChar;
            if (input != null) {
                final inputHandler = takeInputHandler();
                if (inputHandler != null) {
                    inputHandler.dispatchInput(input, this, cx);
                    setInputHandler(inputHandler);
                }
            }
        }
    }

    function focusNodeIdInRenderedFrame(focusId:Int):Int {
        if (focusId != -1) {
            final nodeId = renderedFrame.dispatchTree.focusableNodeId(focusId);
            if (nodeId != -1)
                return nodeId;
        }
        return renderedFrame.dispatchTree.rootNodeId();
    }

    /**
     * Dispatch the given action on the currently focused element, at the end of the current
     * effect cycle.
     */
    public function dispatchAction(action:Action, ?cx:App):Void {
        if (cx == null) cx = app;
        final focusId = this.focusId();
        cx.defer(cx -> {
            if (destroyed)
                return;
            final nodeId = focusNodeIdInRenderedFrame(focusId);
            dispatchActionOnNode(nodeId, action, cx);
        });
    }

    @:allow(glaze)
    function dispatchActionOnFocusHandle(handle:FocusHandle, action:Action, cx:App):Void {
        final nodeId = renderedFrame.dispatchTree.focusableNodeId(handle.id);
        if (nodeId != -1) {
            dispatchActionOnNode(nodeId, action, cx);
        }
    }

    function dispatchActionOnNode(nodeId:Int, action:Action, cx:App):Void {
        final tree = renderedFrame.dispatchTree;
        final dispatchPath = tree.dispatchPath(nodeId);
        final actionType:Class<Dynamic> = Type.getClass(action);

        // Capture phase for global actions.
        cx.propagateEvent = true;
        final globalListeners = cx.globalActionListenersFor(actionType);
        if (globalListeners != null) {
            for (listener in globalListeners) {
                listener(action, Capture, cx);
                if (!cx.propagateEvent) {
                    break;
                }
            }
        }

        if (!cx.propagateEvent) {
            return;
        }

        // Capture phase for window actions.
        for (id in dispatchPath) {
            final listeners = tree.node(id).actionListeners.copy();
            for (entry in listeners) {
                if (entry.actionType == actionType) {
                    entry.call(action, Capture, this, cx);
                    if (!cx.propagateEvent) {
                        return;
                    }
                }
            }
        }

        // Bubble phase for window actions.
        var i = dispatchPath.length - 1;
        while (i >= 0) {
            final listeners = tree.node(dispatchPath[i]).actionListeners.copy();
            i--;
            for (entry in listeners) {
                if (entry.actionType == actionType) {
                    cx.propagateEvent = false; // Actions stop propagation by default during the bubble phase
                    entry.call(action, Bubble, this, cx);
                    if (!cx.propagateEvent) {
                        return;
                    }
                }
            }
        }

        // Bubble phase for global actions.
        final globalListeners = cx.globalActionListenersFor(actionType);
        if (globalListeners != null) {
            var j = globalListeners.length - 1;
            while (j >= 0) {
                cx.propagateEvent = false; // Actions stop propagation by default during the bubble phase
                globalListeners[j](action, Bubble, cx);
                j--;
                if (!cx.propagateEvent) {
                    break;
                }
            }
        }
    }

    /**
     * Determine whether the given action is available along the dispatch path to the currently focused element.
     */
    public function isActionAvailable(action:Action, ?cx:App):Bool {
        final nodeId = focusNodeIdInRenderedFrame(focusId());
        return renderedFrame.dispatchTree.isActionAvailable(action, nodeId);
    }

    /**
     * Determine whether the given action is available along the dispatch path to the given focus handle.
     */
    public function isActionAvailableIn(action:Action, focusHandle:FocusHandle):Bool {
        final nodeId = focusNodeIdInRenderedFrame(focusHandle.id);
        return renderedFrame.dispatchTree.isActionAvailable(action, nodeId);
    }

    /**
     * Returns the key context stack of the focused element, root first.
     */
    public function contextStack():Array<KeyContext> {
        final nodeId = focusNodeIdInRenderedFrame(focusId());
        final tree = renderedFrame.dispatchTree;
        return tree.contextStackForPath(tree.dispatchPath(nodeId));
    }

    /**
     * Returns all available actions for the focused element.
     */
    public function availableActions(cx:App):Array<Action> {
        final nodeId = focusNodeIdInRenderedFrame(focusId());
        return renderedFrame.dispatchTree.availableActions(nodeId, cx.actions);
    }

    /**
     * Returns key bindings that invoke an action on the currently focused element. Bindings are
     * returned in the order they were added. For display, the last binding should take precedence.
     */
    public function bindingsForAction(action:Action):Array<KeyBinding> {
        return renderedFrame.dispatchTree.bindingsForAction(action, renderedFrame.dispatchTree.contextStack);
    }

    /**
     * Returns the highest precedence key binding that invokes an action on the currently focused
     * element.
     */
    public function highestPrecedenceBindingForAction(action:Action):Null<KeyBinding> {
        return renderedFrame.dispatchTree.highestPrecedenceBindingForAction(action, renderedFrame.dispatchTree.contextStack);
    }

    /**
     * Returns the key bindings for an action in a context.
     */
    public function bindingsForActionInContext(action:Action, context:KeyContext):Array<KeyBinding> {
        return renderedFrame.dispatchTree.bindingsForAction(action, [context]);
    }

    /**
     * Returns the key bindings that invoke an action on the given focus handle if it were focused,
     * resolved in the previously rendered frame. Bindings are returned in the order they were added.
     */
    public function bindingsForActionIn(action:Action, focusHandle:FocusHandle):Array<KeyBinding> {
        final contextStack = contextStackForFocusHandle(focusHandle);
        if (contextStack == null)
            return [];
        return renderedFrame.dispatchTree.bindingsForAction(action, contextStack);
    }

    /**
     * Returns the highest precedence key binding that would invoke an action on the given focus
     * handle if it were focused.
     */
    public function highestPrecedenceBindingForActionIn(action:Action, focusHandle:FocusHandle):Null<KeyBinding> {
        final contextStack = contextStackForFocusHandle(focusHandle);
        if (contextStack == null)
            return null;
        return renderedFrame.dispatchTree.highestPrecedenceBindingForAction(action, contextStack);
    }

    function contextStackForFocusHandle(focusHandle:FocusHandle):Null<Array<KeyContext>> {
        final dispatchTree = renderedFrame.dispatchTree;
        final nodeId = dispatchTree.focusableNodeId(focusHandle.id);
        if (nodeId == -1)
            return null;
        return dispatchTree.contextStackForPath(dispatchTree.dispatchPath(nodeId));
    }

    /**
     * Return a key binding string for an action, to display in the UI. Uses the highest precedence
     * binding for the action (last binding added to the keymap).
     */
    public function keystrokeTextFor(action:Action, ?os:OperatingSystem):String {
        final binding = highestPrecedenceBindingForAction(action);
        if (binding == null)
            return action.name();
        if (os == null) os = OperatingSystem.current;
        return [for (keystroke in binding.keystrokes) keystroke.inner().display(os)].join(' ');
    }

/// Frame callbacks

    /**
     * Schedules the given function to be run at the end of the current effect cycle, allowing entities
     * that are currently on the stack to be returned to the app.
     */
    public function defer(cx:App, f:(Window, App) -> Void):Void {
        cx.defer(cx -> {
            if (!destroyed) f(this, cx);
        });
    }

    /**
     * Schedule the given closure to be run directly after the current frame is rendered.
     */
    public function onNextFrame(callback:(Window, App) -> Void):Void {
        nextFrameCallbacks.push(callback);
    }

    /**
     * Schedule a frame to be drawn on the next animation frame.
     *
     * This is useful for elements that need to animate continuously, such as a video player or an animated GIF.
     * It will cause the window to redraw on the next frame, even if no other changes have occurred.
     */
    public function requestAnimationFrame():Void {
        final entity = currentView();
        // Animated: drawn with its ancestors (see `renderInPlace`)
        animationViews.set(entity, true);
        onNextFrame((_, cx) -> cx.notify(entity));
    }

    /**
     * Whether callbacks were scheduled with `onNextFrame`.
     */
    public inline function hasNextFrameCallbacks():Bool {
        return nextFrameCallbacks.length > 0;
    }

    /**
     * Runs the callbacks scheduled with `onNextFrame` (called by the `GlazeSystem` before drawing).
     * Returns how many ran.
     */
    public function runNextFrameCallbacks():Int {
        if (nextFrameCallbacks.length == 0)
            return 0;
        final callbacks = nextFrameCallbacks;
        nextFrameCallbacks = [];
        app.update(cx -> {
            for (callback in callbacks) {
                callback(this, cx);
            }
        });
        return callbacks.length;
    }

    /**
     * Runs the next frame callbacks, like a platform frame request (Rust `simulate_next_frame`).
     */
    public inline function simulateNextFrame(?cx:App):Int {
        return runNextFrameCallbacks();
    }

/// Observing entities from a window

    /**
     * Register a callback to be invoked when the given entity is notified, with this window.
     */
    public function observe<T:Model>(observed:Entity<T>, cx:App, onNotify:(Entity<T>, Window, App) -> Void):Subscription {
        return cx.observe(observed, (entity, cx) -> {
            if (!destroyed) onNotify(entity, this, cx);
        });
    }

    /**
     * Subscribe to events emitted by the given entity, with this window.
     */
    public function subscribe<T:Model, E>(entity:Entity<T>, eventType:EventType<E>, cx:App, onEvent:(Entity<T>, E, Window, App) -> Void):Subscription {
        return cx.subscribe(entity, eventType, (entity, event, cx) -> {
            if (!destroyed) onEvent(entity, event, this, cx);
        });
    }

    @:allow(glaze)
    static function activeWindowOf(app:App):Null<Window> {
        var i = windows.length - 1;
        while (i >= 0) {
            final window = windows[i];
            if (window.app == app && window._active && !window.destroyed) {
                return window;
            }
            i--;
        }
        return null;
    }


    #if glaze_inspector
/// Inspector (Rust feature `inspector`, define `glaze_inspector`)

    /**
     * Toggles the inspector mode on this window.
     */
    public function toggleInspector(cx:App):Void {
        if (inspector == null) {
            inspector = cx.newEntity(_ -> new Inspector());
        }
        else {
            renderedFrame.nextInspectorInstanceIds = new Map();
            renderedFrame.inspectorHitboxes = new Map();
            nextFrame.nextInspectorInstanceIds = new Map();
            nextFrame.inspectorHitboxes = new Map();
            inspector = null;
        }
        refresh();
    }

    /**
     * The inspector of this window while it is open (for tests and tools).
     */
    public inline function inspectorEntity():Null<Inspector> {
        return inspector;
    }

    /**
     * Returns true if the window is in inspector mode.
     */
    public function isInspectorPicking(_cx:App):Bool {
        if (inspector != null) {
            return inspector.isPicking();
        }
        return false;
    }

    /**
     * Executes the provided function with mutable access to an inspector
     * state of type `type` (the box holds `null` when there is none yet).
     * Returns `null` when `inspectorId` is not the active element.
     */
    public function withInspectorState<T, R>(inspectorId:Null<InspectorElementId>, type:Class<T>, cx:App, f:(glaze.util.Ref<Null<T>>, Window) -> R):Null<R> {
        if (inspectorId == null) return null;
        final inspector = this.inspector;
        if (inspector == null) return null;
        if (!inspectorId.equals(inspector.activeElementId())) {
            return null;
        }
        return cx.updateEntity(inspector, (inspector, _cx) -> {
            return inspector.withActiveElementState(type, this, f);
        });
    }

    @:allow(glaze)
    function inspectorEnabled():Bool {
        return inspector != null;
    }

    /**
     * The global id of the current element id stack (Rust
     * `element_id_stack.global_id()`).
     */
    @:allow(glaze)
    function currentGlobalElementId():GlobalElementId {
        return elementIdNode;
    }

    @:allow(glaze)
    function buildInspectorElementId(path:InspectorElementId.InspectorElementPath):InspectorElementId {
        var entry = nextFrame.nextInspectorInstanceIds.get(path.key);
        if (entry == null) {
            entry = new InspectorInstanceCount(path);
            nextFrame.nextInspectorInstanceIds.set(path.key, entry);
        }
        final instanceId = entry.count;
        entry.count++;
        return new InspectorElementId(entry.path, instanceId);
    }

    function prepaintInspector(inspectorWidth:Float, cx:App):Null<AnyElement> {
        final inspector = this.inspector;
        if (inspector != null) {
            this.inspector = null;
            final inspectorElement = (inspector : AnyView).intoAnyElement();
            inspectorElement.prepaintAsRoot(
                new Point(_viewportSize.width - inspectorWidth, 0.0),
                new SizeOf<AvailableSpace>(AvailableSpace.Definite(inspectorWidth), AvailableSpace.Definite(_viewportSize.height)),
                this,
                cx
            );
            this.inspector = inspector;
            return inspectorElement;
        }
        else {
            return null;
        }
    }

    function paintInspector(inspectorElement:Null<AnyElement>, cx:App):Void {
        if (inspectorElement != null) {
            inspectorElement.paint(this, cx);
        }
    }

    /**
     * Registers a hitbox that can be used for inspector picking mode, allowing users to select and
     * inspect UI elements by clicking on them.
     */
    public function insertInspectorHitbox(hitboxId:Int, inspectorId:Null<InspectorElementId>, cx:App):Void {
        if (!isInspectorPicking(cx)) {
            return;
        }
        if (inspectorId != null) {
            nextFrame.inspectorHitboxes.set(hitboxId, inspectorId);
        }
    }

    function paintInspectorHitbox(cx:App):Void {
        final inspector = this.inspector;
        if (inspector != null) {
            final hovered = hoveredInspectorHitbox(inspector, nextFrame);
            if (hovered != null) {
                for (hitbox in nextFrame.hitboxes) {
                    if (hitbox.id == hovered.hitboxId) {
                        paintQuad(Prelude.fill(hitbox.bounds, Prelude.rgba(0x61afef4d)));
                        break;
                    }
                }
            }
        }
    }

    function handleInspectorMouseEvent(event:PlatformInput, cx:App):Void {
        final inspector = this.inspector;
        if (inspector == null) {
            return;
        }
        switch event.kind {
            case MouseMove:
                cx.updateEntity(inspector, (inspector, _cx) -> {
                    final hovered = hoveredInspectorHitbox(inspector, renderedFrame);
                    if (hovered != null) {
                        inspector.hover(hovered.inspectorId, this);
                    }
                    return null;
                });
            case MouseDown:
                cx.updateEntity(inspector, (inspector, _cx) -> {
                    final hovered = hoveredInspectorHitbox(inspector, renderedFrame);
                    if (hovered != null) {
                        inspector.select(hovered.inspectorId, this);
                    }
                    return null;
                });
            case Scroll:
                final event:ScrollEvent = cast event;
                // This should be kept in sync with SCROLL_LINES in x11 platform.
                final SCROLL_LINES:Float = 3.0;
                final SCROLL_PIXELS_PER_LAYER:Float = 36.0;
                final deltaY = event.delta.pixelDelta(SCROLL_PIXELS_PER_LAYER / SCROLL_LINES).y;
                cx.updateEntity(inspector, (inspector, _cx) -> {
                    if (inspector.pickDepth != null) {
                        var depth:Float = inspector.pickDepth + deltaY / SCROLL_PIXELS_PER_LAYER;
                        final maxDepth = mouseHitTest.ids.length - 0.5;
                        if (depth < 0.0) {
                            depth = 0.0;
                        }
                        else if (depth > maxDepth) {
                            depth = maxDepth;
                        }
                        inspector.pickDepth = depth;
                        final hovered = hoveredInspectorHitbox(inspector, renderedFrame);
                        if (hovered != null) {
                            inspector.setActiveElementId(hovered.inspectorId, this);
                        }
                    }
                    return null;
                });
            case _:
        }
    }

    function hoveredInspectorHitbox(inspector:Inspector, frame:Frame):Null<{hitboxId:Int, inspectorId:InspectorElementId}> {
        final pickDepth = inspector.pickDepth;
        if (pickDepth != null) {
            // Rust `(pick_depth as i64).try_into().unwrap_or(0)`: truncation, negatives clamp to 0
            final depth = pickDepth > 0 ? Std.int(pickDepth) : 0;
            final ids = mouseHitTest.ids;
            final maxSkipped = ids.length > 0 ? ids.length - 1 : 0;
            final skipCount = depth < maxSkipped ? depth : maxSkipped;
            for (i in skipCount...ids.length) {
                final hitboxId = ids[i];
                final inspectorId = frame.inspectorHitboxes.get(hitboxId);
                if (inspectorId != null) {
                    return {hitboxId: hitboxId, inspectorId: inspectorId};
                }
            }
        }
        return null;
    }
    #end

}

/** Renders the missing SVG tile of `Window.paintSvg` (fields set before each lookup) */
private class SvgTileBuilder {

    public var path:String = '';

    public var width:Int = 0;

    public var height:Int = 0;

    public var data:Null<haxe.io.Bytes> = null;

    public var cx:Null<App> = null;

    /** `build` as a function value, made once */
    public final buildFunction:() -> Null<AtlasTile.AtlasTileSource>;

    public function new() {
        buildFunction = build;
    }

    function build():Null<AtlasTile.AtlasTileSource> {
        return cx.svgRenderer().renderAlphaMask(new RenderSvgParams(path, width, height), data);
    }

}
