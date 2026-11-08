// Ported from gpui-kit 0.8.1: crates/component/src/button/toggle.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.button;

import glaze.AnyElement;
import glaze.App;
import glaze.Axis;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits;
import glaze.kit.Icon;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import glaze.kit.tooltip.Tooltip.ComponentTooltip;

using glaze.kit.base.StyledExt;

/**
 * The variant of a `Toggle` (default `Ghost`).
 */
enum abstract ToggleVariant(Int) {
    var Ghost;
    var Outline;
}

/**
 * A toggle button: a controlled pressed state shown with the accent colors.
 *
 * The tooltip is a managed tooltip (`glaze.kit.tooltip`), also
 * announced as the accessibility label.
 */
class Toggle implements RenderOnce implements Styled implements ParentElement implements Sizable implements Disableable {

    final id:ElementId;

    @:allow(glaze.kit, tests)
    final toggleStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit, tests)
    var checkedValue:Bool = false;

    @:allow(glaze.kit, tests)
    var sizeValue:Size = Medium;

    @:allow(glaze.kit, tests)
    var variantValue:ToggleVariant = Ghost;

    @:allow(glaze.kit, tests)
    var disabledValue:Bool = false;

    var borderCorners:Array<Bool> = [true, true, true, true];

    var borderEdges:Array<Bool> = [true, true, true, true];

    @:allow(glaze.kit, tests)
    final childElements:Array<AnyElement> = [];

    @:allow(glaze.kit, tests)
    var onClickHandler:Null<(Bool, Window, App) -> Void> = null;

    var tooltipText:Null<String> = null;

    var tooltipShowDelayValue:Null<Float> = null;

    /**
     * Create a new Toggle element.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return toggleStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Toggle {
        if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Set tooltip text for the toggle.
     */
    public function tooltip(tooltip:String):Toggle {
        tooltipText = tooltip;
        return this;
    }

    /**
     * Overrides how long the pointer must rest before the tooltip shows, in seconds.
     */
    public function tooltipShowDelay(delay:Float):Toggle {
        tooltipShowDelayValue = delay;
        return this;
    }

    /**
     * Add a label to the toggle.
     */
    public function label(label:String):Toggle {
        childElements.push((label:IntoElement));
        return this;
    }

    /**
     * Add icon to the toggle.
     */
    public function icon(icon:IntoIcon):Toggle {
        childElements.push(((icon:Icon):IntoElement));
        return this;
    }

    /**
     * Set the checked state of the toggle, default: false
     */
    public function checked(checked:Bool):Toggle {
        checkedValue = checked;
        return this;
    }

    /**
     * Set the callback to be called when the toggle is clicked, with the new
     * checked state of the toggle.
     */
    public function onClick(handler:(Bool, Window, App) -> Void):Toggle {
        onClickHandler = handler;
        return this;
    }

    @:allow(glaze.kit, tests)
    function withBorderCorners(topLeft:Bool, topRight:Bool, bottomRight:Bool, bottomLeft:Bool):Toggle {
        borderCorners = [topLeft, topRight, bottomRight, bottomLeft];
        return this;
    }

    @:allow(glaze.kit, tests)
    function withBorderEdges(top:Bool, right:Bool, bottom:Bool, left:Bool):Toggle {
        borderEdges = [top, right, bottom, left];
        return this;
    }

    public function withVariant(variant:ToggleVariant):Toggle {
        variantValue = variant;
        return this;
    }

    /** Set the variant to ghost. */
    public inline function ghost():Toggle return withVariant(Ghost);

    /** Set the variant to outline. */
    public inline function outline():Toggle return withVariant(Outline);

    public function disabled(disabled:Bool):Toggle {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    public function withSize(size:IntoSize):Toggle {
        this.sizeValue = size;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final size = sizeValue;
        final theme = Theme.global(cx);
        final checked = checkedValue;
        final disabled = disabledValue;
        final hoverable = !disabled && !checked;
        final rounding = theme.radius;
        final pressedBackground = theme.tokens.accent;
        final pressedForeground = theme.accentForeground;
        final instanceStyle = toggleStyle.clone();

        final toggle = glaze.kit.base.Toggle.component(id).pressed(checked).disabled(disabled);
        if (tooltipText != null) toggle.accessibilityLabel(tooltipText);
        final onClick = onClickHandler;
        if (onClick != null) {
            toggle.onChange((next, _, window, cx) -> onClick(next, window, cx));
        }
        toggle.flex().flexRow().lineHeight(glaze.Prelude.relative(1.25)).itemsCenter().justifyCenter();
        switch size {
            case XSmall: toggle.minW5().h5().px0p5().textXs();
            case Small: toggle.minW6().h6().px1().textSm();
            case Large: toggle.minW9().h9().px3().textBase();
            case _: toggle.minW8().h8().px2().textSm();
        }
        if (borderCorners[0]) toggle.roundedTl(rounding);
        if (borderCorners[1]) toggle.roundedTr(rounding);
        if (borderCorners[3]) toggle.roundedBl(rounding);
        if (borderCorners[2]) toggle.roundedBr(rounding);
        if (variantValue == Outline) {
            if (borderEdges[3]) toggle.borderL1();
            if (borderEdges[1]) toggle.borderR1();
            if (borderEdges[0]) toggle.borderT1();
            if (borderEdges[2]) toggle.borderB1();
            toggle.borderColor(theme.border).bg(theme.tokens.background.background);
        }
        if (hoverable) {
            toggle.hover(s -> s.bg(theme.tokens.accent.background).textColor(theme.accentForeground));
        }
        toggle.styles(styles -> styles.pressed(s -> s
            .bg(pressedBackground.background)
            .textColor(pressedForeground)
            .refineStyle(instanceStyle)));
        toggle.refineStyle(toggleStyle);
        toggle.extend(childElements);
        return ComponentTooltip.of(tooltipText, tooltipShowDelayValue).apply(toggle, toggle.base);
    }

}

