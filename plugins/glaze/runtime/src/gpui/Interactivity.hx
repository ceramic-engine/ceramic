// Ported from gpui-pre 0.3.10: src/elements/div.rs (`Interactivity`, `InteractiveElementState`, tooltips, `GroupHitboxes`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.ClickEvent.KeyboardClickEvent;
import gpui.ClickEvent.MouseClickEvent;
import gpui.util.Ref;

/**
 * A mouse listener of an element: called with the event, the phase and the
 * element's hitbox (Rust `MouseDownListener`, `MouseUpListener`...).
 */
typedef ElementMouseListener = (event:PlatformInput, phase:DispatchPhase, hitbox:Hitbox, window:Window, cx:App) -> Void;

/**
 * A style applied when a group is hovered, active or dragged over.
 */
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
 * Rust `TypeId`s. Touch, pinch, pressure, back gesture, file drop,
 * accessibility, inspector and window control areas are not ported.
 * `restrictScrollToAxis` locks precise deltas with `OngoingScroll`, whose
 * gesture separation reads the executor clock instead of the wall clock.
 */
class Interactivity {

    static inline final DRAG_THRESHOLD:Float = 2.0;

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

    public var contentSize:Size = new Size(0, 0);

    public var keyContext:Null<KeyContext> = null;

    public var focusable:Bool = false;

    public var trackedFocusHandle:Null<FocusHandle> = null;

    public var trackedScrollHandle:Null<ScrollHandle> = null;

    public var scrollAnchor:Null<ScrollAnchor> = null;

    public var scrollOffset:Null<Ref<Point>> = null;

    public var ongoingScroll:Null<OngoingScroll> = null;

    public var group:Null<String> = null;

    /** The base style of the element, before any modifications are applied by focus, active, etc. */
    #if gpui_inspector
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

    public final dragOverStyles:Array<{type:Class<Dynamic>, build:(Dynamic, Window, App) -> StyleRefinement}> = [];

    public final groupDragOverStyles:Array<{type:Class<Dynamic>, style:GroupStyle}> = [];

    public final mouseDownListeners:Array<ElementMouseListener> = [];

    public final mouseUpListeners:Array<ElementMouseListener> = [];

    public final mouseMoveListeners:Array<ElementMouseListener> = [];

    public final mouseExitListeners:Array<ElementMouseListener> = [];

    public final scrollListeners:Array<ElementMouseListener> = [];

    public final keyDownListeners:Array<(KeyDownEvent, DispatchPhase, Window, App) -> Void> = [];

    public final keyUpListeners:Array<(KeyUpEvent, DispatchPhase, Window, App) -> Void> = [];

    public final modifiersChangedListeners:Array<(ModifiersChangedEvent, Window, App) -> Void> = [];

    public final actionListeners:Array<{type:Class<Dynamic>, listener:(Action, DispatchPhase, Window, App) -> Void}> = [];

    public final dropListeners:Array<{type:Class<Dynamic>, listener:(Dynamic, Window, App) -> Void}> = [];

    public var canDropPredicate:Null<(Dynamic, Window, App) -> Bool> = null;

    public final clickListeners:Array<(ClickEvent, Window, App) -> Void> = [];

    public final auxClickListeners:Array<(ClickEvent, Window, App) -> Void> = [];

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

    #if gpui_inspector
    /** Where the element was built (Rust `source_location`, captured by `div()`, `img()` and `svg()`) */
    public var sourceLocation:Null<haxe.PosInfos> = null;
    #end

    public function new() {}

/// Listener registration

    /**
     * Bind the given callback to the mouse down event for the given mouse button, during the bubble phase.
     */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Void {
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
        actionListeners.push({
            type: type,
            listener: (action, phase, window, cx) -> {
                if (phase == Capture) {
                    listener(cast action, window, cx);
                }
                else {
                    cx.propagate();
                }
            }
        });
    }

