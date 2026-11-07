// Ported from gpui-pre 0.3.10: src/elements/div.rs (`Interactivity`, `InteractiveElementState`, tooltips, `GroupHitboxes`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.util.Stacks;
import glaze.ClickEvent.KeyboardClickEvent;
import glaze.ClickEvent.MouseClickEvent;
import glaze.util.Ref;

/**
 * A mouse listener of an element: called with the event, the phase and the
 * element's hitbox (Rust `MouseDownListener`, `MouseUpListener`...).
 */
typedef ElementMouseListener = (event:PlatformInput, phase:DispatchPhase, hitbox:Hitbox, window:Window, cx:App) -> Void;

/**
 * A style applied when a group is hovered, active or dragged over.
 */
/*
 * Entries of the typed listener lists of `Interactivity`. Classes rather
 * than anonymous structures: on hxcpp reading a field of an anonymous
 * structure is a lookup by name. `@:structInit`, so the `{type: ..., ...}`
 * literals still build them.
 */

/** A style applied while a value of the given type is dragged over */
@:structInit
class DragOverStyle {
    public final type:Class<Dynamic>;
    public final build:(Dynamic, Window, App) -> StyleRefinement;
    public function new(type:Class<Dynamic>, build:(Dynamic, Window, App) -> StyleRefinement) {
        this.type = type;
        this.build = build;
    }
}

/** A group style applied while a value of the given type is dragged over */
@:structInit
class GroupDragOverStyle {
    public final type:Class<Dynamic>;
    public final style:GroupStyle;
    public function new(type:Class<Dynamic>, style:GroupStyle) {
        this.type = type;
        this.style = style;
    }
}

/**
 * An action listener and the action type it handles: the entry painted into
 * the dispatch tree as is (`listener` is `null` on the subclasses below,
 * which handle `call()` themselves)
 */
class TypedActionListener extends DispatchTree.DispatchActionListener {
    public var type(get, never):Class<Dynamic>;
    inline function get_type():Class<Dynamic> {
        return actionType;
    }
    public function new(type:Class<Dynamic>, listener:Null<(Action, DispatchPhase, Window, App) -> Void>) {
        super(type, listener);
    }
}

/** `Interactivity.onAction`: calls its listener during the bubble phase */
private class BubbleActionListener extends TypedActionListener {
    final bubble:(Action, Window, App) -> Void;
    public function new(type:Class<Dynamic>, bubble:(Action, Window, App) -> Void) {
        super(type, null);
        this.bubble = bubble;
    }
    override public function call(action:Action, phase:DispatchPhase, window:Window, cx:App):Void {
        if (phase == Bubble) {
            bubble(action, window, cx);
        }
    }
}

/**
 * `Interactivity.captureAction`: calls its listener during the capture
 * phase, propagates during the bubble phase
 */
private class CaptureActionListener extends TypedActionListener {
    final capture:(Action, Window, App) -> Void;
    public function new(type:Class<Dynamic>, capture:(Action, Window, App) -> Void) {
        super(type, null);
        this.capture = capture;
    }
    override public function call(action:Action, phase:DispatchPhase, window:Window, cx:App):Void {
        if (phase == Capture) {
            capture(action, window, cx);
        }
        else {
            cx.propagate();
        }
    }
}

/** A drop listener and the dragged value type it handles */
@:structInit
class TypedDropListener {
    public final type:Class<Dynamic>;
    public final listener:(Dynamic, Window, App) -> Void;
    public function new(type:Class<Dynamic>, listener:(Dynamic, Window, App) -> Void) {
        this.type = type;
        this.listener = listener;
    }
}

class GroupStyle {

    /** The identifier for the group. */
    public final group:String;

    /** The specific style refinement that this group would apply to its children. */
    public final style:StyleRefinement;

    public function new(group:String, style:StyleRefinement) {
        this.group = group;
        this.style = style;
    }

}

/**
 * The drag listener of an element (`onDrag`).
 */
class DragListener {

    public final value:Dynamic;

    public final render:(Dynamic, Point, Window, App) -> AnyView;

    public function new(value:Dynamic, render:(Dynamic, Point, Window, App) -> AnyView) {
        this.value = value;
        this.render = render;
    }

}

/**
 * The tooltip builder of an element (`tooltip` / `hoverableTooltip`).
 */
class TooltipBuilder {

    public final build:(Window, App) -> AnyView;

    public final hoverable:Bool;

    public function new(build:(Window, App) -> AnyView, hoverable:Bool) {
        this.build = build;
        this.hoverable = hoverable;
    }

}

/**
 * Whether or not the element or a group that contains it is clicked by the mouse.
 */
class ElementClickedState {

    /** True if this element's group has been clicked, false otherwise */
    public var group:Bool = false;

    /** True if this element has been clicked, false otherwise */
    public var element:Bool = false;

    public function new() {}

    public inline function isClicked():Bool {
        return group || element;
    }

    public inline function reset():Void {
        group = false;
        element = false;
    }

}

/**
 * Whether or not the element or a group that contains it is hovered.
 */
class ElementHoverState {

    /** True if this element's group is hovered, false otherwise */
    public var group:Bool = false;

    /** True if this element is hovered, false otherwise */
    public var element:Bool = false;

    public function new() {}

}

/**
 * The state of the tooltip of an element.
 */
enum ActiveTooltip {
    /** Currently delaying before showing the tooltip. */
    WaitingForShow(task:AnyTask);
    /** Tooltip is visible, element was hovered or for hoverable tooltips, the tooltip was hovered. */
    Visible(tooltip:AnyTooltip, isHoverable:Bool);
    /** Tooltip is visible and hoverable, but the mouse is no longer hovering. Currently delaying before hiding it. */
    WaitingForHide(tooltip:AnyTooltip, task:AnyTask);
}

/**
 * The shared, optional `ActiveTooltip` of an element (Rust `Rc<RefCell<Option<ActiveTooltip>>>`).
 * Replacing or taking the value drops it: its pending task is cancelled. `alive` turns
 * false when the element state is dropped (Rust: the weak reference no longer upgrades).
 */
class ActiveTooltipCell {

    public var value(default, null):Null<ActiveTooltip> = null;

    public var alive(default, null):Bool = true;

    public function new() {}

    public inline function isSome():Bool {
        return value != null;
    }

    /**
     * Replaces the value, dropping the previous one.
     */
    public function set(newValue:Null<ActiveTooltip>):Void {
        final previous = value;
        value = newValue;
        dropValue(previous);
    }

    /**
     * Takes the value out, dropping it. Returns whether there was one.
     */
    public function take():Bool {
        final previous = value;
        value = null;
        dropValue(previous);
        return previous != null;
    }

    public function dispose():Void {
        alive = false;
        set(null);
    }

    static function dropValue(value:Null<ActiveTooltip>):Void {
        if (value == null)
            return;
        switch value {
            case WaitingForShow(task): task.cancel();
            case WaitingForHide(_, task): task.cancel();
            case Visible(_, _):
        }
    }

}

/**
 * The interactive state of an element, kept across frames by element id.
 */
class InteractiveElementState {

    public var focusHandle:Null<FocusHandle> = null;

    public var clickedState:Null<ElementClickedState> = null;

    public var hoverState:Null<ElementHoverState> = null;

    public var hoverListenerState:Null<Ref<Bool>> = null;

    public var pendingMouseDown:Null<Ref<Null<MouseDownEvent>>> = null;

    /** The focus generation at which an activation key went down, or null */
    public var pendingKeyboardDown:Null<Ref<Null<Int>>> = null;

    public var scrollOffset:Null<Ref<Point>> = null;

    public var ongoingScroll:Null<OngoingScroll> = null;

    public var activeTooltip:Null<ActiveTooltipCell> = null;

    /** Whether the active tooltip was shown by a touch long press that has not ended. */
    public var longPressTooltipActive:Null<Ref<Bool>> = null;

    public function new() {}

    /**
     * Called when the state is dropped (its element was not drawn in a frame).
     */
    public function dispose():Void {
        if (activeTooltip != null) {
            activeTooltip.dispose();
        }
    }

}

/**
 * Hover mode for the `onHover` listener.
 */
enum abstract HoverListenerMode(Int) {

    /**
     * Use input-modality-aware hit testing. Keyboard input suppresses hover until the mouse moves
     * again, unless pointer capture or an active mouse-down interaction keeps the listener hovered.
     */
    var InputModalityAware = 0;

    /**
     * Use hit testing even when the last input was from the keyboard.
     */
    var InputModalityIndependent = 1;

    public inline function isHovered(hitbox:Hitbox, window:Window):Bool {
        return (cast this : HoverListenerMode) == InputModalityAware ? hitbox.isHovered(window) : window.isHitboxIdHoveredIgnoringLastInput(hitbox.id);
    }

}

/**
 * The interactivity struct. Powers all of the general-purpose
 * interactivity in the `Div` element.
 *
 * Differences with GPUI: listeners filter events by `PlatformInput.kind`
 * instead of downcasting; action, drag and drop types are classes
 * (`onAction(MyAction, ...)`, `onDrop(MyValue, ...)`) compared exactly like
 * Rust `TypeId`s. Pinch, pressure, back gesture, file drop,
 * accessibility, inspector and window control areas are not ported.
 * `restrictScrollToAxis` locks precise deltas with `OngoingScroll`, whose
 * gesture separation reads the executor clock instead of the wall clock.
 */
class Interactivity {

    static inline final DRAG_THRESHOLD:Float = 2.0;

    static final ZERO_POINT:Point = new Point(0, 0);

    static final ZERO_SIZE:Size = new Size(0, 0);

    /** No click listener (never modified) */
    static final NO_CLICK_LISTENERS:Array<(ClickEvent, Window, App) -> Void> = [];

    /** Default delay before showing a tooltip, in seconds (500ms). */
    public static inline final DEFAULT_TOOLTIP_SHOW_DELAY:Float = 0.5;

    /** Delay before hiding a hoverable tooltip once unhovered, in seconds (500ms). */
    public static inline final HOVERABLE_TOOLTIP_HIDE_DELAY:Float = 0.5;

