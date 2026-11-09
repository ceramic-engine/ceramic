// Ported from gpui-kit 0.8.1: crates/base/src/toolbar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyDownEvent;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An unstyled container that groups a set of controls and owns roving
 * keyboard focus among them.
 *
 * This is the behavior primitive behind a styled toolbar. The container
 * exposes `Toolbar` semantics to assistive technology (`Role.Toolbar` with
 * an orientation) and moves focus between its focusable descendants with the
 * arrow keys, so applications do not have to reimplement the roving-focus
 * contract per toolbar. It works with any focusable children (buttons,
 * menu triggers, inputs), because traversal walks the rendered tab stops
 * and constrains them to this subtree, mirroring how `Root` constrains
 * focus-trap cycling.
 *
 * Keyboard contract:
 *
 * - Left and Right move focus to the previous or next focusable descendant,
 *   wrapping around at either end (the same default as Base UI's `loopFocus`).
 * - When `disabled`, the arrow keys do nothing. Hosted controls must be
 *   disabled by their owner; the flag only suppresses the toolbar's own
 *   navigation.
 *
 * The container is not itself a tab stop, so ordinary `Tab` traversal enters
 * and leaves the toolbar through its items, matching the ARIA toolbar
 * pattern.
 *
 * An input hosted inside the toolbar keeps its own arrow-key behavior: text
 * inputs consume the arrow keys for caret movement before the toolbar sees
 * them. Place inputs at the trailing end of a horizontal toolbar, as the
 * Base UI Toolbar recommends.
 */
class Toolbar extends Component implements Styled implements ParentElement {

    /**
     * Upper bound on tab-stop hops when wrapping focus back into the toolbar, so
     * a toolbar whose items all vanished from the tab order can never hang the
     * key handler. Mirrors `Root`'s focus-trap loop bound.
     */
    static inline final MAX_FOCUS_ATTEMPTS:Int = 100;

    final id:ElementId;

    /** The stateful element the toolbar renders. */
    public final base:Div;

    final toolbarStyle:StyleRefinement = new StyleRefinement();

    /**
     * Disables the toolbar's own keyboard navigation. Hosted controls are
     * not automatically disabled.
     */
    @:allow(tests)
    @prop var disabled:Bool = false;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the toolbar exports. */
    public final a11y:A11y = new A11y(Role.Toolbar);

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
        this.base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return toolbarStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Toolbar {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Toolbar {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    static function stepFocus(window:Window, cx:App, forward:Bool):Void {
        if (forward) {
            window.focusNext(cx);
        } else {
            window.focusPrev(cx);
        }
    }

    /**
     * Move focus to the next (or previous) focusable element inside `container`.
     *
     * Traversal walks the window's tab stops like `Root`'s focus-trap cycling:
     * step once, and if the step landed outside the container, keep stepping
     * until the focus re-enters or comes back to where it started (in which
     * case the toolbar has no other focusable item and focus stays put).
     */
    static function moveFocus(container:FocusHandle, forward:Bool, window:Window, cx:App):Void {
        final start = window.focused(cx);
        if (start == null) return;

        stepFocus(window, cx, forward);
        var focused = window.focused(cx);
        if (container.containsFocused(window, cx) && focused != null && focused != start) {
            return;
        }

        for (_ in 0...MAX_FOCUS_ATTEMPTS) {
            stepFocus(window, cx, forward);
            focused = window.focused(cx);
            if (container.containsFocused(window, cx) && focused != null && focused != start) {
                return;
            }
            if (focused != null && focused == start) {
                break;
            }
        }

        window.focus(start, cx);
    }

    static function handleKeyDown(disabled:Bool, container:FocusHandle, event:KeyDownEvent, window:Window, cx:App):Void {
        if (disabled) return;

        final forward:Null<Bool> = switch event.keystroke.key {
            case 'left': false;
            case 'right': true;
            case _: null;
        }

        if (forward != null) {
            moveFocus(container, forward, window, cx);
            cx.stopPropagation();
        }
    }

    public function render(window:Window, cx:App):IntoElement {
        final disabled = this.disabled;

        // The handle must survive across frames so containment checks and the
        // key handler refer to the same dispatch-tree node; Button uses the
        // same keyed-state pattern for its own focus handle.
        final focusHandle:FocusHandle = window.useKeyedState(id, cx, _ -> cx.focusHandle().tabStop(false)).read(cx).value;

        a11y.orientation = Orientation.Horizontal;
        base.trackFocus(focusHandle)
            .onKeyDown((event, window, cx) -> handleKeyDown(disabled, focusHandle, event, window, cx))
            // The handle exists for containment checks only. Without this, a
            // press on blank space or non-focusable content would focus the
            // toolbar itself and take focus away from the rest of the window.
            // Focusable items handle the press first and keep their focus.
            .onAnyMouseDown((_, window, _) -> window.preventDefault());
        base.extend(childElements);
        return base.refineStyle(toolbarStyle);
    }

}

/**
 * A semantic subgroup of items within a `Toolbar`.
 *
 * The group carries no behavior or styling of its own: the surrounding
 * toolbar's roving arrow-key focus traverses its items exactly like the
 * toolbar's direct children, because containment follows the element tree.
 * Its value is structure: assistive technology announces the group and its
 * accessible name, so a run of related controls reads as one unit ("Undo",
 * "Redo" inside a "History" group).
 *
 * Unlike Base UI's `Toolbar.Group`, the group cannot disable its children:
 * disabling the hosted controls is the group owner's job.
 */
class ToolbarGroup extends Component implements Styled implements ParentElement {

    /** The stateful element the group renders. */
    public final base:Div;

    final groupStyle:StyleRefinement = new StyleRefinement();

    /**
     * Sets the accessible name announced for the group, e.g. "History".
     */
    @:allow(tests)
    @prop var label:Null<String> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the group exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.Group);

    public function new(id:ElementIdArg) {
        super();
        base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):ToolbarGroup {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):ToolbarGroup {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        // A group is one inline segment of the bar, so its children flow
        // along the row and center on the bar's cross axis; the same neutral
        // geometry `Tab` applies. Spacing between items is the caller's
        // (matching the bar's own gap).
        if (label != null) a11y.label = label;
        base.flex().itemsCenter();
        base.extend(childElements);
        return base.refineStyle(groupStyle);
    }

}