    /**
     * Bind the given callback to an action dispatch during the bubble phase.
     */
    public function onAction<A:Action>(type:Class<A>, listener:(A, Window, App) -> Void):Void {
        actionListeners.push({
            type: type,
            listener: (action, phase, window, cx) -> {
                if (phase == Bubble) {
                    listener(cast action, window, cx);
                }
            }
        });
    }

    /**
     * Bind the given callback to an action dispatch, based on a dynamic action parameter
     * instead of a type parameter. Useful for component libraries that want to expose
     * action bindings to their users.
     */
    public function onBoxedAction(action:Action, listener:(Action, Window, App) -> Void):Void {
        final action = action.boxedClone();
        actionListeners.push({
            type: Type.getClass(action),
            listener: (_, phase, window, cx) -> {
                if (phase == Bubble) {
                    listener(action, window, cx);
                }
            }
        });
    }

    /**
     * Bind the given callback to a key down event, during the bubble phase.
     */
    public function onKeyDown(listener:(KeyDownEvent, Window, App) -> Void):Void {
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
        modifiersChangedListeners.push(listener);
    }

    /**
     * Bind the given callback to drop events of the given type, whether or not the drag started on this element.
     */
    public function onDrop<T>(type:Class<T>, listener:(T, Window, App) -> Void):Void {
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
        clickListeners.push(listener);
    }