    /** The element ID of the element. */
    public var elementId:Null<ElementId> = null;

    /** Whether the element was clicked. This will only be present after layout. */
    public var active:Null<Bool> = null;

    /** Whether the element was hovered. This will only be present after paint if an hitbox was created. */
    public var hovered:Null<Bool> = null;

    public var tooltipId:Int = -1;

    public var contentSize:Size = ZERO_SIZE;

    public var keyContext:Null<KeyContext> = null;

    public var focusable:Bool = false;

    public var trackedFocusHandle:Null<FocusHandle> = null;

    /** The content mask this element pushed in its prepaint phase (internal) */
    @:noCompletion var prepaintContentMask:Null<ContentMask> = null;

    public var trackedScrollHandle:Null<ScrollHandle> = null;

    public var scrollAnchor:Null<ScrollAnchor> = null;

    public var scrollOffset:Null<Ref<Point>> = null;

    public var ongoingScroll:Null<OngoingScroll> = null;

    public var group:Null<String> = null;

    /** The base style of the element, before any modifications are applied by focus, active, etc. */
    #if glaze_inspector
    public var baseStyle:StyleRefinement = new StyleRefinement();
    #else
    public final baseStyle:StyleRefinement = new StyleRefinement();
    #end

    public var focusStyle:Null<StyleRefinement> = null;

    public var inFocusStyle:Null<StyleRefinement> = null;

    public var focusVisibleStyle:Null<StyleRefinement> = null;

    public var hoverStyle:Null<StyleRefinement> = null;

    public var groupHoverStyle:Null<GroupStyle> = null;

    public var activeStyle:Null<StyleRefinement> = null;

    public var groupActiveStyle:Null<GroupStyle> = null;

    public var dragOverStyles:Null<Array<DragOverStyle>> = null;

    public var groupDragOverStyles:Null<Array<GroupDragOverStyle>> = null;

    public var mouseDownListeners:Null<Array<ElementMouseListener>> = null;

    public var mouseUpListeners:Null<Array<ElementMouseListener>> = null;

    public var mouseMoveListeners:Null<Array<ElementMouseListener>> = null;

    public var mouseExitListeners:Null<Array<ElementMouseListener>> = null;

    public var scrollListeners:Null<Array<ElementMouseListener>> = null;

    public var keyDownListeners:Null<Array<(KeyDownEvent, DispatchPhase, Window, App) -> Void>> = null;

    public var keyUpListeners:Null<Array<(KeyUpEvent, DispatchPhase, Window, App) -> Void>> = null;

    public var modifiersChangedListeners:Null<Array<(ModifiersChangedEvent, Window, App) -> Void>> = null;

    public var actionListeners:Null<Array<TypedActionListener>> = null;

    public var dropListeners:Null<Array<TypedDropListener>> = null;

    public var canDropPredicate:Null<(Dynamic, Window, App) -> Bool> = null;

    public var clickListeners:Null<Array<(ClickEvent, Window, App) -> Void>> = null;

    public var auxClickListeners:Null<Array<(ClickEvent, Window, App) -> Void>> = null;

    public var dragListener:Null<DragListener> = null;

    public var hoverListener:Null<(Bool, Window, App) -> Void> = null;

    public var hoverListenerModeValue:HoverListenerMode = InputModalityAware;

    public var tooltipBuilder:Null<TooltipBuilder> = null;

    /** Delay before showing the tooltip in seconds, null for the default */
    public var tooltipShowDelay:Null<Float> = null;

    public var hitboxBehavior:HitboxBehavior = Normal;

    /** The window control area of the element (Rust `window_control`), see `windowControlArea`. */
    public var windowControl:Null<WindowControlArea> = null;

    public var tabIndex:Null<Int> = null;

    public var tabGroup:Bool = false;

    public var tabStop:Bool = true;

    #if glaze_inspector
    /** Where the element was built (Rust `source_location`, captured by `div()`, `img()` and `svg()`) */
    public var sourceLocation:Null<haxe.PosInfos> = null;
    #end

    public function new() {}

/// Listener registration

