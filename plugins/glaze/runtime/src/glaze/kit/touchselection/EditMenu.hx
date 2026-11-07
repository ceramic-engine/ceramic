// Ported from gpui-kit 0.8.1: crates/component/src/touch_selection/edit_menu.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.touchselection;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.ElementId;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.Window;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.Popup;
import glaze.kit.base.Positioner;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.button.Button.ButtonCustomVariant;
import glaze.kit.separator.Separator;
import glaze.kit.theme.Theme;
import glaze.kit.touchselection.SelectionHandles.SurfaceHandler;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.Observe;
using glaze.kit.base.StyledExt;
using glaze.kit.ThemeStyled;

/**
 * One command in the edit menu.
 */
class EditMenuItem {

    public final label:String;

    public final onClick:(Window, App) -> Void;

    public function new(label:String, onClick:(Window, App) -> Void) {
        this.label = label;
        this.onClick = onClick;
    }

}

/**
 * The row of commands a touch selection offers: Cut, Copy, Paste, Select All
 * (whichever apply). It floats above the selection, or below it when there
 * is no room above, and stays out of the way of the handles' knobs.
 *
 * Every item is a `Button` sized for a finger, so the row keeps the button
 * family's press feedback. It carries no arrow: it belongs to the selection
 * it sits on, not to a trigger.
 */
class EditMenu implements RenderOnce {

    /** The height of a menu row. */
    static inline final ROW_HEIGHT:Float = 32.;

    final id:ElementId;

    /** The selection, including the room its handles take. */
    final anchor:Bounds;

    final itemList:Array<EditMenuItem> = [];

    var onPaintHandler:Null<SurfaceHandler> = null;

    public function new(id:ElementId, anchor:Bounds) {
        this.id = id;
        this.anchor = anchor;
    }

    public function items(items:Array<EditMenuItem>):EditMenu {
        for (item in items) itemList.push(item);
        return this;
    }

    public function onPaint(onPaint:SurfaceHandler):EditMenu {
        this.onPaintHandler = onPaint;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final onPaint = this.onPaintHandler;
        // A pill-like bar, as iOS draws its edit menu.
        final radius = theme.radiusLg;
        // The menu family's hover, not the ghost button's: the ghost's grey
        // is the bar's own ring color and would blur the edge.
        final itemStyle = new ButtonCustomVariant(cx)
            .color(theme.transparent)
            .foreground(theme.popoverForeground)
            .hover(theme.accent)
            .active(theme.accent);
        final last = itemList.length > 0 ? itemList.length - 1 : 0;
        final elements:Array<IntoElement> = [];
        for (ix in 0...itemList.length) {
            final item = itemList[ix];
            final onClick = item.onClick;
            // A rule between neighbours, none before the first, the full
            // height of the bar.
            if (ix > 0) {
                elements.push(Separator.vertical());
            }
            // The items fill the bar edge to edge, so each one's press
            // surface takes the bar's own corners: the first the left pair,
            // the last the right pair, the ones between none.
            final button = new Button(ix)
                .custom(itemStyle)
                // This is a finger's menu wherever it shows: body text in a
                // 32px row.
                .withSize(glaze.kit.Size.Large)
                .h(px(ROW_HEIGHT))
                .px3()
                .rounded(radius)
                .withBorderCorners(ix == 0, ix == last, ix == last, ix == 0)
                .tabStop(false)
                .label(item.label)
                .onClick((_, window, cx) -> onClick(window, cx));
            // Observed under its label, so a test can press "Copy".
            elements.push(div().id(item.label).testSupport().child(button));
        }
        final bar = hFlex()
            .id(id)
            .relative()
            .itemsStretch()
            .overflowHidden()
            .popoverStyle(cx)
            .rounded(px(radius))
            .children(elements);
        if (onPaint != null) {
            bar.child(canvas((bounds, window, cx) -> {
                onPaint(bounds, window, cx);
                return 0;
            }, (_, _, _, _) -> {}).absolute().inset0());
        }
        return deferred(
            Positioner.side(anchor)
                .placement(Placement.Top)
                .offset(8.)
                .occlude()
                .child(bar)
        ).withPriority(Popup.POPUP_PRIORITY);
    }

}