    /**
     * Bind the given callback to non-primary click events of this element.
     */
    public function onAuxClick(listener:(ClickEvent, Window, App) -> Void):Void {
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
    public function requestLayout(globalId:Null<GlobalElementId>, #if gpui_inspector inspectorId:Null<InspectorElementId>, #end window:Window, cx:App, f:(Style, Window, App) -> LayoutId):LayoutId {
        #if gpui_inspector
        window.withInspectorState(inspectorId, DivInspectorState, cx, (inspectorState, _window) -> {
            if (inspectorState.value != null) {
                baseStyle = inspectorState.value.baseStyle.clone();
            }
            else {
                inspectorState.value = new DivInspectorState(baseStyle.clone(), new Bounds(new Point(0, 0), new Size(0, 0)), new Size(0, 0));
            }
            return null;
        });
        #end

        return window.withOptionalElementState(globalId, InteractiveElementState, (box, window) -> {
            var elementState:Null<InteractiveElementState> = null;
            if (box != null) {
                if (box.value == null) box.value = new InteractiveElementState();
                elementState = box.value;
            }

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

            final style = computeStyleInternal(null, elementState, window, cx);
            return f(style, window, cx);
        });
    }

    /**
     * Commit the bounds of this element according to this interactivity state's configured styles.
     * `f` gets the style, the scroll offset to apply to the children and the hitbox.
     */
    public function prepaint<R>(globalId:Null<GlobalElementId>, #if gpui_inspector inspectorId:Null<InspectorElementId>, #end bounds:Bounds, contentSize:Size, window:Window, cx:App, f:(Style, Point, Null<Hitbox>, Window, App) -> R):R {
        this.contentSize = contentSize;

        #if gpui_inspector
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

        return window.withOptionalElementState(globalId, InteractiveElementState, (box, window) -> {
            var elementState:Null<InteractiveElementState> = null;
            if (box != null) {
                if (box.value == null) box.value = new InteractiveElementState();
                elementState = box.value;
            }
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
                        elementState.activeTooltip.take();
                    }
                }
            }

            final textStyle = style.textStyle();
            if (textStyle != null) window.pushTextStyle(textStyle);
            final mask = style.overflowMask(bounds, window.remSize());
            if (mask != null) window.pushContentMask(mask);

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

            final result = f(style, scrollOffset, hitbox, window, cx);

            if (pushedGroup) {
                window.prepaintGroupHitboxes.pop();
            }
            window.prepaintOpacity = previousPrepaintOpacity;

            if (mask != null) window.popContentMask();
            if (textStyle != null) window.popTextStyle();
            return result;
        });
    }

    function shouldInsertHitbox(style:Style, window:Window, cx:App):Bool {
        #if gpui_inspector
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
            || mouseUpListeners.length > 0
            || mouseDownListeners.length > 0
            || mouseMoveListeners.length > 0
            || mouseExitListeners.length > 0
            || clickListeners.length > 0
            || auxClickListeners.length > 0
            || scrollListeners.length > 0
            || dragListener != null
            || dropListeners.length > 0
            || dragOverStyles.length > 0
            || tooltipBuilder != null;
    }

    function clampScrollPosition(bounds:Bounds, style:Style, window:Window, cx:App):Point {
        inline function roundToTwoDecimals(pixels:Float):Float {
            return gpui.util.MathUtil.round(pixels * 100.0) / 100.0;
        }

        if (scrollOffset == null) {
            return new Point(0, 0);
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
        final paddingLeft = window.pixelSnap(style.paddingLeft.toPixels(AbsoluteLength.Pixels(bounds.size.width), remSize));
        final paddingRight = window.pixelSnap(style.paddingRight.toPixels(AbsoluteLength.Pixels(bounds.size.width), remSize));
        final paddingTop = window.pixelSnap(style.paddingTop.toPixels(AbsoluteLength.Pixels(bounds.size.height), remSize));
        final paddingBottom = window.pixelSnap(style.paddingBottom.toPixels(AbsoluteLength.Pixels(bounds.size.height), remSize));
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
        return gpui.util.MathUtil.totalLess(value, min) ? min : (gpui.util.MathUtil.totalLess(max, value) ? max : value);
    }

    /**
     * Paint this element according to this interactivity state's configured styles
     * and bind the element's mouse and keyboard events.
     *
     * `paintContent` paints the content of the element (children) between the
     * background and the border, inside its content mask.
     */
    public function paint(globalId:Null<GlobalElementId>, #if gpui_inspector inspectorId:Null<InspectorElementId>, #end bounds:Bounds, hitbox:Null<Hitbox>, window:Window, cx:App, paintContent:(Style, Window, App) -> Void):Void {
        hovered = hitbox != null ? hitbox.isHovered(window) : null;
        window.withOptionalElementState(globalId, InteractiveElementState, (box, window) -> {
            var elementState:Null<InteractiveElementState> = null;
            if (box != null) {
                if (box.value == null) box.value = new InteractiveElementState();
                elementState = box.value;
            }

            final style = computeStyleInternal(hitbox, elementState, window, cx);

            paintHoverGroupHandler(window, cx);

            if (style.visibility == Visibility.Hidden) {
                return null;
            }

            final tabGroupIndex:Null<Int> = tabGroup ? tabIndex : null;

            final hasOpacity = style.isSome(StyleRefinement.OPACITY);
            final previousOpacity = hasOpacity ? window.pushElementOpacity(style.opacity) : 0.0;

            final cornerRadii = style.paintBackground(bounds, window, cx);

            final textStyle = style.textStyle();
            if (textStyle != null) window.pushTextStyle(textStyle);
            final mask = style.overflowMask(bounds, window.remSize());
            if (mask != null) window.pushContentMask(mask);

            window.withTabGroup(tabGroupIndex, window -> {
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

                paintContent(style, window, cx);

                #if gpui_inspector
                if (hitbox != null) {
                    window.insertInspectorHitbox(hitbox.id, inspectorId, cx);
                }
                #end

                if (hitbox != null && group != null) {
                    GroupHitboxes.pop(group, cx);
                }
                return null;
            });

            if (mask != null) window.popContentMask();
            if (textStyle != null) window.popTextStyle();

            style.paintBorder(bounds, cornerRadii, window, cx);

            if (hasOpacity) window.popElementOpacity(previousOpacity);
            return null;
        });
    }

    function paintMouseListeners(hitbox:Hitbox, elementState:Null<InteractiveElementState>, window:Window, cx:App):Void {
        final isFocused = trackedFocusHandle != null && trackedFocusHandle.isFocused(window);

        // If this element can be focused, register a mouse down listener
        // that will automatically transfer focus when hitting the element.
        // This behavior can be suppressed by using `window.preventDefault()`.
        if (trackedFocusHandle != null) {
            final focusHandle = trackedFocusHandle;
            window.onMouseEvent(MouseDown, (_, phase, window, cx) -> {
                if (phase == Bubble && hitbox.isHovered(window) && !window.defaultPrevented()) {
                    window.focus(focusHandle, cx);
                    // If there is a parent that is also focusable, prevent it
                    // from transferring focus because we already did so.
                    window.preventDefault();
                }
            });
        }

        for (listener in mouseDownListeners) {
            window.onMouseEvent(MouseDown, (event, phase, window, cx) -> listener(event, phase, hitbox, window, cx));
        }
        mouseDownListeners.resize(0);

        for (listener in mouseUpListeners) {
            window.onMouseEvent(MouseUp, (event, phase, window, cx) -> listener(event, phase, hitbox, window, cx));
        }
        mouseUpListeners.resize(0);

        for (listener in mouseMoveListeners) {
            window.onMouseEvent(MouseMove, (event, phase, window, cx) -> listener(event, phase, hitbox, window, cx));
        }
        mouseMoveListeners.resize(0);

        for (listener in mouseExitListeners) {
            window.onMouseEvent(MouseExited, (event, phase, window, cx) -> listener(event, phase, hitbox, window, cx));
        }
        mouseExitListeners.resize(0);

        for (listener in scrollListeners) {
            window.onMouseEvent(Scroll, (event, phase, window, cx) -> listener(event, phase, hitbox, window, cx));
        }
        scrollListeners.resize(0);

        if (hoverStyle != null
            || baseStyle.has(StyleRefinement.MOUSE_CURSOR)
            || cx.activeDrag != null && dragOverStyles.length > 0) {
            final hoverState = hoverStyle != null && elementState != null ? elementState.hoverState : null;
            final currentView = window.currentView();
            // Difference with GPUI: with default view caching (GPUI's own
            // `.cached(style)` keeps GPUI's behaviour), the view is also
            // notified when the hover state it was painted with is stale (GPUI
            // paints the hover state of the hitbox, but only notifies when it
            // differs from `hoverState.element`, which a first frame drawn
            // under the mouse leaves unset: an uncached view is fixed by the
            // next full redraw, a cached one is not).
            final paintedHovered = window.viewCaching && hoverState != null ? hitbox.isHovered(window) : null;

            window.onMouseEvent(MouseMove, (_, phase, window, cx) -> {
                final hovered = hitbox.isHovered(window);
                final wasHovered = hoverState != null && hoverState.element;
                if (phase == Capture && hovered != wasHovered) {
                    if (hoverState != null) {
                        hoverState.element = hovered;
                        cx.notify(currentView);
                    }
                }
                else if (phase == Capture && paintedHovered != null && hovered != paintedHovered) {
                    cx.notify(currentView);
                }
            });
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
        final dropListeners = this.dropListeners.copy();
        this.dropListeners.resize(0);
        final clickListeners = this.clickListeners.copy();
        this.clickListeners.resize(0);
        final auxClickListeners = this.auxClickListeners.copy();
        this.auxClickListeners.resize(0);
        final canDropPredicate = this.canDropPredicate;
        this.canDropPredicate = null;

        if (dropListeners.length > 0) {
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

                final hasAuxClickListeners = auxClickListeners.length > 0;
                window.onMouseEvent(MouseDown, (event, phase, window, _) -> {
                    final event:MouseDownEvent = cast event;
                    if (phase == Bubble && (event.button == Left || hasAuxClickListeners) && hitbox.isHovered(window)) {
                        pendingMouseDown.value = event;
                        window.refresh();
                    }
                });

                var dragListenerLeft = dragListener;
                window.onMouseEvent(MouseMove, (event, phase, window, cx) -> {
                    if (phase == Capture) {
                        return;
                    }

                    final event:MouseMoveEvent = cast event;
                    final mouseDown = pendingMouseDown.value;
                    if (mouseDown != null
                        && !cx.hasActiveDrag()
                        && event.position.sub(mouseDown.position).magnitude() > DRAG_THRESHOLD
                        && dragListenerLeft != null
                        && mouseDown.button == Left) {
                        final listener = dragListenerLeft;
                        dragListenerLeft = null;
                        clickedState.reset();
                        final cursorOffset = event.position.sub(hitbox.origin);
                        final drag = listener.render(listener.value, cursorOffset, window, cx);
                        cx.activeDrag = new AnyDrag(drag, listener.value, cursorOffset, dragCursorStyle);
                        pendingMouseDown.value = null;
                        window.refresh();
                        cx.stopPropagation();
                    }
                });

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

                var capturedMouseDown:Null<MouseDownEvent> = null;
                window.onMouseEvent(MouseUp, (event, phase, window, cx) -> {
                    switch phase {
                        // Clear the pending mouse down during the capture phase,
                        // so that it happens even if another event handler stops
                        // propagation.
                        case Capture:
                            if (pendingMouseDown.value != null && hitbox.isHovered(window)) {
                                capturedMouseDown = pendingMouseDown.value;
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
                            final mouseDown = capturedMouseDown;
                            if (mouseDown != null) {
                                capturedMouseDown = null;
                                final mouseClick = ClickEvent.Mouse(new MouseClickEvent(mouseDown, cast event));
                                if (mouseDown.button == Left) {
                                    for (listener in clickListeners) {
                                        listener(mouseClick, window, cx);
                                    }
                                }
                                else {
                                    for (listener in auxClickListeners) {
                                        listener(mouseClick, window, cx);
                                    }
                                }
                            }
                    }
                });
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
                registerTooltipMouseHandlers(activeTooltip, tooltipId, buildTooltip, checkIsHovered, checkIsHoveredDuringPrepaint, tooltipShowDelay, window);
            }

            // We unconditionally bind both the mouse up and mouse down active state handlers
            // Because we might not get a chance to render a frame before the mouse up event arrives.
            if (elementState.clickedState == null) elementState.clickedState = new ElementClickedState();
            final activeState = elementState.clickedState;

            window.onMouseEvent(MouseUp, (_, phase, window, _) -> {
                if (phase == Capture && activeState.isClicked()) {
                    activeState.reset();
                    window.refresh();
                }
            });

            final activeGroupHitbox = groupActiveStyle != null ? GroupHitboxes.get(groupActiveStyle.group, cx) : -1;
            window.onMouseEvent(MouseDown, (_, phase, window, _) -> {
                if (phase == Bubble && !window.defaultPrevented()) {
                    final groupHovered = activeGroupHitbox != -1 && window.isHitboxIdHovered(activeGroupHitbox);
                    final elementHovered = hitbox.isHovered(window);
                    if (groupHovered || elementHovered) {
                        activeState.group = groupHovered;
                        activeState.element = elementHovered;
                        window.refresh();
                    }
                }
            });
        }
    }

    function paintKeyboardListeners(window:Window, cx:App):Void {
        if (keyContext != null) {
            window.setKeyContext(keyContext);
        }

        for (listener in keyDownListeners) {
            window.onKeyEvent((event, phase, window, cx) -> {
                if (event.kind == KeyDown) listener(cast event, phase, window, cx);
            });
        }
        keyDownListeners.resize(0);

        for (listener in keyUpListeners) {
            window.onKeyEvent((event, phase, window, cx) -> {
                if (event.kind == KeyUp) listener(cast event, phase, window, cx);
            });
        }
        keyUpListeners.resize(0);

        for (listener in modifiersChangedListeners) {
            window.onModifiersChanged(listener);
        }
        modifiersChangedListeners.resize(0);

        for (entry in actionListeners) {
            window.onAction(entry.type, entry.listener);
        }
        actionListeners.resize(0);
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
        return window.withOptionalElementState(globalId, InteractiveElementState, (box, window) -> {
            var elementState:Null<InteractiveElementState> = null;
            if (box != null) {
                if (box.value == null) box.value = new InteractiveElementState();
                elementState = box.value;
            }
            return computeStyleInternal(hitbox, elementState, window, cx);
        });
    }

    function computeStyleInternal(hitbox:Null<Hitbox>, elementState:Null<InteractiveElementState>, window:Window, cx:App):Style {
        final style = new Style();
        style.refine(baseStyle);

        if (trackedFocusHandle != null) {
            if (inFocusStyle != null && trackedFocusHandle.withinFocused(window, cx)) {
                style.refine(inFocusStyle);
            }

            if (focusStyle != null && trackedFocusHandle.isFocused(window)) {
                style.refine(focusStyle);
            }

            if (focusVisibleStyle != null && trackedFocusHandle.isFocused(window) && window.lastInputWasKeyboard()) {
                style.refine(focusVisibleStyle);
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
                    style.refine(groupHoverStyle.style);
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
                    style.refine(hoverStyle);
                }
            }
        }

        if (hitbox != null) {
            final drag = cx.activeDrag;
            if (drag != null) {
                cx.activeDrag = null;
                var canDrop = true;
                if (canDropPredicate != null) {
                    canDrop = canDropPredicate(drag.value, window, cx);
                }

                if (canDrop) {
                    for (entry in groupDragOverStyles) {
                        final groupHitboxId = GroupHitboxes.get(entry.style.group, cx);
                        if (groupHitboxId != -1 && drag.valueIs(entry.type) && window.isHitboxIdHovered(groupHitboxId)) {
                            style.refine(entry.style.style);
                        }
                    }

                    for (entry in dragOverStyles) {
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
        }

        if (elementState != null) {
            if (elementState.clickedState == null) elementState.clickedState = new ElementClickedState();
            final clickedState = elementState.clickedState;
            if (clickedState.group && groupActiveStyle != null) {
                style.refine(groupActiveStyle.style);
            }

            if (activeStyle != null && clickedState.element) {
                style.refine(activeStyle);
            }
        }

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
        checkIsHovered:Window->Bool,
        checkIsHoveredDuringPrepaint:Window->Bool,
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

        window.onMouseEvent(Scroll, (_, _, window, _) -> {
            if (!(tooltipId != -1 && window.isTooltipHovered(tooltipId))) {
                clearActiveTooltipIfNotHoverable(activeTooltip, window);
            }
        });
    }

    static function handleTooltipMouseMove(
        activeTooltip:ActiveTooltipCell,
        buildTooltip:(Window, App) -> {view:AnyView, hoverable:Bool},
        checkIsHovered:Window->Bool,
        checkIsHoveredDuringPrepaint:Window->Bool,
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
                        showTooltip(activeTooltip, buildTooltip, checkIsHoveredDuringPrepaint, window, cx);
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
        checkIsHoveredDuringPrepaint:Window->Bool,
        window:Window,
        cx:App
    ):Bool {
        final built = buildTooltip(window, cx);
        var newTooltip:Null<ActiveTooltip> = null;
        if (built != null) {
            final tooltipIsHoverable = built.hoverable;
            newTooltip = Visible(new AnyTooltip(built.view, window.mousePosition(), (tooltipBounds, window, cx) -> {
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
        checkIsHovered:Window->Bool,
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
            stack.pop();
        }
    }

}