/**
 * A group of toggles.
 */
class ToggleGroup implements RenderOnce implements Styled implements Sizable implements Disableable {

    final id:ElementId;

    final groupStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit, tests)
    var sizeValue:Size = Medium;

    @:allow(glaze.kit, tests)
    var variantValue:ToggleVariant = Ghost;

    @:allow(glaze.kit, tests)
    var disabledValue:Bool = false;

    @:allow(glaze.kit, tests)
    var segmentedValue:Bool = false;

    @:allow(glaze.kit, tests)
    final items:Array<Toggle> = [];

    @:allow(glaze.kit, tests)
    var onClickHandler:Null<(Array<Bool>, Window, App) -> Void> = null;

    /**
     * Create a new ToggleGroup element.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    /**
     * Add a child `Toggle` to the group.
     */
    public function child(toggle:Toggle):ToggleGroup {
        if (toggle != null) items.push(toggle);
        return this;
    }

    /**
     * Add multiple `Toggle`s to the group.
     */
    public function children(children:Array<Toggle>):ToggleGroup {
        for (child in children) if (child != null) items.push(child);
        return this;
    }

    /**
     * Set the callback to be called when the toggle group changes, with the
     * new check state of each `Toggle` in the group.
     */
    public function onClick(onClick:(Array<Bool>, Window, App) -> Void):ToggleGroup {
        onClickHandler = onClick;
        return this;
    }

    /**
     * Render the group as a connected segmented control.
     *
     * This keeps the existing multi-toggle behavior, but removes the default
     * gap and joins adjacent item borders into a single segmented outline.
     */
    public function segmented():ToggleGroup {
        segmentedValue = true;
        return this;
    }

    public function withSize(size:IntoSize):ToggleGroup {
        this.sizeValue = size;
        return this;
    }

    public function withVariant(variant:ToggleVariant):ToggleGroup {
        variantValue = variant;
        return this;
    }

    public inline function ghost():ToggleGroup return withVariant(Ghost);

    public inline function outline():ToggleGroup return withVariant(Outline);

    public function disabled(disabled:Bool):ToggleGroup {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    public function render(window:Window, cx:App):IntoElement {
        final size = sizeValue;
        final disabled = disabledValue;
        final itemsLen = items.length;
        final checks = [for (item in items) item.checkedValue];
        final clickedIndex:Array<Null<Int>> = [null];

        final row = hFlex().itemsCenter();
        if (!segmentedValue) row.gap2();
        row.refineStyle(groupStyle);
        for (ix in 0...items.length) {
            final item = items[ix];
            if (!segmentedValue || itemsLen == 1) {
                // Unchanged
            } else if (ix == 0) {
                item.withBorderCorners(true, false, false, true).withBorderEdges(true, true, true, true);
            } else if (ix == itemsLen - 1) {
                item.withBorderCorners(false, true, true, false).withBorderEdges(true, true, true, false);
            } else {
                item.withBorderCorners(false, false, false, false).withBorderEdges(true, true, true, false);
            }
            final effectiveDisabled = disabled || item.disabledValue;
            item.disabled(effectiveDisabled)
                .withSize(size)
                .withVariant(variantValue)
                .onClick((_, _, cx) -> {
                    clickedIndex[0] = ix;
                    cx.propagate();
                });
            row.child(item);
        }

        final group = glaze.kit.base.ToggleGroup.component(id).axis(Axis.Horizontal).child(row);
        final onClick = onClickHandler;
        if (!disabled && onClick != null) {
            group.onClick((_, window, cx) -> {
                final ix = clickedIndex[0];
                clickedIndex[0] = null;
                if (ix == null) return;
                final next = checks.copy();
                next[ix] = !next[ix];
                onClick(next, window, cx);
            });
        }
        return group;
    }

}
