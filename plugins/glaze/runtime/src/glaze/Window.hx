// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.util.Stacks;
import glaze.platform.SceneRenderable;
import glaze.TouchGestureRecognizer.RecognizedTouchGesture;
import glaze.scene.Scene;
import haxe.ds.IntMap;

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
private class CursorStyleRequest {

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
private class TooltipRequest {

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
private class DeferredDraw {

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

    public final scene:Scene = new Scene();

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

    public final tabStops:TabStopMap = new TabStopMap();

    public final deferredDraws:Array<DeferredDraw> = [];

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
            state.node.removeState(state);
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
        elementStates.resize(0);
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

    /** Views notified since the last frame (Rust: the invalidator's dirty views) */
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
     * Opens a window whose root view is built by `build` (Rust
     * `cx.open_window(options, |window, cx| cx.new(...))`).
     */
    public static function open(app:App, options:Null<WindowOptions>, build:(Window, App) -> AnyView):Window {
        final window = new Window(app, options);
        window.root = build(window, app);
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
        root = view;
        refresh();
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
        addPendingDirtyView(entityId);
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
        return false;
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
    function addPendingDirtyView(viewId:Int):Void {
        if (!pendingDirtyViews.exists(viewId)) {
            pendingDirtyViews.set(viewId, true);
            pendingDirtyViewIds.push(viewId);
        }
    }

    function markViewDirty(viewId:Int):Void {
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
        drawing = true;
        drawingClean = !dirty;
        final previousRecorder = accessRecorder;
        accessRecorder = this;
        accessedStack.resize(0);
        currentAccessed = frameAccessed;
        frameAccessed.clear();
        app.startUpdate();
        try {
            drawFrame();
        }
        catch (e:haxe.Exception) {
            accessRecorder = previousRecorder;
            drawing = false;
            drawingClean = false;
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
        // Rust `invalidate_entities`
        final pendingIds = pendingDirtyViewIds;
        for (i in 0...pendingIds.length) {
            markViewDirty(pendingIds[i]);
        }
        pendingIds.resize(0);
        pendingDirtyViews.clear();
        // Default view caching: views whose scroll states changed render again
        viewDependencies.invalidateChanged(renderedFrame.dispatchTree, this);

        dirty = false;
        renderedViews.clear();
        renderedViewCount = 0;
        reusedViewCount = 0;
        requestedAutoscroll = null;

        // Restore the previously used input handler into an empty slot of the
        // last frame, so that a reused paint range finds it at its index.
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

        if (root != null) {
            drawRoots();
        }

        dirtyViews.clear();
        nextFrame.windowActive = _active;

        // Register the requested input handler with the platform (the last one).
        var focusedTextInput = -1;
        var handlerIndex = nextFrame.inputHandlers.length - 1;
        while (handlerIndex >= 0) {
            final inputHandler = nextFrame.inputHandlers[handlerIndex];
            if (inputHandler != null) {
                nextFrame.inputHandlers[handlerIndex] = null;
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

        glaze.util.FrameProfiler.begin(glaze.util.FrameProfiler.FINISH);
        layoutEngine.finishFrame();
        windowTextSystem.finishFrame();
        nextFrame.finish(renderedFrame);

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
        final currentFocusPath = renderedFrame.focusPath();
        final currentWindowActive = renderedFrame.windowActive;
        var focusBeforeListeners = _focus;

        // Views not rendered (or reused) anymore stop reacting
        final dispatchTree = renderedFrame.dispatchTree;
        final ids = trackerIds;
        var kept = 0;
        for (i in 0...ids.length) {
            final entityId = ids[i];
            if (!renderedViews.exists(entityId) && !dispatchTree.containsView(entityId)) {
                trackers.get(entityId).destroy();
                trackers.remove(entityId);
            }
            else {
                ids[kept++] = entityId;
            }
        }
        ids.resize(kept);

        AnyElement.clearArena();
        drawCount++;

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

        recordEntitiesAccessed();
        resetCursorStyle();
        refreshing = false;
        focusMovedWhileDrawing = _focus != focusBeforeListeners;
        glaze.util.FrameProfiler.end(glaze.util.FrameProfiler.FINISH);
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

        prepaintDeferredDraws();

        var activeDragElement:Null<AnyElement> = null;
        var tooltipElement:Null<AnyElement> = null;
        final activeDrag = app.activeDrag;
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

        paintDeferredDraws();

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
            }
            tracker.beginCapture();
        }
        else {
            tracker.resumeCapture();
        }
        accessedStack.push(currentAccessed);
        currentAccessed = tracker.accessed;
    }

    /**
     * Records an access to the given entity while this window draws (Rust
     * `EntityMap::read` / `lease` / `insert` mark the entity accessed).
     */
    @:allow(glaze)
    static inline function recordAccess(entityId:Int):Void {
        final window = accessRecorder;
        if (window != null) {
            window.currentAccessed.add(entityId);
        }
    }

    /**
     * `recordAccess` for a model, whose id is only read while a window draws.
     */
    @:allow(glaze)
    static inline function recordModelAccess(model:Model):Void {
        final window = accessRecorder;
        if (window != null) {
            window.currentAccessed.add(model.entityId);
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
        for (accessed in frameAccessed.ids) {
            next.add(accessed);
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
            if (pendingDirtyViews.exists(viewId)) {
                pendingDirtyViews.remove(viewId);
                pendingDirtyViewIds.remove(viewId);
                markViewDirty(viewId);
            }
            else if (childrenChanged) {
                markViewDirty(viewId);
            }
        }
        return host;
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
        final opacity = clamp01(elementOpacity);
        final scaleFactor = _scaleFactor;

        // Snap bounds
        final bounds = quad.bounds;
        final left = roundToDevice(bounds.origin.x);
        final top = roundToDevice(bounds.origin.y);
        final right = Math.max(roundToDevice(bounds.origin.x + bounds.size.width), left);
        final bottom = Math.max(roundToDevice(bounds.origin.y + bounds.size.height), top);

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

    function deferredDrawOrder(start:Int, end:Int):Array<Int> {
        final order = [for (i in start...end) i];
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

/// View caching (Rust `prepaint_index`, `reuse_prepaint`, `paint_index`, `reuse_paint`)

    /**
     * Writes the current position in the prepaint state of the next frame into `index`.
     */
    @:allow(glaze)
    function prepaintIndexInto(index:PrepaintStateIndex):Void {
        final frame = nextFrame;
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
        next.tabStops.replayRange(rendered.tabStops, start.tabHandleIndex, end.tabHandleIndex);
        windowTextSystem.reuseLayouts(start.lineLayoutIndex, end.lineLayoutIndex);
        next.scene.replay(start.sceneIndex, end.sceneIndex, rendered.scene);
    }

/// View caching: debugging

    /**
     * Number of layout runs (a layout root computed by taffy) since the
     * window was opened, for tests and benchmarks.
     */
    public function layoutRunCount():Int {
        return layoutEngine.runCount;
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
    inline function beginViewLayoutNodes(adopt:Null<Array<Int>>):Void {
        layoutEngine.beginViewNodes(adopt);
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
            return true;
        }
        if (lastInputWasKeyboard()) {
            return false;
        }
        return hitboxHitTest(hitboxId);
    }

    /**
     * Checks if the hitbox with this id is currently hovered, regardless of the last
     * input modality used.
     */
    public function isHitboxIdHoveredIgnoringLastInput(hitboxId:Int):Bool {
        if (_capturedHitbox == hitboxId) {
            return true;
        }
        return hitboxHitTest(hitboxId);
    }

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