    /**
     * Bind the given callback to the mouse down event for the given mouse button, during the bubble phase.
     */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Void {
        if (mouseDownListeners == null) mouseDownListeners = [];
        mouseDownListeners.push((event, phase, hitbox, window, cx) -> {
            final event:MouseDownEvent = cast event;
            if (phase == Bubble && event.button == button && hitbox.isHovered(window)) {
                listener(event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to the mouse down event for any button, during the capture phase.
     */
    public function captureAnyMouseDown(listener:(MouseDownEvent, Window, App) -> Void):Void {
        if (mouseDownListeners == null) mouseDownListeners = [];
        mouseDownListeners.push((event, phase, hitbox, window, cx) -> {
            if (phase == Capture && hitbox.isHovered(window)) {
                listener(cast event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to the mouse down event for any button, during the bubble phase.
     */
    public function onAnyMouseDown(listener:(MouseDownEvent, Window, App) -> Void):Void {
        if (mouseDownListeners == null) mouseDownListeners = [];
        mouseDownListeners.push((event, phase, hitbox, window, cx) -> {
            if (phase == Bubble && hitbox.isHovered(window)) {
                listener(cast event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to the mouse up event for the given button, during the bubble phase.
     */
    public function onMouseUp(button:MouseButton, listener:(MouseUpEvent, Window, App) -> Void):Void {
        if (mouseUpListeners == null) mouseUpListeners = [];
        mouseUpListeners.push((event, phase, hitbox, window, cx) -> {
            final event:MouseUpEvent = cast event;
            if (phase == Bubble && event.button == button && hitbox.isHovered(window)) {
                listener(event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to the mouse up event for any button, during the capture phase.
     */
    public function captureAnyMouseUp(listener:(MouseUpEvent, Window, App) -> Void):Void {
        if (mouseUpListeners == null) mouseUpListeners = [];
        mouseUpListeners.push((event, phase, hitbox, window, cx) -> {
            if (phase == Capture && hitbox.isHovered(window)) {
                listener(cast event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to the mouse up event for any button, during the bubble phase.
     */
    public function onAnyMouseUp(listener:(MouseUpEvent, Window, App) -> Void):Void {
        if (mouseUpListeners == null) mouseUpListeners = [];
        mouseUpListeners.push((event, phase, hitbox, window, cx) -> {
            if (phase == Bubble && hitbox.isHovered(window)) {
                listener(cast event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to the mouse down event, on any button, during the capture phase,
     * when the mouse is outside of the bounds of this element.
     */
    public function onMouseDownOut(listener:(MouseDownEvent, Window, App) -> Void):Void {
        if (mouseDownListeners == null) mouseDownListeners = [];
        mouseDownListeners.push((event, phase, hitbox, window, cx) -> {
            if (phase == Capture && !hitbox.contains(window.mousePosition())) {
                listener(cast event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to the mouse up event, for the given button, during the capture phase,
     * when the mouse is outside of the bounds of this element.
     */
    public function onMouseUpOut(button:MouseButton, listener:(MouseUpEvent, Window, App) -> Void):Void {
        if (mouseUpListeners == null) mouseUpListeners = [];
        mouseUpListeners.push((event, phase, hitbox, window, cx) -> {
            final event:MouseUpEvent = cast event;
            if (phase == Capture && event.button == button && !hitbox.isHovered(window)) {
                listener(event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to the mouse move event, during the bubble phase.
     */
    public function onMouseMove(listener:(MouseMoveEvent, Window, App) -> Void):Void {
        if (mouseMoveListeners == null) mouseMoveListeners = [];
        mouseMoveListeners.push((event, phase, hitbox, window, cx) -> {
            if (phase == Bubble && hitbox.isHovered(window)) {
                listener(cast event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to the mouse exit event, during the bubble phase.
     */
    public function onMouseExit(listener:(MouseExitEvent, Window, App) -> Void):Void {
        if (mouseExitListeners == null) mouseExitListeners = [];
        mouseExitListeners.push((event, phase, hitbox, window, cx) -> {
            if (phase == Bubble && hitbox.isHovered(window)) {
                listener(cast event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to the mouse drag event of the given type. Note that this
     * will be called for all move events, inside or outside of this element, as long as the
     * drag was started with this element under the mouse. Useful for implementing draggable
     * UIs that don't conform to a drag and drop style interaction, like resizing.
     */
    public function onDragMove<T>(type:Class<T>, listener:(DragMoveEvent<T>, Window, App) -> Void):Void {
        if (mouseMoveListeners == null) mouseMoveListeners = [];
        mouseMoveListeners.push((event, phase, hitbox, window, cx) -> {
            final drag = cx.activeDrag;
            if (phase == Capture && drag != null && drag.valueIs(type)) {
                listener(new DragMoveEvent<T>(cast event, hitbox.bounds, drag.value), window, cx);
            }
        });
    }

    /**
     * Bind the given callback to scroll events (wheel and trackpad), during the bubble phase.
     */
    public function onScroll(listener:(ScrollEvent, Window, App) -> Void):Void {
        if (scrollListeners == null) scrollListeners = [];
        scrollListeners.push((event, phase, hitbox, window, cx) -> {
            if (phase == Bubble && hitbox.shouldHandleScroll(window)) {
                listener(cast event, window, cx);
            }
        });
    }

    /**
     * Renamed to `onScroll` in GPUI (kept for compatibility).
     */
    public inline function onScrollWheel(listener:(ScrollEvent, Window, App) -> Void):Void {
        onScroll(listener);
    }

    /**
     * Bind the given callback to an action dispatch during the capture phase.
     */
    public function captureAction<A:Action>(type:Class<A>, listener:(A, Window, App) -> Void):Void {
        if (actionListeners == null) actionListeners = [];
        actionListeners.push(new CaptureActionListener(type, cast listener));
    }

    /**
     * Bind the given callback to an action dispatch during the bubble phase.
     */
    public function onAction<A:Action>(type:Class<A>, listener:(A, Window, App) -> Void):Void {
        if (actionListeners == null) actionListeners = [];
        actionListeners.push(new BubbleActionListener(type, cast listener));
    }

    /**
     * The entry `onAction(type, listener)` registers: immutable, so an owner
     * that keeps its listeners can make it once and add it each frame
     * (`addActionEntry`). Internal.
     */
    @:allow(glaze)
    static function bubbleActionEntry<A:Action>(type:Class<A>, listener:(A, Window, App) -> Void):TypedActionListener {
        return new BubbleActionListener(type, cast listener);
    }

    /** Adds an entry made by `bubbleActionEntry` (`onAction` without a new entry). Internal. */
    @:allow(glaze)
    function addActionEntry(entry:TypedActionListener):Void {
        if (actionListeners == null) actionListeners = [];
        actionListeners.push(entry);
    }

    /**
     * Bind the given callback to an action dispatch, based on a dynamic action parameter
     * instead of a type parameter. Useful for component libraries that want to expose
     * action bindings to their users.
     */
    public function onBoxedAction(action:Action, listener:(Action, Window, App) -> Void):Void {
        final action = action.boxedClone();
        if (actionListeners == null) actionListeners = [];
        actionListeners.push(new TypedActionListener(Type.getClass(action), (_, phase, window, cx) -> {
            if (phase == Bubble) {
                listener(action, window, cx);
            }
        }));
    }

    /**
     * Bind the given callback to a key down event, during the bubble phase.
     */
    public function onKeyDown(listener:(KeyDownEvent, Window, App) -> Void):Void {
        if (keyDownListeners == null) keyDownListeners = [];
        keyDownListeners.push((event, phase, window, cx) -> {
            if (phase == Bubble) {
                listener(event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to a key down event, during the capture phase.
     */
    public function captureKeyDown(listener:(KeyDownEvent, Window, App) -> Void):Void {
        if (keyDownListeners == null) keyDownListeners = [];
        keyDownListeners.push((event, phase, window, cx) -> {
            if (phase == Capture) {
                listener(event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to a key up event, during the bubble phase.
     */
    public function onKeyUp(listener:(KeyUpEvent, Window, App) -> Void):Void {
        if (keyUpListeners == null) keyUpListeners = [];
        keyUpListeners.push((event, phase, window, cx) -> {
            if (phase == Bubble) {
                listener(event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to a key up event, during the capture phase.
     */
    public function captureKeyUp(listener:(KeyUpEvent, Window, App) -> Void):Void {
        if (keyUpListeners == null) keyUpListeners = [];
        keyUpListeners.push((event, phase, window, cx) -> {
            if (phase == Capture) {
                listener(event, window, cx);
            }
        });
    }

    /**
     * Bind the given callback to modifiers changing events.
     */
    public function onModifiersChanged(listener:(ModifiersChangedEvent, Window, App) -> Void):Void {
        if (modifiersChangedListeners == null) modifiersChangedListeners = [];
        modifiersChangedListeners.push(listener);
    }

    /**
     * Bind the given callback to drop events of the given type, whether or not the drag started on this element.
     */
    public function onDrop<T>(type:Class<T>, listener:(T, Window, App) -> Void):Void {
        if (dropListeners == null) dropListeners = [];
        dropListeners.push({type: type, listener: (value, window, cx) -> listener(cast value, window, cx)});
    }

    /**
     * Use the given predicate to determine whether or not a drop event should be dispatched to this element.
     */
    public function canDrop(predicate:(Dynamic, Window, App) -> Bool):Void {
        canDropPredicate = predicate;
    }

    /**
     * Bind the given callback to click events of this element.
     */
    public function onClick(listener:(ClickEvent, Window, App) -> Void):Void {
        if (clickListeners == null) clickListeners = [];
        clickListeners.push(listener);
    }

    /**
     * Bind the given callback to non-primary click events of this element.
     */
    public function onAuxClick(listener:(ClickEvent, Window, App) -> Void):Void {
        if (auxClickListeners == null) auxClickListeners = [];
        auxClickListeners.push(listener);
    }

    /**
     * On drag initiation, this callback will be used to create a new view to render the dragged value
     * for a drag and drop operation. The value is passed to the constructor with the offset of the
     * cursor in the element. Only one drag listener per element.
     */
    public function onDrag<T>(value:T, constructor:(T, Point, Window, App) -> AnyView):Void {
        dragListener = new DragListener(value, (value, offset, window, cx) -> constructor(cast value, offset, window, cx));
    }

    /**
     * Bind the given callback on the hover start and end events of this element. Note that the boolean
     * passed to the callback is true when the hover starts and false when it ends.
     */
    public function onHover(listener:(Bool, Window, App) -> Void):Void {
        hoverListener = listener;
    }

    /**
     * Use the given callback to construct a new tooltip view when the mouse hovers over this element.
     */
    public function tooltip(buildTooltip:(Window, App) -> AnyView):Void {
        tooltipBuilder = new TooltipBuilder(buildTooltip, false);
    }

    /**
     * Use the given callback to construct a new tooltip view when the mouse hovers over this element.
     * The tooltip itself is also hoverable and won't disappear when the user moves the mouse into
     * the tooltip.
     */
    public function hoverableTooltip(buildTooltip:(Window, App) -> AnyView):Void {
        tooltipBuilder = new TooltipBuilder(buildTooltip, true);
    }

    /**
     * Block the mouse from all interactions with elements behind this element's hitbox.
     */
    public inline function occludeMouse():Void {
        hitboxBehavior = BlockMouse;
    }

    /**
     * Set the bounds of this element as a hitbox that blocks mouse interactions except scrolling.
     */
    public inline function blockMouseExceptScroll():Void {
        hitboxBehavior = BlockMouseExceptScroll;
    }

/// Phases

    /**
     * Layout this element according to this interactivity state's configured styles.
     */
    public function requestLayout(globalId:Null<GlobalElementId>, #if glaze_inspector inspectorId:Null<InspectorElementId>, #end window:Window, cx:App, f:(Style, Window, App) -> LayoutId):LayoutId {
        final style = requestLayoutStyle(globalId, #if glaze_inspector inspectorId, #end window, cx);
        return f(style, window, cx);
    }

    static var interactiveStateTypeId:Int = -1;

    /**
     * The interactive element state of `globalId` for this frame (Rust
     * `with_optional_element_state`), or null without an id.
     */
    static inline function interactiveElementState(globalId:Null<GlobalElementId>, window:Window):Null<InteractiveElementState> {
        if (globalId == null) {
            return null;
        }
        if (interactiveStateTypeId == -1) {
            interactiveStateTypeId = ElementStateType.of(InteractiveElementState);
        }
        final box = window.elementStateBox(globalId, interactiveStateTypeId);
        if (box.value == null) box.value = new InteractiveElementState();
        return box.value;
    }

    /**
     * The first half of `requestLayout()`: updates the element state and
     * returns the style to request the layout with (no closure for `Div`).
     */
    public function requestLayoutStyle(globalId:Null<GlobalElementId>, #if glaze_inspector inspectorId:Null<InspectorElementId>, #end window:Window, cx:App):Style {
        #if glaze_inspector
        window.withInspectorState(inspectorId, DivInspectorState, cx, (inspectorState, _window) -> {
            if (inspectorState.value != null) {
                baseStyle = inspectorState.value.baseStyle.clone();
                computedStyle = null;
            }
            else {
                inspectorState.value = new DivInspectorState(baseStyle.clone(), new Bounds(new Point(0, 0), new Size(0, 0)), new Size(0, 0));
            }
            return null;
        });
        #end

        {
            final elementState = interactiveElementState(globalId, window);

            if (elementState != null && cx.hasActiveDrag()) {
                if (elementState.pendingMouseDown != null) {
                    elementState.pendingMouseDown.value = null;
                }
                if (elementState.clickedState != null) {
                    elementState.clickedState.reset();
                }
            }

            // Ensure we store a focus handle in our element state if we're focusable.
            // If there's an explicit focus handle we're tracking, use that. Otherwise
            // create a new handle and store it in the element state, which lives for as
            // as frames contain an element with this id.
            if (focusable && trackedFocusHandle == null && elementState != null) {
                if (elementState.focusHandle == null) {
                    elementState.focusHandle = cx.focusHandle();
                }
                var handle = elementState.focusHandle.tabStop(tabStop);
                if (tabIndex != null) {
                    handle = handle.tabIndex(tabIndex);
                }
                trackedFocusHandle = handle;
            }

            if (trackedScrollHandle != null) {
                scrollOffset = trackedScrollHandle.state.offset;
                ongoingScroll = trackedScrollHandle.state.ongoingScroll;
            }
            else if ((baseStyle.has(StyleRefinement.OVERFLOW_X) && baseStyle.overflowX == Scroll
                || baseStyle.has(StyleRefinement.OVERFLOW_Y) && baseStyle.overflowY == Scroll)
                && elementState != null) {
                if (elementState.scrollOffset == null) {
                    elementState.scrollOffset = new Ref(new Point(0, 0));
                }
                scrollOffset = elementState.scrollOffset;
                if (elementState.ongoingScroll == null) {
                    elementState.ongoingScroll = new OngoingScroll();
                }
                ongoingScroll = elementState.ongoingScroll;
            }

            return computeStyleInternal(null, elementState, window, cx);
        }
    }

    /**
     * Commit the bounds of this element according to this interactivity state's configured styles.
     * `f` gets the style, the scroll offset to apply to the children and the hitbox.
     */
    public function prepaint<R>(globalId:Null<GlobalElementId>, #if glaze_inspector inspectorId:Null<InspectorElementId>, #end bounds:Bounds, contentSize:Size, window:Window, cx:App, f:(Style, Point, Null<Hitbox>, Window, App) -> R):R {
        final style = prepaintBegin(globalId, #if glaze_inspector inspectorId, #end bounds, contentSize, window, cx);
        final result = f(style, prepaintScrollOffset, prepaintHitbox, window, cx);
        prepaintEnd(window);
        return result;
    }

    /** The hitbox inserted by `prepaintBegin()`, or null */
    public var prepaintHitbox(default, null):Null<Hitbox> = null;

    /** The scroll offset to apply to the children, set by `prepaintBegin()` */
    public var prepaintScrollOffset(default, null):Point = ZERO_POINT;

    var prepaintTextStyle:Null<TextStyleRefinement> = null;
    var prepaintMask:Bool = false;
    var previousPrepaintOpacity:Float = 1.0;
    var prepaintPushedGroup:Bool = false;

    /**
     * The first half of `prepaint()` (no closure for `Div`): returns the
     * style and sets `prepaintScrollOffset` and `prepaintHitbox`. The
     * children are prepainted between it and `prepaintEnd()`.
     */
    public function prepaintBegin(globalId:Null<GlobalElementId>, #if glaze_inspector inspectorId:Null<InspectorElementId>, #end bounds:Bounds, contentSize:Size, window:Window, cx:App):Style {
        this.contentSize = contentSize;

        #if glaze_inspector
        window.withInspectorState(inspectorId, DivInspectorState, cx, (inspectorState, _window) -> {
            if (inspectorState.value != null) {
                inspectorState.value.bounds = bounds;
                inspectorState.value.contentSize = contentSize;
            }
            return null;
        });
        #end

        if (trackedFocusHandle != null) {
            window.setFocusHandle(trackedFocusHandle, cx);
        }

        {
            final elementState = interactiveElementState(globalId, window);
            final style = computeStyleInternal(null, elementState, window, cx);

            if (elementState != null) {
                if (elementState.clickedState != null) {
                    active = elementState.clickedState.element;
                }
                if (hoverStyle != null || groupHoverStyle != null) {
                    if (elementState.hoverState == null) {
                        elementState.hoverState = new ElementHoverState();
                    }
                }
                if (elementState.activeTooltip != null) {
                    if (tooltipBuilder != null) {
                        tooltipId = setTooltipOnWindow(elementState.activeTooltip, window);
                    }
                    else {
                        // If there is no longer a tooltip builder, remove the active tooltip.
                        if (elementState.longPressTooltipActive != null) {
                            elementState.longPressTooltipActive.value = false;
                        }
                        elementState.activeTooltip.take();
                    }
                }
            }

            final textStyle = style.textStyle();
            if (textStyle != null) window.pushTextStyle(textStyle);
            final mask = window.pushOverflowMask(style, bounds);
            // Kept for the paint phase (the same mask when the same values)
            prepaintContentMask = mask ? window.contentMask() : null;

            final hitbox = shouldInsertHitbox(style, window, cx) ? window.insertHitbox(bounds, hitboxBehavior) : null;
            final scrollOffset = clampScrollPosition(bounds, style, window, cx);

            // Context of the descendants' paint that cached views compare
            // (the opacity and group hitboxes they will be painted with)
            final previousPrepaintOpacity = window.prepaintOpacity;
            if (style.isSome(StyleRefinement.OPACITY)) {
                window.prepaintOpacity = previousPrepaintOpacity * style.opacity;
            }
            final pushedGroup = group != null && hitbox != null;
            if (pushedGroup) {
                window.prepaintGroupHitboxes.push(hitbox.id);
            }

            prepaintHitbox = hitbox;
            prepaintScrollOffset = scrollOffset;
            prepaintTextStyle = textStyle;
            prepaintMask = mask;
            this.previousPrepaintOpacity = previousPrepaintOpacity;
            prepaintPushedGroup = pushedGroup;
            return style;
        }
    }

    /**
     * The second half of `prepaint()`, after the children.
     */
    public function prepaintEnd(window:Window):Void {
        if (prepaintPushedGroup) {
            Stacks.drop(window.prepaintGroupHitboxes);
        }
        window.prepaintOpacity = previousPrepaintOpacity;

        if (prepaintMask) window.popContentMask();
        if (prepaintTextStyle != null) window.popTextStyle();
        prepaintTextStyle = null;
        prepaintMask = false;
    }

    function shouldInsertHitbox(style:Style, window:Window, cx:App):Bool {
        #if glaze_inspector
        // Rust ends the condition with `|| window.is_inspector_picking(cx)`
        if (window.isInspectorPicking(cx)) return true;
        #end
        return hitboxBehavior != Normal
            || windowControl != null
            || style.isSome(StyleRefinement.MOUSE_CURSOR)
            || group != null
            || scrollOffset != null
            || trackedFocusHandle != null
            || hoverStyle != null
            || groupHoverStyle != null
            || hoverListener != null
            || mouseUpListeners != null
            || mouseDownListeners != null
            || mouseMoveListeners != null
            || mouseExitListeners != null
            || clickListeners != null
            || auxClickListeners != null
            || scrollListeners != null
            || dragListener != null
            || dropListeners != null
            || dragOverStyles != null
            || tooltipBuilder != null;
    }

    function clampScrollPosition(bounds:Bounds, style:Style, window:Window, cx:App):Point {
        inline function roundToTwoDecimals(pixels:Float):Float {
            return glaze.util.MathUtil.round(pixels * 100.0) / 100.0;
        }

        if (scrollOffset == null) {
            return ZERO_POINT;
        }

        var scrollToBottom = false;
        final scrollHandleState = trackedScrollHandle != null ? trackedScrollHandle.state : null;
        if (scrollHandleState != null) {
            scrollHandleState.overflowX = style.overflowX;
            scrollHandleState.overflowY = style.overflowY;
            scrollToBottom = scrollHandleState.scrollToBottom;
            scrollHandleState.scrollToBottom = false;
        }

        final remSize = window.remSize();
        // Taffy lays the box out with the padding snapped to the device pixel
        // grid; recomputed unsnapped, it could exceed `bounds` and leave the box
        // scrollable by the sub-pixel difference.
        final paddingLeft = window.pixelSnap(style.paddingLeft.toPixelsOf(bounds.size.width, remSize));
        final paddingRight = window.pixelSnap(style.paddingRight.toPixelsOf(bounds.size.width, remSize));
        final paddingTop = window.pixelSnap(style.paddingTop.toPixelsOf(bounds.size.height, remSize));
        final paddingBottom = window.pixelSnap(style.paddingBottom.toPixelsOf(bounds.size.height, remSize));
        // The floating point values produced by Taffy and ours often vary
        // slightly after ~5 decimal places: round the scroll max to 2 decimal places.
        final scrollMaxX = Math.max(roundToTwoDecimals(contentSize.width + paddingLeft + paddingRight - bounds.size.width), 0);
        final scrollMaxY = Math.max(roundToTwoDecimals(contentSize.height + paddingTop + paddingBottom - bounds.size.height), 0);
        // Clamp scroll offset in case scroll max is smaller now (e.g., if children
        // were removed or the bounds became larger).
        final current = scrollOffset.value;
        final x = clamp(current.x, -scrollMaxX, 0);
        final y = scrollToBottom ? -scrollMaxY : clamp(current.y, -scrollMaxY, 0);
        final clamped = (x == current.x && y == current.y) ? current : new Point(x, y);
        scrollOffset.value = clamped;

        if (scrollHandleState != null) {
            scrollHandleState.maxOffset = new Point(scrollMaxX, scrollMaxY);
            scrollHandleState.bounds = bounds;
        }

        return clamped;
    }

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        // Rust `Ord::clamp` on `Pixels`, ordered with `f32::total_cmp` (-0 < +0)
        return glaze.util.MathUtil.totalLess(value, min) ? min : (glaze.util.MathUtil.totalLess(max, value) ? max : value);
    }

    /**
     * Paint this element according to this interactivity state's configured styles
     * and bind the element's mouse and keyboard events.
     *
     * `paintContent` paints the content of the element (children) between the
     * background and the border, inside its content mask.
     */
    public function paint(globalId:Null<GlobalElementId>, #if glaze_inspector inspectorId:Null<InspectorElementId>, #end bounds:Bounds, hitbox:Null<Hitbox>, window:Window, cx:App, paintContent:(Style, Window, App) -> Void):Void {
        final style = paintBegin(globalId, #if glaze_inspector inspectorId, #end bounds, hitbox, window, cx);
        if (style == null) {
            return;
        }
        paintContent(style, window, cx);
        paintEnd(bounds, window, cx);
    }

    var paintStyle:Null<Style> = null;
    var paintHitbox:Null<Hitbox> = null;
    var paintCornerRadii:Null<Corners> = null;
    var paintTextStyle:Null<TextStyleRefinement> = null;
    var paintMask:Bool = false;
    var paintTabGroup:Bool = false;
    var paintHasOpacity:Bool = false;
    var paintPreviousOpacity:Float = 0.0;
    #if glaze_inspector
    var paintInspectorId:Null<InspectorElementId> = null;
    #end

    /**
     * The first half of `paint()` (no closure for `Div`): paints the
     * background and binds the listeners, then returns the style, or null
     * when the element is hidden (nothing else to paint, no `paintEnd()`).
     * The content is painted between it and `paintEnd()`.
     */
    public function paintBegin(globalId:Null<GlobalElementId>, #if glaze_inspector inspectorId:Null<InspectorElementId>, #end bounds:Bounds, hitbox:Null<Hitbox>, window:Window, cx:App):Null<Style> {
        hovered = hitbox != null ? hitbox.isHovered(window) : null;
        // Port: an element scrolled from another view draws again (default view caching)
        if (trackedScrollHandle != null) {
            trackedScrollHandle.recordView(window);
        }
        final elementState = interactiveElementState(globalId, window);

        final style = computeStyleInternal(hitbox, elementState, window, cx);

        paintHoverGroupHandler(window, cx);

        if (style.visibility == Visibility.Hidden) {
            return null;
        }

        final tabGroupIndex:Null<Int> = tabGroup ? tabIndex : null;

        final hasOpacity = style.isSome(StyleRefinement.OPACITY);
        paintHasOpacity = hasOpacity;
        paintPreviousOpacity = hasOpacity ? window.pushElementOpacity(style.opacity) : 0.0;

        paintCornerRadii = style.paintBackground(bounds, window, cx);

        final textStyle = style.textStyle();
        if (textStyle != null) window.pushTextStyle(textStyle);
        final mask = window.pushOverflowMask(style, bounds, prepaintContentMask);
        prepaintContentMask = null;

        // Rust `window.with_tab_group(tab_group_index, ...)` around the listeners and the content
        paintTabGroup = tabGroupIndex != null;
        if (paintTabGroup) {
            @:privateAccess window.nextFrame.tabStops.beginGroup(tabGroupIndex);
        }

        // Register the container's own focus handle *inside* its tab group, so that
        // focusing the container and then calling `focusNext` descends into this group's
        // first item.
        if (trackedFocusHandle != null) {
            window.insertTabStop(trackedFocusHandle);
        }
        if (hitbox != null) {
            final drag = cx.activeDrag;
            if (drag != null) {
                if (drag.cursorStyle != null) {
                    window.setWindowCursorStyle(drag.cursorStyle);
                }
            }
            else {
                if (style.isSome(StyleRefinement.MOUSE_CURSOR)) {
                    window.setCursorStyle(style.mouseCursor, hitbox);
                }
            }

            if (group != null) {
                GroupHitboxes.push(group, hitbox.id, cx);
            }

            if (windowControl != null) {
                window.insertWindowControlHitbox(windowControl, hitbox);
            }

            paintMouseListeners(hitbox, elementState, window, cx);
            paintScrollListener(hitbox, style, window, cx);
        }

        paintKeyboardListeners(window, cx);

        paintStyle = style;
        paintHitbox = hitbox;
        paintTextStyle = textStyle;
        paintMask = mask;
        #if glaze_inspector
        paintInspectorId = inspectorId;
        #end
        return style;
    }

    /**
     * The second half of `paint()`, after the content: the border.
     */
    public function paintEnd(bounds:Bounds, window:Window, cx:App):Void {
        final style = paintStyle;
        final hitbox = paintHitbox;
        paintStyle = null;
        paintHitbox = null;

        #if glaze_inspector
        if (hitbox != null) {
            window.insertInspectorHitbox(hitbox.id, paintInspectorId, cx);
        }
        #end

        if (hitbox != null && group != null) {
            GroupHitboxes.pop(group, cx);
        }

        if (paintTabGroup) {
            @:privateAccess window.nextFrame.tabStops.endGroup();
        }

        if (paintMask) window.popContentMask();
        if (paintTextStyle != null) window.popTextStyle();
        paintMask = false;
        paintTextStyle = null;

        style.paintBorder(bounds, paintCornerRadii, window, cx);

        if (paintHasOpacity) window.popElementOpacity(paintPreviousOpacity);
    }

    function paintMouseListeners(hitbox:Hitbox, elementState:Null<InteractiveElementState>, window:Window, cx:App):Void {
        final isFocused = trackedFocusHandle != null && trackedFocusHandle.isFocused(window);

        // If this element can be focused, register a mouse down listener
        // that will automatically transfer focus when hitting the element.
        // This behavior can be suppressed by using `window.preventDefault()`.
        if (trackedFocusHandle != null) {
            // In an entry, without a closure (`FocusMouseDownEntry`)
            window.addMouseListenerEntry(new FocusMouseDownEntry(hitbox, trackedFocusHandle));
        }

        final mouseDownListeners = this.mouseDownListeners;
        if (mouseDownListeners != null) {
            this.mouseDownListeners = null;
            for (listener in mouseDownListeners) {
                window.onElementMouseEvent(MouseDown, listener, hitbox);
            }
        }

        final mouseUpListeners = this.mouseUpListeners;
        if (mouseUpListeners != null) {
            this.mouseUpListeners = null;
            for (listener in mouseUpListeners) {
                window.onElementMouseEvent(MouseUp, listener, hitbox);
            }
        }

        final mouseMoveListeners = this.mouseMoveListeners;
        if (mouseMoveListeners != null) {
            this.mouseMoveListeners = null;
            for (listener in mouseMoveListeners) {
                window.onElementMouseEvent(MouseMove, listener, hitbox);
            }
        }

        final mouseExitListeners = this.mouseExitListeners;
        if (mouseExitListeners != null) {
            this.mouseExitListeners = null;
            for (listener in mouseExitListeners) {
                window.onElementMouseEvent(MouseExited, listener, hitbox);
            }
        }

        final scrollListeners = this.scrollListeners;
        if (scrollListeners != null) {
            this.scrollListeners = null;
            for (listener in scrollListeners) {
                window.onElementMouseEvent(Scroll, listener, hitbox);
            }
        }

        if (hoverStyle != null
            || baseStyle.has(StyleRefinement.MOUSE_CURSOR)
            || cx.activeDrag != null && dragOverStyles != null) {
            final hoverState = hoverStyle != null && elementState != null ? elementState.hoverState : null;
            final currentView = window.currentView();
            // Difference with GPUI: with default view caching (GPUI's own
            // `.cached(style)` keeps GPUI's behaviour), the view is also
            // notified when the hover state it was painted with is stale (GPUI
            // paints the hover state of the hitbox, but only notifies when it
            // differs from `hoverState.element`, which a first frame drawn
            // under the mouse leaves unset: an uncached view is fixed by the
            // next full redraw, a cached one is not).
            final paintedHovered = window.viewCaching && hoverState != null ? (hitbox.isHovered(window) ? 1 : 0) : -1;

            // The listener's state in an entry, without a closure (`Window.HoverListenerEntry`)
            window.onElementHover(hitbox, hoverState, currentView, paintedHovered);
        }

        if (groupHoverStyle != null) {
            final groupHitboxId = GroupHitboxes.get(groupHoverStyle.group, cx);
            if (groupHitboxId != -1) {
                final hoverState = elementState != null ? elementState.hoverState : null;
                final currentView = window.currentView();
                // See the element hover listener above (view caching)
                final paintedGroupHovered = window.viewCaching && hoverState != null ? window.isHitboxIdHovered(groupHitboxId) : null;

                window.onMouseEvent(MouseMove, (_, phase, window, cx) -> {
                    final groupHovered = window.isHitboxIdHovered(groupHitboxId);
                    final wasGroupHovered = hoverState != null && hoverState.group;
                    if (phase == Capture && groupHovered != wasGroupHovered) {
                        if (hoverState != null) {
                            hoverState.group = groupHovered;
                            cx.notify(currentView);
                        }
                    }
                    else if (phase == Capture && paintedGroupHovered != null && groupHovered != paintedGroupHovered) {
                        cx.notify(currentView);
                    }
                });
            }
        }

        final dragCursorStyle:Null<CursorStyle> = baseStyle.has(StyleRefinement.MOUSE_CURSOR) ? baseStyle.mouseCursor : null;

        final dragListener = this.dragListener;
        this.dragListener = null;
        // Taken (Rust `mem::take`): the listeners of an element are painted once
        final dropListeners = this.dropListeners;
        this.dropListeners = null;
        final clickListeners = this.clickListeners != null ? this.clickListeners : NO_CLICK_LISTENERS;
        this.clickListeners = null;
        final auxClickListeners = this.auxClickListeners != null ? this.auxClickListeners : NO_CLICK_LISTENERS;
        this.auxClickListeners = null;
        final canDropPredicate = this.canDropPredicate;
        this.canDropPredicate = null;

        if (dropListeners != null) {
            window.onMouseEvent(MouseUp, (_, phase, window, cx) -> {
                final drag = cx.activeDrag;
                if (drag != null && phase == Bubble && hitbox.isHovered(window)) {
                    for (entry in dropListeners) {
                        if (drag.valueIs(entry.type) && cx.activeDrag == drag) {
                            cx.activeDrag = null;

                            var canDrop = true;
                            if (canDropPredicate != null) {
                                canDrop = canDropPredicate(drag.value, window, cx);
                            }

                            if (canDrop) {
                                entry.listener(drag.value, window, cx);
                                window.refresh();
                                cx.stopPropagation();
                            }
                        }
                    }
                }
            });
        }

        if (elementState != null) {
            if (clickListeners.length > 0 || auxClickListeners.length > 0 || dragListener != null) {
                if (elementState.pendingMouseDown == null) elementState.pendingMouseDown = new Ref(null);
                final pendingMouseDown = elementState.pendingMouseDown;
                if (elementState.pendingKeyboardDown == null) elementState.pendingKeyboardDown = new Ref(null);
                final pendingKeyboardDown = elementState.pendingKeyboardDown;
                if (elementState.clickedState == null) elementState.clickedState = new ElementClickedState();
                final clickedState = elementState.clickedState;

                // The state the three click listeners share (Rust closures), in
                // one object and three listener entries instead of closures
                final clickState = new ClickListenerState(hitbox, pendingMouseDown, clickedState, clickListeners, auxClickListeners, dragListener, dragCursorStyle);
                window.addMouseListenerEntry(new ClickMouseDownEntry(clickState));
                window.addMouseListenerEntry(new ClickMouseMoveEntry(clickState));

                if (isFocused) {
                    // Record the focus generation at which an enter/space key
                    // down event happened on this element. The next key up
                    // event will be mapped to a click event if no other key
                    // events happen in between and the focus did not move.
                    window.onKeyEvent((event, phase, window, _) -> {
                        if (event.kind != KeyDown)
                            return;
                        if (phase.bubble() && !window.defaultPrevented()) {
                            final stroke = (cast event : KeyDownEvent).keystroke;
                            final isActivationKey = (stroke.key == 'enter' || stroke.key == 'space') && !stroke.modifiers.modified();
                            pendingKeyboardDown.value = isActivationKey ? window.focusGeneration : null;
                        }
                    });

                    // Press enter, space to trigger click, when the element is focused.
                    window.onKeyEvent((event, phase, window, cx) -> {
                        if (event.kind != KeyUp)
                            return;
                        if (phase.bubble() && !window.defaultPrevented()) {
                            final stroke = (cast event : KeyUpEvent).keystroke;
                            final keyboardButton:Null<KeyboardButton> = stroke.key == 'enter' ? KeyboardButton.Enter : (stroke.key == 'space' ? KeyboardButton.Space : null);

                            if (keyboardButton != null && !stroke.modifiers.modified()) {
                                final pending = pendingKeyboardDown.value;
                                pendingKeyboardDown.value = null;
                                if (pending == null || pending != window.focusGeneration) {
                                    return;
                                }

                                final clickEvent = ClickEvent.Keyboard(new KeyboardClickEvent(keyboardButton, hitbox.bounds));
                                for (listener in clickListeners) {
                                    listener(clickEvent, window, cx);
                                }
                            }
                            else {
                                // Releasing any other key mid-press means
                                // this isn't a clean activation, so cancel
                                // the pending keydown.
                                pendingKeyboardDown.value = null;
                            }
                        }
                    });
                }

                window.addMouseListenerEntry(new ClickMouseUpEntry(clickState));
            }

            final hoverListener = this.hoverListener;
            this.hoverListener = null;
            if (hoverListener != null) {
                if (elementState.hoverListenerState == null) elementState.hoverListenerState = new Ref(false);
                final wasHovered = elementState.hoverListenerState;
                if (elementState.pendingMouseDown == null) elementState.pendingMouseDown = new Ref(null);
                final hasMouseDown = elementState.pendingMouseDown;
                final updateHover = (isHovered:Bool, window:Window, cx:App) -> {
                    if (isHovered != wasHovered.value) {
                        wasHovered.value = isHovered;
                        hoverListener(isHovered, window, cx);
                    }
                };
                final hoverListenerMode = this.hoverListenerModeValue;

                if (hasMouseDown.value == null) {
                    final isHovered = !cx.hasActiveDrag() && hoverListenerMode.isHovered(hitbox, window);
                    if (isHovered != wasHovered.value) {
                        window.defer(cx, (window, cx) -> updateHover(isHovered, window, cx));
                    }
                }

                window.onMouseEvent(MouseMove, (_, phase, window, cx) -> {
                    if (phase == Bubble) {
                        final isHovered = hasMouseDown.value == null && !cx.hasActiveDrag() && hoverListenerMode.isHovered(hitbox, window);
                        updateHover(isHovered, window, cx);
                    }
                });

                // The pointer can leave the window without a final MouseMove, so also
                // clear hover on MouseExited.
                window.onMouseEvent(MouseExited, (_, phase, window, cx) -> {
                    if (phase == Bubble) {
                        updateHover(false, window, cx);
                    }
                });
            }

            final tooltipBuilder = this.tooltipBuilder;
            this.tooltipBuilder = null;
            if (tooltipBuilder != null) {
                if (elementState.activeTooltip == null) elementState.activeTooltip = new ActiveTooltipCell();
                final activeTooltip = elementState.activeTooltip;
                if (elementState.pendingMouseDown == null) elementState.pendingMouseDown = new Ref(null);
                final pendingMouseDown = elementState.pendingMouseDown;
                if (elementState.longPressTooltipActive == null) elementState.longPressTooltipActive = new Ref(false);
                final longPressTooltipActive = elementState.longPressTooltipActive;

                final tooltipIsHoverable = tooltipBuilder.hoverable;
                final buildTooltip = (window:Window, cx:App) -> {view: tooltipBuilder.build(window, cx), hoverable: tooltipIsHoverable};
                // Use bounds instead of testing hitbox since this is called during prepaint.
                final sourceBounds = hitbox.bounds;
                final checkIsHoveredDuringPrepaint = (window:Window) -> {
                    return !window.lastInputWasKeyboard() && pendingMouseDown.value == null && sourceBounds.contains(window.mousePosition());
                };
                final checkIsHovered = (window:Window) -> {
                    return pendingMouseDown.value == null && hitbox.isHovered(window);
                };
                registerTooltipMouseHandlers(activeTooltip, tooltipId, buildTooltip, checkIsHovered, checkIsHoveredDuringPrepaint, longPressTooltipActive, tooltipShowDelay, window);
            }

            // We unconditionally bind both the mouse up and mouse down active state handlers
            // Because we might not get a chance to render a frame before the mouse up event arrives.
            if (elementState.clickedState == null) elementState.clickedState = new ElementClickedState();
            final activeState = elementState.clickedState;

            // In entries, without closures (`ActiveMouseUpEntry`, `ActiveMouseDownEntry`)
            window.addMouseListenerEntry(new ActiveMouseUpEntry(activeState));

            final activeGroupHitbox = groupActiveStyle != null ? GroupHitboxes.get(groupActiveStyle.group, cx) : -1;
            window.addMouseListenerEntry(new ActiveMouseDownEntry(activeState, activeGroupHitbox, hitbox));
        }
    }

    function paintKeyboardListeners(window:Window, cx:App):Void {
        if (keyContext != null) {
            window.setKeyContext(keyContext);
        }

        final keyDownListeners = this.keyDownListeners;
        if (keyDownListeners != null) {
            this.keyDownListeners = null;
            for (listener in keyDownListeners) {
                window.onKeyEvent((event, phase, window, cx) -> {
                    if (event.kind == KeyDown) listener(cast event, phase, window, cx);
                });
            }
        }

        final keyUpListeners = this.keyUpListeners;
        if (keyUpListeners != null) {
            this.keyUpListeners = null;
            for (listener in keyUpListeners) {
                window.onKeyEvent((event, phase, window, cx) -> {
                    if (event.kind == KeyUp) listener(cast event, phase, window, cx);
                });
            }
        }

        final modifiersChangedListeners = this.modifiersChangedListeners;
        if (modifiersChangedListeners != null) {
            this.modifiersChangedListeners = null;
            for (listener in modifiersChangedListeners) {
                window.onModifiersChanged(listener);
            }
        }

        final actionListeners = this.actionListeners;
        if (actionListeners != null) {
            this.actionListeners = null;
            for (entry in actionListeners) {
                @:privateAccess window.onActionEntry(entry);
            }
        }
    }

    function paintHoverGroupHandler(window:Window, cx:App):Void {
        final groupHitbox = groupHoverStyle != null ? GroupHitboxes.get(groupHoverStyle.group, cx) : -1;

        if (groupHitbox != -1) {
            final wasHovered = window.isHitboxIdHovered(groupHitbox);
            final currentView = window.currentView();
            window.onMouseEvent(MouseMove, (_, phase, window, cx) -> {
                final hovered = window.isHitboxIdHovered(groupHitbox);
                if (phase == Capture && hovered != wasHovered) {
                    cx.notify(currentView);
                }
            });
        }
    }

    function paintScrollListener(hitbox:Hitbox, style:Style, window:Window, cx:App):Void {
        final scrollOffset = this.scrollOffset;
        if (scrollOffset == null)
            return;

        final ongoingScroll = this.ongoingScroll;
        final overflowX = style.overflowX;
        final overflowY = style.overflowY;
        final allowConcurrentScroll = style.allowConcurrentScroll;
        final restrictScrollToAxis = style.restrictScrollToAxis;
        final lineHeight = window.lineHeight();
        final currentView = window.currentView();
        window.onMouseEvent(Scroll, (event, phase, window, cx) -> {
            if (phase == Bubble && hitbox.shouldHandleScroll(window)) {
                final event:ScrollEvent = cast event;
                final oldScrollOffset = scrollOffset.value;
                var delta = event.delta.pixelDelta(lineHeight);

                if (restrictScrollToAxis && event.delta.precise() && ongoingScroll != null) {
                    delta = ongoingScroll.filter(delta, event.touchPhase, cx.backgroundExecutor().now());
                }

                var deltaX:Float = if (overflowX == Scroll && delta.x != 0) {
                    delta.x;
                }
                else if (overflowX == Scroll && !restrictScrollToAxis && overflowY != Scroll) {
                    delta.y;
                }
                else {
                    0.0;
                }
                var deltaY:Float = if (overflowY == Scroll && delta.y != 0) {
                    delta.y;
                }
                else if (overflowY == Scroll && !restrictScrollToAxis && overflowX != Scroll) {
                    delta.x;
                }
                else {
                    0.0;
                }
                if (!allowConcurrentScroll && deltaX != 0 && deltaY != 0) {
                    if (Math.abs(deltaX) > Math.abs(deltaY)) {
                        deltaY = 0.0;
                    }
                    else {
                        deltaX = 0.0;
                    }
                }
                final newOffset = new Point(oldScrollOffset.x + deltaX, oldScrollOffset.y + deltaY);
                scrollOffset.value = newOffset;
                if (!newOffset.equals(oldScrollOffset)) {
                    cx.notify(currentView);
                }
            }
        });
    }

    /**
     * Compute the visual style for this element, based on the current bounds and the element's state.
     */
    public function computeStyle(globalId:Null<GlobalElementId>, hitbox:Null<Hitbox>, window:Window, cx:App):Style {
        return computeStyleInternal(hitbox, interactiveElementState(globalId, window), window, cx);
    }

    /** Bits of the refinements `computeStyleInternal` applies (`computedStyleKey`) */
    static inline final STYLE_IN_FOCUS:Int = 1;
    static inline final STYLE_FOCUS:Int = 2;
    static inline final STYLE_FOCUS_VISIBLE:Int = 4;
    static inline final STYLE_GROUP_HOVER:Int = 8;
    static inline final STYLE_HOVER:Int = 16;
    static inline final STYLE_GROUP_ACTIVE:Int = 32;
    static inline final STYLE_ACTIVE:Int = 64;

    /**
     * The style computed last by `computeStyleInternal` (requested layout,
     * prepaint and paint each compute one), reused while the same
     * refinements apply, or null.
     */
    var computedStyle:Null<Style> = null;

    /** The refinements applied to `computedStyle` (`STYLE_*` bits) */
    var computedStyleKey:Int = 0;

    /**
     * Forgets the style computed by the last phase: an element that changes
     * the style it was given (`Img` sizes itself from its image) calls it,
     * so the next phase computes a fresh one like GPUI does.
     */
    @:allow(glaze)
    inline function forgetComputedStyle():Void {
        computedStyle = null;
    }

    /**
     * Rust `compute_style_internal`. GPUI computes a new style in each phase
     * (request layout, prepaint, paint), and its inputs can change between
     * them (paint reads the hitbox prepaint just inserted). The port first
     * evaluates which refinements apply, in GPUI's order, and returns the
     * style of the previous phase when it applied the same ones (the
     * refinements of an element do not change while it is drawn). The drag
     * over styles (a style built by a closure) are always computed again.
     */
    function computeStyleInternal(hitbox:Null<Hitbox>, elementState:Null<InteractiveElementState>, window:Window, cx:App):Style {
        var key = 0;
        if (trackedFocusHandle != null) {
            if (inFocusStyle != null && trackedFocusHandle.withinFocused(window, cx)) {
                key |= STYLE_IN_FOCUS;
            }

            if (focusStyle != null && trackedFocusHandle.isFocused(window)) {
                key |= STYLE_FOCUS;
            }

            if (focusVisibleStyle != null && trackedFocusHandle.isFocused(window) && window.lastInputWasKeyboard()) {
                key |= STYLE_FOCUS_VISIBLE;
            }
        }

        if (!cx.hasActiveDrag()) {
            if (groupHoverStyle != null) {
                final groupHitboxId = GroupHitboxes.get(groupHoverStyle.group, cx);
                final isGroupHovered = if (groupHitboxId != -1) {
                    !window.lastInputWasTouch() && window.isHitboxIdHovered(groupHitboxId);
                }
                else if (elementState != null) {
                    !window.lastInputWasTouch() && elementState.hoverState != null && elementState.hoverState.group;
                }
                else {
                    false;
                }

                if (isGroupHovered) {
                    key |= STYLE_GROUP_HOVER;
                }
            }

            if (hoverStyle != null) {
                final isHovered = if (hitbox != null) {
                    !window.lastInputWasTouch() && hitbox.isHovered(window);
                }
                else if (elementState != null) {
                    !window.lastInputWasTouch() && elementState.hoverState != null && elementState.hoverState.element;
                }
                else {
                    false;
                }

                if (isHovered) {
                    key |= STYLE_HOVER;
                }
            }
        }

        final drag = hitbox != null ? cx.activeDrag : null;

        if (elementState != null) {
            if (elementState.clickedState == null) elementState.clickedState = new ElementClickedState();
            final clickedState = elementState.clickedState;
            if (clickedState.group && groupActiveStyle != null) {
                key |= STYLE_GROUP_ACTIVE;
            }

            if (activeStyle != null && clickedState.element) {
                key |= STYLE_ACTIVE;
            }
        }

        if (drag == null && computedStyle != null && computedStyleKey == key) {
            return computedStyle;
        }

        final style = new Style();
        style.refine(baseStyle);

        if (key & STYLE_IN_FOCUS != 0) style.refine(inFocusStyle);
        if (key & STYLE_FOCUS != 0) style.refine(focusStyle);
        if (key & STYLE_FOCUS_VISIBLE != 0) style.refine(focusVisibleStyle);
        if (key & STYLE_GROUP_HOVER != 0) style.refine(groupHoverStyle.style);
        if (key & STYLE_HOVER != 0) style.refine(hoverStyle);

        if (drag != null) {
            cx.activeDrag = null;
            var canDrop = true;
            if (canDropPredicate != null) {
                canDrop = canDropPredicate(drag.value, window, cx);
            }

            if (canDrop) {
                if (groupDragOverStyles != null) for (entry in groupDragOverStyles) {
                    final groupHitboxId = GroupHitboxes.get(entry.style.group, cx);
                    if (groupHitboxId != -1 && drag.valueIs(entry.type) && window.isHitboxIdHovered(groupHitboxId)) {
                        style.refine(entry.style.style);
                    }
                }

                if (dragOverStyles != null) for (entry in dragOverStyles) {
                    if (drag.valueIs(entry.type) && hitbox.isHovered(window)) {
                        style.refine(entry.build(drag.value, window, cx));
                    }
                }
            }

            if (drag.cursorStyle != null) {
                style.mouseCursor = drag.cursorStyle;
                style.optionMask |= StyleRefinement.MOUSE_CURSOR;
            }
            else {
                style.optionMask &= ~StyleRefinement.MOUSE_CURSOR;
            }
            cx.activeDrag = drag;
        }

        if (key & STYLE_GROUP_ACTIVE != 0) style.refine(groupActiveStyle.style);
        if (key & STYLE_ACTIVE != 0) style.refine(activeStyle);

        computedStyle = drag == null ? style : null;
        computedStyleKey = key;
        return style;
    }

/// Tooltips

    static function setTooltipOnWindow(activeTooltip:ActiveTooltipCell, window:Window):Int {
        final value = activeTooltip.value;
        if (value == null)
            return -1;
        return switch value {
            case WaitingForShow(_): -1;
            case Visible(tooltip, _): window.setTooltip(tooltip);
            case WaitingForHide(tooltip, _): window.setTooltip(tooltip);
        }
    }

    static function clearActiveTooltip(activeTooltip:ActiveTooltipCell, window:Window):Void {
        final value = activeTooltip.value;
        if (value == null)
            return;
        activeTooltip.take();
        switch value {
            case WaitingForShow(_):
            case Visible(_, _) | WaitingForHide(_, _): window.refresh();
        }
    }

    static function clearActiveTooltipIfNotHoverable(activeTooltip:ActiveTooltipCell, window:Window):Void {
        final value = activeTooltip.value;
        final shouldClear = value != null && switch value {
            case Visible(_, isHoverable): !isHoverable;
            case _: false;
        }
        if (shouldClear) {
            activeTooltip.take();
            window.refresh();
        }
    }

    static function registerTooltipMouseHandlers(
        activeTooltip:ActiveTooltipCell,
        tooltipId:Int,
        buildTooltip:(Window, App) -> {view:AnyView, hoverable:Bool},
        checkIsHovered:(Window) -> Bool,
        checkIsHoveredDuringPrepaint:(Window) -> Bool,
        longPressTooltipActive:Ref<Bool>,
        showDelay:Null<Float>,
        window:Window
    ):Void {
        final currentView = window.currentView();
        final showDelay:Float = showDelay != null ? showDelay : DEFAULT_TOOLTIP_SHOW_DELAY;

        window.onMouseEvent(MouseMove, (_, phase, window, cx) -> {
            handleTooltipMouseMove(activeTooltip, buildTooltip, checkIsHovered, checkIsHoveredDuringPrepaint, tooltipId, currentView, phase, showDelay, window, cx);
        });

        window.onMouseEvent(MouseDown, (_, _, window, _) -> {
            if (!(tooltipId != -1 && window.isTooltipHovered(tooltipId))) {
                clearActiveTooltipIfNotHoverable(activeTooltip, window);
            }
        });

        // Touch long presses show the tooltip immediately once the gesture
        // is recognized, until the finger lifts.
        window.onMouseEvent(LongPress, (e, phase, window, cx) -> {
            if (!phase.bubble())
                return;
            final event:LongPressEvent = cast e;
            switch event.phase {
                case Started if (!window.defaultPrevented() && checkIsHovered(window)):
                    if (showTooltip(activeTooltip, buildTooltip, checkIsHoveredDuringPrepaint, longPressTooltipActive, window, cx)) {
                        longPressTooltipActive.value = true;
                        window.preventDefault();
                        cx.stopPropagation();
                    }
                case Ended | Cancelled if (longPressTooltipActive.value):
                    longPressTooltipActive.value = false;
                    clearActiveTooltip(activeTooltip, window);
                    cx.stopPropagation();
                case _:
            }
        });

        window.onMouseEvent(Scroll, (_, _, window, _) -> {
            if (!(tooltipId != -1 && window.isTooltipHovered(tooltipId))) {
                clearActiveTooltipIfNotHoverable(activeTooltip, window);
            }
        });
    }

    static function handleTooltipMouseMove(
        activeTooltip:ActiveTooltipCell,
        buildTooltip:(Window, App) -> {view:AnyView, hoverable:Bool},
        checkIsHovered:(Window) -> Bool,
        checkIsHoveredDuringPrepaint:(Window) -> Bool,
        tooltipId:Int,
        currentView:Int,
        phase:DispatchPhase,
        showDelay:Float,
        window:Window,
        cx:App
    ):Void {
        // 0: None, 1: CancelShow, 2: ScheduleShow, 3: CheckVisible
        final value = activeTooltip.value;
        final action = if (value == null) {
            (checkIsHovered(window) && phase.bubble()) ? 2 : 0;
        }
        else switch value {
            case WaitingForShow(_):
                checkIsHovered(window) ? 0 : 1;
            case Visible(_, isHoverable):
                (phase.capture()
                    && !checkIsHovered(window)
                    && (!isHoverable || !(tooltipId != -1 && window.isTooltipHovered(tooltipId)))) ? 3 : 0;
            case WaitingForHide(_, _):
                (phase.capture()
                    && (checkIsHovered(window) || (tooltipId != -1 && window.isTooltipHovered(tooltipId)))) ? 3 : 0;
        }

        switch action {
            case 1:
                // Cancel waiting to show tooltip when it is no longer hovered.
                activeTooltip.take();
            case 2:
                final timer = cx.backgroundExecutor().timer(showDelay);
                timer.then(_ -> {
                    if (!activeTooltip.alive || window.isDestroyed())
                        return;
                    cx.update(cx -> {
                        showTooltip(activeTooltip, buildTooltip, checkIsHoveredDuringPrepaint, null, window, cx);
                    });
                });
                activeTooltip.set(WaitingForShow(timer));
            case 3:
                cx.notify(currentView);
            case _:
        }
    }

    static function showTooltip(
        activeTooltip:ActiveTooltipCell,
        buildTooltip:(Window, App) -> {view:AnyView, hoverable:Bool},
        checkIsHoveredDuringPrepaint:(Window) -> Bool,
        longPressTooltipActive:Null<Ref<Bool>>,
        window:Window,
        cx:App
    ):Bool {
        final built = buildTooltip(window, cx);
        var newTooltip:Null<ActiveTooltip> = null;
        if (built != null) {
            final tooltipIsHoverable = built.hoverable;
            newTooltip = Visible(new AnyTooltip(built.view, window.mousePosition(), (tooltipBounds, window, cx) -> {
                if (longPressTooltipActive != null && longPressTooltipActive.value) {
                    return true;
                }
                if (!activeTooltip.alive) {
                    return false;
                }
                return handleTooltipCheckVisibleAndUpdate(activeTooltip, tooltipIsHoverable, checkIsHoveredDuringPrepaint, tooltipBounds, window, cx);
            }), tooltipIsHoverable);
        }
        final didShow = newTooltip != null;
        // The waiting task is the one running: replacing it must not cancel anything else
        activeTooltip.set(newTooltip);
        window.refresh();
        return didShow;
    }

    static function handleTooltipCheckVisibleAndUpdate(
        activeTooltip:ActiveTooltipCell,
        tooltipIsHoverable:Bool,
        checkIsHovered:(Window) -> Bool,
        tooltipBounds:Bounds,
        window:Window,
        cx:App
    ):Bool {
        final isHovered = checkIsHovered(window) || (tooltipIsHoverable && tooltipBounds.contains(window.mousePosition()));
        final value = activeTooltip.value;
        if (value != null) {
            switch value {
                case Visible(tooltip, _):
                    if (!isHovered) {
                        if (tooltipIsHoverable) {
                            // Schedule hide
                            final timer = cx.backgroundExecutor().timer(HOVERABLE_TOOLTIP_HIDE_DELAY);
                            timer.then(_ -> {
                                if (!activeTooltip.alive || window.isDestroyed())
                                    return;
                                if (activeTooltip.take()) {
                                    cx.update(_ -> window.refresh());
                                }
                            });
                            activeTooltip.set(WaitingForHide(tooltip, timer));
                        }
                        else {
                            clearActiveTooltip(activeTooltip, window);
                        }
                    }
                case WaitingForHide(tooltip, _):
                    if (isHovered) {
                        // Cancel waiting to hide tooltip when it becomes hovered.
                        activeTooltip.set(Visible(tooltip, true));
                    }
                case WaitingForShow(_):
            }
        }

        return activeTooltip.isSome();
    }

}

/**
 * The hitboxes of the groups being painted (Rust global `GroupHitboxes`):
 * a stack per group name, so nested groups of the same name resolve to the
 * innermost one.
 */
class GroupHitboxes {

    /**
     * The hitbox of the innermost group with the given name being painted, or -1.
     */
    public static function get(name:String, cx:App):Int {
        final stack = cx.groupHitboxes.get(name);
        return stack != null && stack.length > 0 ? stack[stack.length - 1] : -1;
    }

    public static function push(name:String, hitboxId:Int, cx:App):Void {
        var stack = cx.groupHitboxes.get(name);
        if (stack == null) {
            stack = [];
            cx.groupHitboxes.set(name, stack);
        }
        stack.push(hitboxId);
    }

    public static function pop(name:String, cx:App):Void {
        final stack = cx.groupHitboxes.get(name);
        if (stack != null) {
            Stacks.drop(stack);
        }
    }

}

/**
 * The state of the click listeners of an element for one frame (what the
 * listeners of `Interactivity.paintMouseListeners` capture in Rust).
 */
private class ClickListenerState {

    public final hitbox:Hitbox;

    public final pendingMouseDown:Ref<Null<MouseDownEvent>>;

    public final clickedState:ElementClickedState;

    public final clickListeners:Array<(ClickEvent, Window, App) -> Void>;

    public final auxClickListeners:Array<(ClickEvent, Window, App) -> Void>;

    public final hasAuxClickListeners:Bool;

    /** The drag listener, until a drag starts */
    public var dragListenerLeft:Null<DragListener>;

    public final dragCursorStyle:Null<CursorStyle>;

    /** The mouse down taken in the capture phase of a mouse up */
    public var capturedMouseDown:Null<MouseDownEvent> = null;

    public function new(hitbox:Hitbox, pendingMouseDown:Ref<Null<MouseDownEvent>>, clickedState:ElementClickedState,
            clickListeners:Array<(ClickEvent, Window, App) -> Void>, auxClickListeners:Array<(ClickEvent, Window, App) -> Void>,
            dragListener:Null<DragListener>, dragCursorStyle:Null<CursorStyle>) {
        this.hitbox = hitbox;
        this.pendingMouseDown = pendingMouseDown;
        this.clickedState = clickedState;
        this.clickListeners = clickListeners;
        this.auxClickListeners = auxClickListeners;
        this.hasAuxClickListeners = auxClickListeners.length > 0;
        this.dragListenerLeft = dragListener;
        this.dragCursorStyle = dragCursorStyle;
    }

}

/**
 * The mouse down listener of a focusable element: transfers the focus when
 * the element is hit (`Interactivity.paintMouseListeners`)
 */
private class FocusMouseDownEntry extends glaze.Window.MouseListenerEntry {

    final focusHandle:FocusHandle;

    public function new(hitbox:Hitbox, focusHandle:FocusHandle) {
        // The hitbox of the entry (no element listener: `call` is overridden)
        super(MouseDown, null, null, hitbox);
        this.focusHandle = focusHandle;
    }

    override function call(event:PlatformInput, phase:DispatchPhase, window:Window, cx:App):Void {
        if (phase == Bubble && hitbox.isHovered(window) && !window.defaultPrevented()) {
            window.focus(focusHandle, cx);
            // If there is a parent that is also focusable, prevent it
            // from transferring focus because we already did so.
            window.preventDefault();
        }
    }

}

/** The mouse up listener of an element's active state (`Interactivity.paintMouseListeners`) */
private class ActiveMouseUpEntry extends glaze.Window.MouseListenerEntry {

    final activeState:ElementClickedState;

    public function new(activeState:ElementClickedState) {
        super(MouseUp, null, null, null);
        this.activeState = activeState;
    }

    override function call(event:PlatformInput, phase:DispatchPhase, window:Window, cx:App):Void {
        if (phase == Capture && activeState.isClicked()) {
            activeState.reset();
            window.refresh();
        }
    }

}

/** The mouse down listener of an element's active state (`Interactivity.paintMouseListeners`) */
private class ActiveMouseDownEntry extends glaze.Window.MouseListenerEntry {

    final activeState:ElementClickedState;

    final activeGroupHitbox:Int;

    public function new(activeState:ElementClickedState, activeGroupHitbox:Int, hitbox:Hitbox) {
        super(MouseDown, null, null, hitbox);
        this.activeState = activeState;
        this.activeGroupHitbox = activeGroupHitbox;
    }

    override function call(event:PlatformInput, phase:DispatchPhase, window:Window, cx:App):Void {
        if (phase == Bubble && !window.defaultPrevented()) {
            final groupHovered = activeGroupHitbox != -1 && window.isHitboxIdHovered(activeGroupHitbox);
            final elementHovered = hitbox.isHovered(window);
            if (groupHovered || elementHovered) {
                activeState.group = groupHovered;
                activeState.element = elementHovered;
                window.refresh();
            }
        }
    }

}

private class ClickMouseDownEntry extends glaze.Window.MouseListenerEntry {

    final state:ClickListenerState;

    public function new(state:ClickListenerState) {
        super(MouseDown, null, null, null);
        this.state = state;
    }

    override function call(event:PlatformInput, phase:DispatchPhase, window:Window, cx:App):Void {
        final event:MouseDownEvent = cast event;
        if (phase == Bubble && (event.button == Left || state.hasAuxClickListeners) && state.hitbox.isHovered(window)) {
            state.pendingMouseDown.value = event;
            window.refresh();
        }
    }

}

private class ClickMouseMoveEntry extends glaze.Window.MouseListenerEntry {

    final state:ClickListenerState;

    public function new(state:ClickListenerState) {
        super(MouseMove, null, null, null);
        this.state = state;
    }

    override function call(event:PlatformInput, phase:DispatchPhase, window:Window, cx:App):Void {
        if (phase == Capture) {
            return;
        }

        final event:MouseMoveEvent = cast event;
        final state = this.state;
        final mouseDown = state.pendingMouseDown.value;
        if (mouseDown != null
            && !cx.hasActiveDrag()
            && event.position.sub(mouseDown.position).magnitude() > @:privateAccess Interactivity.DRAG_THRESHOLD
            && state.dragListenerLeft != null
            && mouseDown.button == Left) {
            final listener = state.dragListenerLeft;
            state.dragListenerLeft = null;
            state.clickedState.reset();
            final cursorOffset = event.position.sub(state.hitbox.origin);
            final drag = listener.render(listener.value, cursorOffset, window, cx);
            cx.activeDrag = new AnyDrag(drag, listener.value, cursorOffset, state.dragCursorStyle);
            state.pendingMouseDown.value = null;
            window.refresh();
            cx.stopPropagation();
        }
    }

}

private class ClickMouseUpEntry extends glaze.Window.MouseListenerEntry {

    final state:ClickListenerState;

    public function new(state:ClickListenerState) {
        super(MouseUp, null, null, null);
        this.state = state;
    }

    override function call(event:PlatformInput, phase:DispatchPhase, window:Window, cx:App):Void {
        final state = this.state;
        final pendingMouseDown = state.pendingMouseDown;
        switch phase {
            // Clear the pending mouse down during the capture phase,
            // so that it happens even if another event handler stops
            // propagation.
            case Capture:
                if (pendingMouseDown.value != null && state.hitbox.isHovered(window)) {
                    state.capturedMouseDown = pendingMouseDown.value;
                    pendingMouseDown.value = null;
                    window.refresh();
                }
                else if (pendingMouseDown.value != null) {
                    // Clear the pending mouse down event (without firing click handlers)
                    // if the hitbox is not being hovered.
                    pendingMouseDown.value = null;
                    window.refresh();
                }
            // Fire click handlers during the bubble phase.
            case Bubble:
                final mouseDown = state.capturedMouseDown;
                if (mouseDown != null) {
                    state.capturedMouseDown = null;
                    final mouseClick = ClickEvent.Mouse(new MouseClickEvent(mouseDown, cast event));
                    if (mouseDown.button == Left) {
                        for (listener in state.clickListeners) {
                            listener(mouseClick, window, cx);
                        }
                    }
                    else {
                        for (listener in state.auxClickListeners) {
                            listener(mouseClick, window, cx);
                        }
                    }
                }
        }
    }

}
