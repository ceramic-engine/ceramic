// Ported from gpui-pre 0.3.10: src/elements/div.rs (`Div`, `InteractiveElement`, `StatefulInteractiveElement`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A `Div` element, the all-in-one element for building complex UIs in GPUI.
 * Create one with `Prelude.div()`, style it with the `Styled` methods, add
 * children with `child()` / `children()` and make it interactive with the
 * methods of GPUI's `InteractiveElement` and `StatefulInteractiveElement`
 * traits (`onClick`, `hover`, `trackFocus`, `onAction`, `overflowYScroll`...),
 * which are methods of `Div` here.
 *
 * Differences with GPUI:
 * - `id()` returns the same `Div` (Rust wraps it in `Stateful<Div>`), so the
 *   stateful methods are always available: like in Rust, they need an id to
 *   keep their state across frames (clicks, drags, tooltips, scrolling...).
 * - Style closures get a `StyleBuilder` (see its doc): `hover(s -> s.bg(red()))`.
 * - Typed listeners take the class: `onAction(MoveUp, (action, window, cx) -> ...)`,
 *   `onDrop(DraggedTab, ...)`, `dragOver(DraggedTab, (s, value, window, cx) -> ...)`.
 * - Delays are in seconds (`tooltipShowDelay(0.2)`).
 */
class Div extends Element implements Styled implements ParentElement {

    /**
     * The interactivity of this element (Rust `InteractiveElement::interactivity`).
     */
    public final interactivity:Interactivity = new Interactivity();

    final childElements:Array<AnyElement> = [];

    /**
     * The layout ids of the children, from `requestLayout()`: a new array
     * each time (the layout node keeps it), the shared empty one without
     * children
     */
    var childLayoutIds:Array<LayoutId> = NO_LAYOUT_IDS;

    /** The layout ids of a div without children (never changed) */
    static final NO_LAYOUT_IDS:Array<LayoutId> = [];

    var prepaintListener:Null<(Array<Bounds>, Window, App) -> Void> = null;

    var hitbox:Null<Hitbox> = null;

    public function new(#if glaze_inspector ?pos:haxe.PosInfos #end) {
        #if glaze_count_allocations glaze.util.AllocationCounters.divs++; #end
        #if glaze_inspector
        interactivity.sourceLocation = pos;
        #end
    }

    public inline function style():StyleRefinement {
        return interactivity.baseStyle;
    }

    override function elementId():Null<ElementId> {
        return interactivity.elementId;
    }

