// Ported from gpui-pre 0.3.10: src/element.rs (`AnyElement`, `Drawable`, `ElementDrawPhase`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A dynamically typed element that can be used to store any element type,
 * and drives its draw phases (Rust `AnyElement` wrapping a `Drawable`).
 *
 * Like GPUI's element arena, instances are pooled: they are only valid
 * during the frame they are created in (they are recycled when the window
 * finishes drawing), so they must not be kept across frames.
 */
class AnyElement {

    static inline final PHASE_START = 0;
    static inline final PHASE_REQUEST_LAYOUT = 1;
    static inline final PHASE_LAYOUT_COMPUTED = 2;
    static inline final PHASE_PREPAINT = 3;
    static inline final PHASE_PAINTED = 4;

    static final pool:Array<AnyElement> = [];

    static final arena:Array<AnyElement> = [];

    /**
     * Number of `AnyElement` instances allocated so far (for allocation tests).
     */
    public static var allocatedCount(default, null):Int = 0;

    /**
     * Wraps an element, reusing a pooled instance when possible.
     */
    public static function create(element:Element):AnyElement {
        var any = pool.pop();
        if (any == null) {
            any = new AnyElement();
            allocatedCount++;
        }
        any.element = element;
        any.phase = PHASE_START;
        arena.push(any);
        return any;
    }

    /**
     * Recycles every element created since the last call. Called by the
     * window at the end of a frame (Rust: clearing the element arena).
     */
    public static function clearArena():Void {
        for (any in arena) {
            any.element = null;
            any.globalId = null;
            any.bounds = null;
            any.availableWidth = null;
            any.availableHeight = null;
            pool.push(any);
        }
        arena.resize(0);
    }

    /**
     * The wrapped element.
     */
    public var element(default, null):Element = null;

    var phase:Int = PHASE_START;

    var layoutId:LayoutId = 0;

    var nodeId:Int = -1;

    var globalId:Null<GlobalElementId> = null;

    var bounds:Null<Bounds> = null;

    var availableWidth:Null<AvailableSpace> = null;

    var availableHeight:Null<AvailableSpace> = null;

    function new() {}

    /**
     * Request the layout ID of the element stored in this `AnyElement`.
     * Used for laying out child elements in a parent element.
     */
    public function requestLayout(window:Window, cx:App):LayoutId {
        if (phase != PHASE_START) {
            throw 'must call request_layout only once';
        }
        final elementId = element.elementId();
        globalId = elementId != null ? window.prepareElementId(elementId) : null;

        #if gpui_inspector
        var inspectorId:Null<InspectorElementId> = null;
        if (window.inspectorEnabled()) {
            final source = element.sourceLocation();
            if (source != null) {
                inspectorId = prepareInspectorId(source, window);
            }
        }
        element.inspectorId = inspectorId;
        #end

        layoutId = element.requestLayout(globalId, window, cx);

        if (globalId != null) {
            window.popElementId();
        }
        phase = PHASE_REQUEST_LAYOUT;
        return layoutId;
    }

    #if gpui_inspector
    static function prepareInspectorId(source:haxe.PosInfos, window:Window):InspectorElementId {
        final path = new InspectorElementId.InspectorElementPath(window.currentGlobalElementId(), source);
        return window.buildInspectorElementId(path);
    }
    #end

    /**
     * Prepares the element to be painted by storing its bounds, giving it a chance to draw hitboxes and
     * request autoscroll before the final paint pass is confirmed.
     */
    public function prepaint(window:Window, cx:App):Void {
        if (phase != PHASE_REQUEST_LAYOUT && phase != PHASE_LAYOUT_COMPUTED) {
            throw 'must call request_layout before prepaint';
        }
        final elementId = element.elementId();
        if (elementId != null) {
            window.pushElementId(elementId);
        }

        bounds = window.layoutBounds(layoutId);
        final dispatchTree = window.nextFrameDispatchTree();
        nodeId = dispatchTree.pushNode();
        element.prepaint(globalId, bounds, window, cx);
        dispatchTree.popNode();

        if (globalId != null) {
            window.popElementId();
        }
        phase = PHASE_PREPAINT;
    }

    /**
     * Paints the element stored in this `AnyElement`.
     */
    public function paint(window:Window, cx:App):Void {
        if (phase != PHASE_PREPAINT) {
            throw 'must call prepaint before paint';
        }
        final elementId = element.elementId();
        if (elementId != null) {
            window.pushElementId(elementId);
        }

        window.nextFrameDispatchTree().setActiveNode(nodeId);
        element.paint(globalId, bounds, window, cx);

        if (globalId != null) {
            window.popElementId();
        }
        phase = PHASE_PAINTED;
    }

    /**
     * Performs layout for this element within the given available space and
     * returns its size.
     */
    public function layoutAsRoot(availableSpace:SizeOf<AvailableSpace>, window:Window, cx:App):Size {
        if (phase == PHASE_START) {
            requestLayout(window, cx);
        }
        if (phase == PHASE_REQUEST_LAYOUT) {
            window.computeLayout(layoutId, availableSpace, cx);
        }
        else if (phase == PHASE_LAYOUT_COMPUTED) {
            if (!Type.enumEq(availableSpace.width, availableWidth) || !Type.enumEq(availableSpace.height, availableHeight)) {
                window.computeLayout(layoutId, availableSpace, cx);
            }
        }
        else {
            throw 'cannot measure after painting';
        }
        availableWidth = availableSpace.width;
        availableHeight = availableSpace.height;
        phase = PHASE_LAYOUT_COMPUTED;
        // `window.layoutBounds(layoutId).size` without the `Bounds`
        @:privateAccess window.computeLayoutBounds(layoutId);
        return @:privateAccess window.layoutBoundsSize;
    }

    /**
     * Prepaints this element at the given absolute origin.
     */
    public function prepaintAt(origin:Point, window:Window, cx:App):Void {
        window.pushAbsoluteElementOffset(origin);
        prepaint(window, cx);
        window.popElementOffset();
    }

    /**
     * Performs layout on this element in the available space, then prepaints
     * it at the given absolute origin.
     */
    public function prepaintAsRoot(origin:Point, availableSpace:SizeOf<AvailableSpace>, window:Window, cx:App):Void {
        layoutAsRoot(availableSpace, window, cx);
        window.pushAbsoluteElementOffset(origin);
        prepaint(window, cx);
        window.popElementOffset();
    }

}
