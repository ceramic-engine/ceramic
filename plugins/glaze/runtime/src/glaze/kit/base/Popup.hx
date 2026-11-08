// Ported from gpui-kit 0.8.1: crates/base/src/popup.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.Action;
import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Component;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.IntoKeyContext;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.Point;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Positioner.PointCell;
import glaze.kit.base.Positioner.ResolvedPosition;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * The trigger bounds a popup measured during the last prepaint (Rust
 * `PopupAnchorState`).
 */
class PopupAnchorState {

    public var bounds:Bounds = new Bounds();

    public var captured:Bool = false;

    public function new() {}

}

/**
 * An unstyled trigger and anchored popup host.
 *
 * `Popup` owns trigger measurement, anchor-point calculation, first-frame
 * synchronization, deferred rendering, and window-edge snapping. Callers own
 * open state, interaction, popup content, appearance, and motion.
 *
 * Interactive listeners (`keyContext`, `onAction`, `onMouseDown`...) go to
 * `base`, the stateful `Div` the popup renders (Rust implements
 * `InteractiveElement` by delegation).
 */
class Popup extends Component implements Styled {

    /** Distance kept between a popup and the window edge. */
    static inline final WINDOW_MARGIN:Float = 8.;

    /** Deferred paint priority for interactive surfaces that must appear above dialogs. */
    public static inline final POPUP_PRIORITY:Int = 100;

    final id:ElementId;

    /** The stateful element the popup renders (its trigger container). */
    public final base:Div;

    final popupStyle:StyleRefinement = new StyleRefinement();

    @prop var anchor:Anchor = Anchor.TopLeft;

    /**
     * Gap from the trigger along the anchor's outward direction, zero by default.
     */
    @prop var offset:Float = 0.;

    /**
     * Observe resolved popup and trigger bounds before content prepaint.
     */
    @prop var onPosition:Null<(ResolvedPosition, Bounds) -> Void> = null;

    final trigger:AnyElement;

    var contentElement:Null<AnyElement> = null;

    public function new(id:ElementIdArg, trigger:IntoElement) {
        super();
        this.id = id;
        this.base = div().id(id);
        this.trigger = trigger;
    }

    public inline function style():StyleRefinement {
        return popupStyle;
    }

    public function content(content:IntoElement):Popup {
        contentElement = content;
        return this;
    }

    /** Key context of the trigger container (on `base`). */
    public function keyContext(keyContext:IntoKeyContext):Popup {
        base.keyContext(keyContext);
        return this;
    }

    /** An action listener (on `base`). */
    public function onAction<A:Action>(type:Class<A>, listener:(A, Window, App) -> Void):Popup {
        base.onAction(type, listener);
        return this;
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Popup {
        base.onMouseDown(button, listener);
        return this;
    }

    public static function resolvedCorner(anchor:Anchor, triggerBounds:Bounds):Point {
        return switch anchor {
            case TopLeft: triggerBounds.origin;
            case TopCenter: triggerBounds.topCenter();
            case TopRight: triggerBounds.topRight();
            case BottomLeft: new Point(triggerBounds.origin.x, triggerBounds.origin.y - triggerBounds.size.height);
            case BottomCenter: new Point(triggerBounds.topCenter().x, triggerBounds.origin.y - triggerBounds.size.height);
            case BottomRight: new Point(triggerBounds.topRight().x, triggerBounds.origin.y - triggerBounds.size.height);
            case LeftCenter | RightCenter: triggerBounds.origin;
        }
    }

    /**
     * Match the popup's anchor to the opposite edge of the measured trigger.
     */
    static function anchorPosition(anchor:Anchor, trigger:Bounds, offset:Float):Point {
        return switch anchor {
            case TopLeft: trigger.bottomLeft().add(new Point(0., offset));
            case TopCenter: trigger.bottomCenter().add(new Point(0., offset));
            case TopRight: trigger.bottomRight().add(new Point(0., offset));
            case BottomLeft: trigger.origin.sub(new Point(0., offset));
            case BottomCenter: trigger.topCenter().sub(new Point(0., offset));
            case BottomRight: trigger.topRight().sub(new Point(0., offset));
            case LeftCenter: trigger.rightCenter().add(new Point(offset, 0.));
            case RightCenter: trigger.leftCenter().sub(new Point(offset, 0.));
        }
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = window.useKeyedState(ElementId.NamedChild(id, 'anchor'), cx, _ -> new PopupAnchorState()).read(cx).value;
        final anchor = this.anchor;
        final triggerBounds = new BoundsCell(state.bounds);
        final offset = this.offset;
        final position = new PointCell(anchorPosition(anchor, state.bounds, offset));

        // A closed popup places nothing: it notes its trigger's bounds, for when
        // it opens, without asking for another frame.
        final hasContent = contentElement != null;
        final root = base
            .child(trigger)
            .child(
                canvas((bounds, window, cx) -> {
                    triggerBounds.value = bounds;
                    position.value = anchorPosition(anchor, bounds, offset);
                    final first = !state.captured;
                    state.bounds = bounds;
                    state.captured = true;
                    if (first && hasContent) {
                        window.requestAnimationFrame();
                    }
                    return null;
                }, (_, _, _, _) -> {})
                    .absolute()
                    .sizeFull()
                    .top0()
                    .left0()
            )
            .refineStyle(popupStyle);

        final content = contentElement;
        if (content == null) {
            return root;
        }
        if (!state.captured) {
            return root;
        }

        var positioner = Positioner.corner(anchor, position.value).trackedCornerPosition(position);
        final callback = onPosition;
        if (callback != null) {
            positioner = positioner.onPosition(position -> callback(position, triggerBounds.value));
        }
        return root.child(
            deferred(
                positioner
                    .margin(WINDOW_MARGIN)
                    // The host blocks the mouse, so no caller has to remember:
                    // what a popup covers belongs to the popup.
                    .occlude()
                    .child(content)
            )
                .withPriority(POPUP_PRIORITY)
        );
    }

}

/**
 * A mutable cell holding bounds (Rust `Rc<Cell<Bounds<Pixels>>>`).
 */
class BoundsCell {

    public var value:Bounds;

    public function new(value:Bounds) {
        this.value = value;
    }

}