    #if glaze_inspector
    override function sourceLocation():Null<haxe.PosInfos> {
        return interactivity.sourceLocation;
    }
    #end

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) {
            childElements.push(element);
        }
    }

    /**
     * Add a single child element to this element.
     */
    public function child(child:IntoElement):Div {
        if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Add multiple child elements to this element.
     */
    public function children(children:Array<IntoElement>):Div {
        for (child in children) {
            if (child != null) childElements.push(child);
        }
        return this;
    }

    /**
     * Optionally applies `then` (Rust `FluentBuilder::when`).
     */
    public inline function when(condition:Bool, then:(Div) -> Div):Div {
        return condition ? then(this) : this;
    }

    /**
     * Applies `then` with the value when it is not null (Rust
     * `FluentBuilder::when_some`).
     */
    public inline function whenSome<T>(option:Null<T>, then:(Div, T) -> Div):Div {
        return option != null ? then(this, option) : this;
    }

    /**
     * Applies `f` to this element (Rust `FluentBuilder::map`).
     */
    public inline function map(f:(Div) -> Div):Div {
        return f(this);
    }

    /**
     * Rust `InteractiveElement::debug_selector`: a key to look up the bounds
     * of this element in tests. Like GPUI outside of debug test builds, it
     * records nothing.
     */
    public inline function debugSelector(f:() -> String):Div {
        return this;
    }

    /**
     * Add a listener to be called when the children of this `Div` are prepainted.
     * This allows you to store the `Bounds` of the children for later use.
     */
    public function onChildrenPrepainted(listener:(Array<Bounds>, Window, App) -> Void):Div {
        prepaintListener = listener;
        return this;
    }

/// InteractiveElement

    /**
     * Assign this element an ID, so that it can be used with interactivity
     * (Rust returns a `Stateful<Div>`).
     */
    public function id(id:ElementIdArg):Div {
        interactivity.elementId = id;
        return this;
    }

    /**
     * Assign this element to a group of elements that can be styled together.
     */
    public function group(group:String):Div {
        interactivity.group = group;
        return this;
    }

    /**
     * Track the focus state of the given focus handle on this element.
     * If the focus handle is focused by the application, this element will
     * apply its focused styles.
     */
    public function trackFocus(focusHandle:FocusHandle):Div {
        interactivity.focusable = true;
        interactivity.trackedFocusHandle = focusHandle;
        return this;
    }

    /**
     * Set whether this element is a tab stop.
     * When false, the element remains in tab-index order but cannot be reached via keyboard navigation.
     * Useful for container elements: focus the container, then call `window.focusNext()` to focus
     * the first tab stop inside it while having the container element itself be unreachable via the keyboard.
     * Should only be used with `tabIndex`.
     */
    public function tabStop(tabStop:Bool):Div {
        interactivity.tabStop = tabStop;
        return this;
    }

    /**
     * Set index of the tab stop order, and set this node as a tab stop.
     * This will default the element to being a tab stop. See `tabStop` for more information.
     * This should only be used in conjunction with `tabGroup`
     * in order to not interfere with the tab index of other elements.
     */
    public function tabIndex(index:Int):Div {
        interactivity.focusable = true;
        interactivity.tabIndex = index;
        interactivity.tabStop = true;
        return this;
    }

    /**
     * Designate this div as a "tab group". Tab groups have their own location in the tab-index order,
     * but for children of the tab group, the tab index is reset to 0. This can be useful for swapping
     * the order of tab stops within the group, without having to renumber all the tab stops in the whole
     * application.
     */
    public function tabGroup():Div {
        interactivity.tabGroup = true;
        if (interactivity.tabIndex == null) {
            interactivity.tabIndex = 0;
        }
        return this;
    }

    /**
     * Set the keymap context for this element. This will be used to determine
     * which action to dispatch from the keymap.
     */
    public function keyContext(keyContext:IntoKeyContext):Div {
        interactivity.keyContext = keyContext;
        return this;
    }

    /**
     * Apply the given style to this element when the mouse hovers over it.
     */
    public function hover(f:(StyleBuilder) -> StyleBuilder):Div {
        interactivity.hoverStyle = StyleBuilder.build(f);
        return this;
    }

    /**
     * Apply the given style to this element when the mouse hovers over a group member.
     */
    public function groupHover(groupName:String, f:(StyleBuilder) -> StyleBuilder):Div {
        interactivity.groupHoverStyle = new Interactivity.GroupStyle(groupName, StyleBuilder.build(f));
        return this;
    }

    /**
     * Bind the given callback to the mouse down event for the given mouse button.
     * The fluent API equivalent to `Interactivity.onMouseDown`.
     */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Div {
        interactivity.onMouseDown(button, listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse down event for any button, during the capture phase.
     */
    public function captureAnyMouseDown(listener:(MouseDownEvent, Window, App) -> Void):Div {
        interactivity.captureAnyMouseDown(listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse down event for any button, during the bubble phase.
     */
    public function onAnyMouseDown(listener:(MouseDownEvent, Window, App) -> Void):Div {
        interactivity.onAnyMouseDown(listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse up event for the given button, during the bubble phase.
     */
    public function onMouseUp(button:MouseButton, listener:(MouseUpEvent, Window, App) -> Void):Div {
        interactivity.onMouseUp(button, listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse up event for any button, during the capture phase.
     */
    public function captureAnyMouseUp(listener:(MouseUpEvent, Window, App) -> Void):Div {
        interactivity.captureAnyMouseUp(listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse up event for any button, during the bubble phase.
     */
    public function onAnyMouseUp(listener:(MouseUpEvent, Window, App) -> Void):Div {
        interactivity.onAnyMouseUp(listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse down event, on any button, during the capture phase,
     * when the mouse is outside of the bounds of this element.
     */
    public function onMouseDownOut(listener:(MouseDownEvent, Window, App) -> Void):Div {
        interactivity.onMouseDownOut(listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse up event, for the given button, during the capture phase,
     * when the mouse is outside of the bounds of this element.
     */
    public function onMouseUpOut(button:MouseButton, listener:(MouseUpEvent, Window, App) -> Void):Div {
        interactivity.onMouseUpOut(button, listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse move event, during the bubble phase.
     */
    public function onMouseMove(listener:(MouseMoveEvent, Window, App) -> Void):Div {
        interactivity.onMouseMove(listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse exit event, during the bubble phase.
     */
    public function onMouseExit(listener:(MouseExitEvent, Window, App) -> Void):Div {
        interactivity.onMouseExit(listener);
        return this;
    }

    /**
     * Bind the given callback to the mouse drag event of the given type. Note that this
     * will be called for all move events, inside or outside of this element, as long as the
     * drag was started with this element under the mouse.
     */
    public function onDragMove<T>(type:Class<T>, listener:(DragMoveEvent<T>, Window, App) -> Void):Div {
        interactivity.onDragMove(type, listener);
        return this;
    }

    /**
     * Bind the given callback to scroll events (wheel and trackpad), during the bubble phase.
     */
    public function onScroll(listener:(ScrollEvent, Window, App) -> Void):Div {
        interactivity.onScroll(listener);
        return this;
    }

    /**
     * Renamed to `onScroll` in GPUI.
     */
    public inline function onScrollWheel(listener:(ScrollEvent, Window, App) -> Void):Div {
        return onScroll(listener);
    }

    /**
     * Capture the given action, before normal action dispatch can fire.
     */
    public function captureAction<A:Action>(type:Class<A>, listener:(A, Window, App) -> Void):Div {
        interactivity.captureAction(type, listener);
        return this;
    }

    /**
     * Bind the given callback to an action dispatch during the bubble phase.
     */
    public function onAction<A:Action>(type:Class<A>, listener:(A, Window, App) -> Void):Div {
        interactivity.onAction(type, listener);
        return this;
    }

    /** `onAction()` with an entry made once (`Interactivity.bubbleActionEntry`). Internal. */
    @:allow(glaze)
    function onActionEntry(entry:Interactivity.TypedActionListener):Div {
        interactivity.addActionEntry(entry);
        return this;
    }

    /**
     * Bind the given callback to an action dispatch, based on a dynamic action parameter
     * instead of a type parameter.
     */
    public function onBoxedAction(action:Action, listener:(Action, Window, App) -> Void):Div {
        interactivity.onBoxedAction(action, listener);
        return this;
    }

    /**
     * Bind the given callback to a key down event, during the bubble phase.
     */
    public function onKeyDown(listener:(KeyDownEvent, Window, App) -> Void):Div {
        interactivity.onKeyDown(listener);
        return this;
    }

    /**
     * Bind the given callback to a key down event, during the capture phase.
     */
    public function captureKeyDown(listener:(KeyDownEvent, Window, App) -> Void):Div {
        interactivity.captureKeyDown(listener);
        return this;
    }

    /**
     * Bind the given callback to a key up event, during the bubble phase.
     */
    public function onKeyUp(listener:(KeyUpEvent, Window, App) -> Void):Div {
        interactivity.onKeyUp(listener);
        return this;
    }

    /**
     * Bind the given callback to a key up event, during the capture phase.
     */
    public function captureKeyUp(listener:(KeyUpEvent, Window, App) -> Void):Div {
        interactivity.captureKeyUp(listener);
        return this;
    }

    /**
     * Bind the given callback to modifiers changing events.
     */
    public function onModifiersChanged(listener:(ModifiersChangedEvent, Window, App) -> Void):Div {
        interactivity.onModifiersChanged(listener);
        return this;
    }

    /**
     * Apply the given style when the given data type is dragged over this element.
     */
    public function dragOver<S>(type:Class<S>, f:(StyleBuilder, S, Window, App) -> StyleBuilder):Div {
        if (interactivity.dragOverStyles == null) interactivity.dragOverStyles = [];
        interactivity.dragOverStyles.push({
            type: type,
            build: (value, window, cx) -> f(new StyleBuilder(), cast value, window, cx).style()
        });
        return this;
    }

    /**
     * Apply the given style when the given data type is dragged over this element's group.
     */
    public function groupDragOver<S>(type:Class<S>, groupName:String, f:(StyleBuilder) -> StyleBuilder):Div {
        if (interactivity.groupDragOverStyles == null) interactivity.groupDragOverStyles = [];
        interactivity.groupDragOverStyles.push({type: type, style: new Interactivity.GroupStyle(groupName, StyleBuilder.build(f))});
        return this;
    }

    /**
     * Bind the given callback to drop events of the given type, whether or not the drag started on this element.
     */
    public function onDrop<T>(type:Class<T>, listener:(T, Window, App) -> Void):Div {
        interactivity.onDrop(type, listener);
        return this;
    }

    /**
     * Use the given predicate to determine whether or not a drop event should be dispatched to this element.
     */
    public function canDrop(predicate:(Dynamic, Window, App) -> Bool):Div {
        interactivity.canDrop(predicate);
        return this;
    }

    /**
     * Set the area of the window that this element acts as, for the
     * platform's own window controls (Windows hit testing). The port records
     * it (`Window.windowControlHitboxes`) without platform effect.
     */
    public function windowControlArea(area:WindowControlArea):Div {
        interactivity.windowControl = area;
        return this;
    }

    /**
     * Block the mouse from all interactions with elements behind this element's hitbox. Typically
     * `blockMouseExceptScroll` should be preferred.
     */
    public function occlude():Div {
        interactivity.occludeMouse();
        return this;
    }

    /**
     * Set the bounds of this element as a hitbox that blocks mouse interactions with elements
     * behind it, except for scrolling.
     */
    public function blockMouseExceptScroll():Div {
        interactivity.blockMouseExceptScroll();
        return this;
    }

    /**
     * Set the given styles to be applied when this element, specifically, is focused.
     * Requires that the element is focusable. Elements can be made focusable using `trackFocus`.
     */
    public function focus(f:(StyleBuilder) -> StyleBuilder):Div {
        interactivity.focusStyle = StyleBuilder.build(f);
        return this;
    }

    /**
     * Set the given styles to be applied when this element is inside another element that is focused.
     */
    public function inFocus(f:(StyleBuilder) -> StyleBuilder):Div {
        interactivity.inFocusStyle = StyleBuilder.build(f);
        return this;
    }

    /**
     * Set the given styles to be applied when this element is focused via keyboard navigation.
     * This is similar to CSS's `:focus-visible` pseudo-class.
     */
    public function focusVisible(f:(StyleBuilder) -> StyleBuilder):Div {
        interactivity.focusVisibleStyle = StyleBuilder.build(f);
        return this;
    }

/// StatefulInteractiveElement

    /**
     * Set this element to focusable.
     */
    public function focusable():Div {
        interactivity.focusable = true;
        return this;
    }

    /**
     * Set the overflow x and y to scroll.
     */
    public function overflowScroll():Div {
        interactivity.baseStyle.overflowX = Scroll;
        interactivity.baseStyle.overflowY = Scroll;
        return this;
    }

    /**
     * Set the overflow x to scroll.
     */
    public function overflowXScroll():Div {
        interactivity.baseStyle.overflowX = Scroll;
        return this;
    }

    /**
     * Set the overflow y to scroll.
     */
    public function overflowYScroll():Div {
        interactivity.baseStyle.overflowY = Scroll;
        return this;
    }

    /**
     * Set the scroll to be restricted to the input gesture's axis.
     */
    public function restrictScrollToAxis():Div {
        interactivity.baseStyle.restrictScrollToAxis = true;
        return this;
    }

    /**
     * Track the scroll state of this element with the given handle.
     */
    public function trackScroll(scrollHandle:ScrollHandle):Div {
        interactivity.trackedScrollHandle = scrollHandle;
        return this;
    }

    /**
     * Track the scroll state of this element with the given handle.
     */
    public function anchorScroll(scrollAnchor:Null<ScrollAnchor>):Div {
        interactivity.scrollAnchor = scrollAnchor;
        return this;
    }

    /**
     * Set the given styles to be applied when this element is active.
     */
    public function active(f:(StyleBuilder) -> StyleBuilder):Div {
        interactivity.activeStyle = StyleBuilder.build(f);
        return this;
    }

    /** `hover(f)` with the refinement `f` would build (no closure). Internal. */
    @:allow(glaze)
    function setHoverRefinement(refinement:StyleRefinement):Void {
        interactivity.hoverStyle = refinement;
    }

    /** `active(f)` with the refinement `f` would build (no closure). Internal. */
    @:allow(glaze)
    function setActiveRefinement(refinement:StyleRefinement):Void {
        interactivity.activeStyle = refinement;
    }

    /**
     * Set the given styles to be applied when this element's group is active.
     */
    public function groupActive(groupName:String, f:(StyleBuilder) -> StyleBuilder):Div {
        interactivity.groupActiveStyle = new Interactivity.GroupStyle(groupName, StyleBuilder.build(f));
        return this;
    }

    /**
     * Bind the given callback to click events of this element.
     */
    public function onClick(listener:(ClickEvent, Window, App) -> Void):Div {
        interactivity.onClick(listener);
        return this;
    }

    /**
     * Bind the given callback to non-primary click events of this element.
     */
    public function onAuxClick(listener:(ClickEvent, Window, App) -> Void):Div {
        interactivity.onAuxClick(listener);
        return this;
    }

    /**
     * On drag initiation, this callback will be used to create a new view to render the dragged value
     * for a drag and drop operation. The value is passed to the callback with the offset of the cursor
     * in the element.
     */
    public function onDrag<T>(value:T, constructor:(T, Point, Window, App) -> AnyView):Div {
        interactivity.onDrag(value, constructor);
        return this;
    }

    /**
     * Bind the given callback on the hover start and end events of this element. Note that the boolean
     * passed to the callback is true when the hover starts and false when it ends.
     */
    public function onHover(listener:(Bool, Window, App) -> Void):Div {
        interactivity.onHover(listener);
        return this;
    }

    /**
     * Configure how the `onHover` listener reacts to keyboard input.
     */
    public function hoverListenerMode(mode:Interactivity.HoverListenerMode):Div {
        interactivity.hoverListenerModeValue = mode;
        return this;
    }

    /**
     * Use the given callback to construct a new tooltip view when the mouse hovers over this element.
     */
    public function tooltip(buildTooltip:(Window, App) -> AnyView):Div {
        interactivity.tooltip(buildTooltip);
        return this;
    }

    /**
     * Use the given callback to construct a new tooltip view when the mouse hovers over this element.
     * The tooltip itself is also hoverable and won't disappear when the user moves the mouse into
     * the tooltip.
     */
    public function hoverableTooltip(buildTooltip:(Window, App) -> AnyView):Div {
        interactivity.hoverableTooltip(buildTooltip);
        return this;
    }

    /**
     * Set the delay before the tooltip is shown, in seconds.
     */
    public function tooltipShowDelay(delay:Float):Div {
        interactivity.tooltipShowDelay = delay;
        return this;
    }

/// AnimationExt

    /**
     * Render this element with an animation (Rust `AnimationExt::with_animation`).
     */
    public function withAnimation(id:ElementIdArg, animation:Animation, animator:(Div, Float) -> Div):AnimationElement<Div> {
        return AnimationExt.withAnimation(this, id, animation, animator);
    }

    /**
     * Render this element with a chain of animations (Rust `AnimationExt::with_animations`).
     */
    public function withAnimations(id:ElementIdArg, animations:Array<Animation>, animator:(Div, Int, Float) -> Div):AnimationElement<Div> {
        return AnimationExt.withAnimations(this, id, animations, animator);
    }

    /**
     * Render this element with a spring animation (Rust `AnimationExt::with_spring`).
     */
    public function withSpring<T>(id:ElementIdArg, animation:SpringAnimation<T>, animator:(Div, T) -> Div):SpringAnimationElement<Div, T> {
        return AnimationExt.withSpring(this, id, animation, animator);
    }

/// Element

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        // Rust `self.interactivity.request_layout(.., |style, window, cx| ..)`,
        // without a closure
        final style = interactivity.requestLayoutStyle(id, #if glaze_inspector inspectorId, #end window, cx);
        final textStyle = style.textStyle();
        if (textStyle != null) window.pushTextStyle(textStyle);
        final count = childElements.length;
        var ids = NO_LAYOUT_IDS;
        if (count > 0) {
            ids = [];
            ids.resize(count);
            for (i in 0...count) {
                ids[i] = childElements[i].requestLayout(window, cx);
            }
        }
        childLayoutIds = ids;
        final layoutId = window.requestLayoutOwned(style, ids, cx);
        if (textStyle != null) window.popTextStyle();
        return layoutId;
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final hasPrepaintListener = prepaintListener != null;
        final childrenBounds:Null<Array<Bounds>> = hasPrepaintListener ? [] : null;

        var childMinX = Math.POSITIVE_INFINITY;
        var childMinY = Math.POSITIVE_INFINITY;
        var childMaxX = 0.0;
        var childMaxY = 0.0;
        final scrollAnchor = interactivity.scrollAnchor;
        if (scrollAnchor != null) {
            scrollAnchor.lastOrigin.value = bounds.origin.sub(window.elementOffset());
        }
        var contentSize:Size;
        if (childLayoutIds.length == 0) {
            contentSize = bounds.size;
        }
        else {
            final scrollHandle = interactivity.trackedScrollHandle;
            if (scrollHandle != null) {
                scrollHandle.state.childBounds.resize(0);
            }
            for (childLayoutId in childLayoutIds) {
                // Read without allocating a `Bounds` (only kept when a scroll handle or a prepaint listener needs it)
                window.computeLayoutBounds(childLayoutId);
                final childX = window.layoutBoundsX;
                final childY = window.layoutBoundsY;
                final childSize = window.layoutBoundsSize;
                childMinX = Math.min(childMinX, childX);
                childMinY = Math.min(childMinY, childY);
                childMaxX = Math.max(childMaxX, childX + childSize.width);
                childMaxY = Math.max(childMaxY, childY + childSize.height);
                if (scrollHandle != null) {
                    scrollHandle.state.childBounds.push(window.computedLayoutBounds());
                }
                else if (hasPrepaintListener) {
                    childrenBounds.push(window.computedLayoutBounds());
                }
            }
            final contentWidth = childMaxX - childMinX;
            final contentHeight = childMaxY - childMinY;
            // The element's own size when the children span it exactly (immutable, so shared)
            final size = bounds.size;
            contentSize = sameFloat(contentWidth, size.width) && sameFloat(contentHeight, size.height)
                ? size
                : new Size(contentWidth, contentHeight);
        }

        if (interactivity.trackedScrollHandle != null) {
            interactivity.trackedScrollHandle.scrollToActiveItem();
        }

        // Rust `self.interactivity.prepaint(.., |style, scroll_offset, hitbox, window, cx| ..)`,
        // without a closure
        final style = interactivity.prepaintBegin(id, #if glaze_inspector inspectorId, #end bounds, contentSize, window, cx);
        // skip children
        if (style.display != Display.None) {
            // Rust `window.with_element_offset(scroll_offset, ..)`
            final scrollOffset = interactivity.prepaintScrollOffset;
            final offset = !scrollOffset.isZero();
            if (offset) {
                window.pushAbsoluteElementOffset(window.elementOffset().add(scrollOffset));
            }
            for (child in childElements) {
                child.prepaint(window, cx);
            }
            if (offset) {
                window.popElementOffset();
            }

            if (prepaintListener != null) {
                prepaintListener(childrenBounds, window, cx);
            }
        }
        hitbox = interactivity.prepaintHitbox;
        interactivity.prepaintEnd(window);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final hitbox = this.hitbox;
        this.hitbox = null;
        // Rust `self.interactivity.paint(.., |style, window, cx| ..)`, without a closure
        final style = interactivity.paintBegin(id, #if glaze_inspector inspectorId, #end bounds, hitbox, window, cx);
        if (style == null) {
            return;
        }
        // skip children
        if (style.display != Display.None) {
            for (child in childElements) {
                child.paint(window, cx);
            }
        }
        interactivity.paintEnd(bounds, window, cx);
    }


    /** The same value, zero signs included */
    static inline function sameFloat(a:Float, b:Float):Bool {
        return a == b && (b != 0.0 || 1.0 / a == 1.0 / b);
    }

}
