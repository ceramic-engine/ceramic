// Ported from gpui-kit 0.8.1: crates/component/src/status_bar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.statusbar;

import gpui.AnyElement;
import gpui.App;
import gpui.Div;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.theme.Theme;

using gpui.base.StyledExt;

/**
 * A status bar with left, center (the children) and right regions.
 *
 * The center aligns by which ends are pinned: centered with both left and
 * right, end-aligned with only left, otherwise start-aligned.
 */
class StatusBar implements RenderOnce implements Styled implements ParentElement {

    final barStyle:StyleRefinement = new StyleRefinement();

    final leftElements:Array<AnyElement> = [];

    final rightElements:Array<AnyElement> = [];

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public function left(child:IntoElement):StatusBar {
        leftElements.push(child);
        return this;
    }

    public function right(child:IntoElement):StatusBar {
        rightElements.push(child);
        return this;
    }

    public inline function style():StyleRefinement {
        return barStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):StatusBar {
        childElements.push(child);
        return this;
    }

    static function region():Div {
        return gpui.base.Prelude.hFlex().overflowHidden().itemsCenter().gap2();
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final hasLeft = leftElements.length > 0;
        final hasRight = rightElements.length > 0;

        final bar = gpui.base.Prelude.hFlex()
            .itemsCenter()
            .gap2()
            .py1()
            .px2()
            .borderT1()
            .borderColor(theme.statusBarBorder)
            .bg(theme.tokens.statusBar.background)
            .textXs()
            .textColor(theme.mutedForeground)
            .refineStyle(barStyle);
        if (hasLeft) {
            final r = region();
            r.extend(leftElements);
            bar.child(r);
        }
        final center = region().flex1();
        if (hasLeft && hasRight) center.justifyCenter();
        if (hasLeft && !hasRight) center.justifyEnd();
        center.extend(childElements);
        bar.child(center);
        if (hasRight) {
            final r = region();
            r.extend(rightElements);
            bar.child(r);
        }
        return bar;
    }

}
