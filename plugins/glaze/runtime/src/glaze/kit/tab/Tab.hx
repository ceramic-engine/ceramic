// Ported from gpui-kit 0.8.1: crates/component/src/tab/tab.rs (Tab)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviations DEV-013 (icon-only tab width) and DEV-014 (disabled selected tab). See DEVIATIONS.md.
package glaze.kit.tab;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.ElementId;
import glaze.IntoBackground;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Path.FillOptions;
import glaze.PathBuilder;
import glaze.PathBuilder.PathStyle;
import glaze.Point;
import glaze.Pixels;
import glaze.RenderOnce;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Selectable;
import glaze.kit.base.animation.Easings;
import glaze.kit.base.animation.Lerp;
import glaze.kit.Icon;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.tab.TabVariant;
import glaze.kit.tab.TabVariant.FolderTabConstants;
import glaze.kit.tab.TabVariant.FolderTabMetrics;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A Tab element for the `TabBar`.
 */
class Tab implements RenderOnce implements Styled implements ParentElement implements Sizable implements Selectable {

    @:allow(glaze.kit.tab)
    var ix:Int = 0;

    final base:glaze.kit.base.Tabs.BaseTab = new glaze.kit.base.Tabs.BaseTab(0);

    @:allow(glaze.kit.tab)
    var labelValue:Null<String> = null;

    var ariaLabelValue:Null<String> = null;

    @:allow(glaze.kit.tab)
    var iconValue:Null<Icon> = null;

    var prefixValue:Null<AnyElement> = null;

    @:allow(glaze.kit.tab)
    var tabBarPrefixValue:Null<Bool> = null;

    var suffixValue:Null<AnyElement> = null;

    final childElements:Array<AnyElement> = [];

    var variant:TabVariant = TabVariant.defaultValue();

    var size:Size = Medium;

    @:allow(glaze.kit.tab)
    var disabledValue:Bool = false;

    @:allow(glaze.kit.tab)
    var selectedValue:Bool = false;

    @:allow(glaze.kit.tab)
    var indicatorActive:Bool = false;

    @:allow(glaze.kit.tab)
    var indicatorReady:Bool = true;

    /**
     * Animation epoch of the `TabBar` indicator; increments on every tab
     * switch. Used to key the selected tab's text color fade so it restarts
     * in sync with the indicator slide.
     */
    @:allow(glaze.kit.tab)
    var indicatorEpoch:Int = 0;

    /** Whether a `TabVariant.Folder` tab draws the divider after it. */
    @:allow(glaze.kit.tab)
    var separator:Bool = false;

    /**
     * Whether the `TabBar` reports the pointer over this tab. Kept there
     * rather than in a hover group, which would replace the caller's.
     */
    @:allow(glaze.kit.tab)
    var hovered:Bool = false;

    @:allow(glaze.kit.tab)
    var maxWidthValue:Null<Pixels> = null;

    @:allow(glaze.kit.tab)
    var onClickHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    /** Create a new tab. */
    public function new() {}

    /** `Tab::from(label)`. */
    public static function fromLabel(label:String):Tab {
        return new Tab().label(label);
    }

    /** `Tab::from(icon)`. */
    public static function fromIcon(icon:Icon):Tab {
        return new Tab().icon(icon);
    }

    /** Set label for the tab. */
    public function label(label:String):Tab {
        labelValue = label;
        return this;
    }

    /** Set the accessible label for the tab. */
    public function ariaLabel(label:String):Tab {
        ariaLabelValue = label;
        return this;
    }

    function a11yLabel():Null<String> {
        return ariaLabelValue != null ? ariaLabelValue : labelValue;
    }

    /** Set icon for the tab. */
    public function icon(icon:Icon):Tab {
        iconValue = icon;
        return this;
    }

    /** Set Tab Variant. */
    public function withVariant(variant:TabVariant):Tab {
        this.variant = variant;
        return this;
    }

    public function pill():Tab {
        variant = Pill;
        return this;
    }

    public function outline():Tab {
        variant = Outline;
        return this;
    }

    public function segmented():Tab {
        variant = Segmented;
        return this;
    }

    public function underline():Tab {
        variant = Underline;
        return this;
    }

    public function folder():Tab {
        variant = Folder;
        return this;
    }

    /** Set the left side of the tab */
    public function prefix(prefix:IntoElement):Tab {
        prefixValue = prefix;
        return this;
    }

    /** Set the right side of the tab */
    public function suffix(suffix:IntoElement):Tab {
        suffixValue = suffix;
        return this;
    }

    /** Set disabled state to the tab, default false. */
    public function disabled(disabled:Bool):Tab {
        disabledValue = disabled;
        return this;
    }

    /** Set the click handler for the tab. */
    public function onClick(onClick:(ClickEvent, Window, App) -> Void):Tab {
        onClickHandler = onClick;
        return this;
    }

    /** Set index to the tab. */
    @:allow(glaze.kit)
    function withIx(ix:Int):Tab {
        this.ix = ix;
        base.id(ix);
        return this;
    }

    /** Set if the tab bar has a prefix. */
    @:allow(glaze.kit)
    function tabBarPrefix(tabBarPrefix:Bool):Tab {
        tabBarPrefixValue = tabBarPrefix;
        return this;
    }

    /** Set the maximum width of the tab, see `TabBar.maxWidth`. */
    @:allow(glaze.kit.tab)
    function maxWidth(maxWidth:Null<Pixels>):Tab {
        maxWidthValue = maxWidth;
        return this;
    }

    // Rust `InteractiveElement` / `StatefulInteractiveElement` for Tab, whose
    // interactivity is the base tab's element.

    /** Rust `debug_selector`: like `Div.debugSelector`, it records nothing. */
    public function debugSelector(f:() -> String):Tab {
        base.base.debugSelector(f);
        return this;
    }

    /** A mouse down listener. */
    public function onMouseDown(button:glaze.MouseButton, listener:(glaze.MouseDownEvent, Window, App) -> Void):Tab {
        base.onMouseDown(button, listener);
        return this;
    }

    /** A mouse up listener. */
    public function onMouseUp(button:glaze.MouseButton, listener:(glaze.MouseUpEvent, Window, App) -> Void):Tab {
        base.base.onMouseUp(button, listener);
        return this;
    }

    /** Starts a drag of `value` from this tab, previewed by the view `constructor` builds. */
    public function onDrag<T>(value:T, constructor:(T, Point, Window, App) -> glaze.AnyView):Tab {
        base.base.onDrag(value, constructor);
        return this;
    }

    /** The style applied while a drag of type `type` is over this tab. */
    public function dragOver<S>(type:Class<S>, f:(StyleBuilder, S, Window, App) -> StyleBuilder):Tab {
        base.base.dragOver(type, f);
        return this;
    }

    /** Drops of type `type` on this tab. */
    public function onDrop<T>(type:Class<T>, listener:(T, Window, App) -> Void):Tab {
        base.base.onDrop(type, listener);
        return this;
    }

    /** Whether a drop should be dispatched to this tab. */
    public function canDrop(predicate:(Dynamic, Window, App) -> Bool):Tab {
        base.base.canDrop(predicate);
        return this;
    }

    /** A tooltip shown while the pointer rests on the tab. */
    public function tooltip(buildTooltip:(Window, App) -> glaze.AnyView):Tab {
        base.base.tooltip(buildTooltip);
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function selected(selected:Bool):Tab {
        selectedValue = selected;
        return this;
    }

    public function setSelected(selected:Bool):Void {
        selectedValue = selected;
    }

    public function isSelected():Bool {
        return selectedValue;
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function withSize(size:IntoSize):Tab {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final normalStyle = variant.normal(cx);
        final selectedStyle = variant.selected(cx);
        final disabledStyle = variant.disabled(selectedValue, cx);
        var hoverStyle = variant.hovered(selectedValue, cx);
        if (disabledValue) {
            hoverStyle = variant.disabled(selectedValue, cx);
        }
        final tabBarPrefix = tabBarPrefixValue != null ? tabBarPrefixValue : false;
        if (!tabBarPrefix) {
            if (ix == 0 && variant == TabVariant.Tab) {
                for (style in [normalStyle, selectedStyle, disabledStyle, hoverStyle]) {
                    style.borders = new glaze.Edges(style.borders.top, style.borders.right, style.borders.bottom, 0.);
                }
            }
        }
        final tabStyle = disabledValue ? disabledStyle : (selectedValue ? selectedStyle : normalStyle);
        final radius = variant.radius(size, cx);
        final innerRadius = variant.innerRadius(size, cx);
        final innerPaddings = variant.innerPaddings(size);
        final innerMargins = variant.innerMargins(size);
        final innerHeight = variant.innerHeight(size);
        final height = variant.height(size);
        final ariaLabel = a11yLabel();
        final folder = variant == Folder;
        final metrics = new FolderTabMetrics(size, cx);
        final hasPrefix = prefixValue != null;

        final segmentedIndicatorActive = variant == Segmented && indicatorActive;
        final hasInlineInnerBg = selectedValue && segmentedIndicatorActive && !indicatorReady;
        final inlineInnerBg = tabStyle.innerBg;
        var innerBg:IntoBackground;
        var hoverInnerBg:IntoBackground;
        // Deviation DEV-014: a disabled selected tab has no indicator under it
        // (see TabBar) and keeps its own inner background.
        if (segmentedIndicatorActive && indicatorReady && !(selectedValue && disabledValue)) {
            innerBg = theme.transparent;
            hoverInnerBg = theme.transparent;
        } else if (hasInlineInnerBg) {
            innerBg = inlineInnerBg;
            hoverInnerBg = inlineInnerBg;
        } else {
            innerBg = tabStyle.innerBg;
            hoverInnerBg = hoverStyle.innerBg;
        }
        final innerShadow = tabStyle.shadow && !segmentedIndicatorActive;

        // When a sliding indicator is active and ready, it alone represents the
        // selected state. Suppress the selected tab's own active background/border
        // so the two don't overlap during the switch animation (Segmented already
        // does this for its `inner_bg` above). Skip disabled tabs so a
        // disabled-selected tab keeps its dimmed styling instead of the
        // full-strength indicator color.
        final suppressActiveVisual = selectedValue && !disabledValue && indicatorActive && indicatorReady;
        // Pill paints its active state via the outer `bg`.
        final selectedOuterBg:IntoBackground = suppressActiveVisual && variant == Pill ? (theme.transparent : IntoBackground) : selectedStyle.bg;
        // Underline paints its active state via the bottom `border_color`.
        final selectedOuterBorderColor = suppressActiveVisual && variant == Underline ? theme.transparent : selectedStyle.borderColor;

        // For Pill, the newly selected tab's text color (`primary_foreground`)
        // would otherwise snap to white instantly while the indicator is still
        // sliding into place. Fade it from the normal color in sync with the
        // indicator slide (keyed on the indicator epoch so it restarts on each
        // switch). `epoch == 0` is the initial layout (no slide), so we skip it.
        final animateFg = selectedValue && !disabledValue && variant == Pill && indicatorActive && indicatorReady && indicatorEpoch > 0;
        final fgFrom = variant.normal(cx).fg;
        final fgTo = tabStyle.fg;
        // Icon-only tabs are fixed-size and exempt from `max_width`.
        final maxWidth = iconValue == null ? maxWidthValue : null;

        final innerContent = hFlex()
            .flex1()
            .h(innerHeight)
            .lineHeight(glaze.Prelude.relative(1.25))
            .whitespaceNowrap()
            .itemsCenter()
            .justifyCenter()
            .overflowHidden()
            .margins(glaze.Prelude.px(innerMargins.top), glaze.Prelude.px(innerMargins.right), glaze.Prelude.px(innerMargins.bottom), glaze.Prelude.px(innerMargins.left));
        // Normally the label decides the tab width, so it never shrinks. With
        // `max_width` it is the one part that gives way.
        if (maxWidth != null) innerContent.flexAuto() else innerContent.flexShrink0();
        if (iconValue != null) {
            final icon = iconValue;
            switch size {
                case XSmall: icon.size2p5();
                case Small: icon.size3p5();
                case Large: icon.size4();
                case _: icon.size4();
            }
            // Deviation DEV-013: `flex1()` above gave the box a zero basis, so
            // it shrank to the icon and ignored the width below. An icon-only
            // tab keeps that width.
            innerContent.flexNone().w(innerHeight * 1.25).child(icon);
        } else {
            innerContent.paddingsEdges(innerPaddings);
            if (labelValue != null) {
                // Text always takes its natural width, so it needs a box
                // that is allowed to shrink to ellipsize inside of.
                if (maxWidth != null) {
                    innerContent.child(div().minW0().whitespaceNowrap().textEllipsis().child(labelValue));
                } else {
                    innerContent.child(labelValue);
                }
            }
            innerContent.extend(childElements);
            // With the prefix's gap, 8px between icon and title, as in a Button.
            if (folder && hasPrefix) innerContent.pl(glaze.Prelude.px(4.));
        }
        innerContent.bg(innerBg).rounded(innerRadius);
        if (innerShadow) innerContent.shadowXs();
        innerContent.hover(s -> s.bg(hoverInnerBg).rounded(innerRadius));

        final innerElement:AnyElement = if (animateFg) {
            innerContent.withAnimation(
                ElementId.NamedInteger('tab-fg', indicatorEpoch),
                new glaze.Animation(0.2).withEasing(Easings.easeInOutCubic),
                (this_, delta) -> this_.textColor(Lerp.hsla(fgFrom, fgTo, delta))
            ).intoAnyElement();
        } else {
            innerContent.intoAnyElement();
        }

        final selectedStyleValue = selectedStyle;
        base.id(ix)
            .selected(selectedValue)
            .disabled(disabledValue);
        if (ariaLabel != null) base.accessibilityLabel(ariaLabel);
        base.styles(styles -> styles
            .selected(style -> style
                .textColor(selectedStyleValue.fg)
                .bg(selectedOuterBg)
                .borderL(glaze.Prelude.px(selectedStyleValue.borders.left))
                .borderR(glaze.Prelude.px(selectedStyleValue.borders.right))
                .borderT(glaze.Prelude.px(selectedStyleValue.borders.top))
                .borderB(glaze.Prelude.px(selectedStyleValue.borders.bottom))
                .borderColor(selectedOuterBorderColor))
            .disabled(style -> style
                .textColor(disabledStyle.fg)
                .bg(disabledStyle.bg)
                .borderL(glaze.Prelude.px(disabledStyle.borders.left))
                .borderR(glaze.Prelude.px(disabledStyle.borders.right))
                .borderT(glaze.Prelude.px(disabledStyle.borders.top))
                .borderB(glaze.Prelude.px(disabledStyle.borders.bottom))
                .borderColor(disabledStyle.borderColor)));
        base.relative().flex();
        // Wrapping would move the overflow onto a clipped second line instead
        // of letting the label shrink, so a capped tab lays out on one line.
        if (maxWidth != null) base.flexNowrap().maxW(maxWidth) else base.flexWrap();
        base.gap1().itemsCenter().flexShrink0().h(height);
        // A folder tab's curves reach past its bounds.
        if (!folder) base.overflowHidden();
        switch size {
            case XSmall: base.textXs();
            case Large: base.textBase();
            case _: base.textSm();
        }
        base.rounded(radius);
        if (folder) base.px(metrics.paddingX).pb(metrics.topPadding);
        if (!selectedValue && !disabledValue) {
            base.textColor(normalStyle.fg)
                .bg(normalStyle.bg)
                .borderL(glaze.Prelude.px(normalStyle.borders.left))
                .borderR(glaze.Prelude.px(normalStyle.borders.right))
                .borderT(glaze.Prelude.px(normalStyle.borders.top))
                .borderB(glaze.Prelude.px(normalStyle.borders.bottom))
                .borderColor(normalStyle.borderColor);
        }
        final selected = selectedValue;
        final disabled = disabledValue;
        base.hover(s -> {
            // Always register the hover style: GPUI only refreshes the cached
            // hover state while one is present. If the selected tab skipped it,
            // the stale state would keep hover colors after unselecting.
            if (selected || disabled) {
                return s;
            }
            return s.textColor(hoverStyle.fg)
                .bg(hoverStyle.bg)
                .borderL(glaze.Prelude.px(hoverStyle.borders.left))
                .borderR(glaze.Prelude.px(hoverStyle.borders.right))
                .borderT(glaze.Prelude.px(hoverStyle.borders.top))
                .borderB(glaze.Prelude.px(hoverStyle.borders.bottom))
                .borderColor(hoverStyle.borderColor)
                .rounded(radius);
        });
        if (folder && selectedValue) {
            base.child(folderTabShape(metrics, theme.tokens.tabActive.background));
        }
        if (folder && hovered && !selectedValue && !disabledValue) {
            base.child(div()
                .absolute()
                .top0()
                .left0()
                .right0()
                .bottom(glaze.Prelude.px(metrics.topPadding))
                .rounded(metrics.radius)
                .bg(theme.tokens.secondary.background));
        }
        // In the gap after the tab, on a whole pixel, level with the content.
        if (folder && separator) {
            base.child(div()
                .absolute()
                .right(glaze.Prelude.px(-(@:privateAccess FolderTabConstants.FOLDER_TAB_GAP / 2.)))
                .top(glaze.Prelude.px((height - metrics.topPadding - metrics.separatorHeight) / 2.))
                .w(glaze.Prelude.px(1.))
                .h(metrics.separatorHeight)
                .bg(theme.border));
        }
        if (hasInlineInnerBg) {
            final layer = div()
                .wFull()
                .h(innerHeight)
                .bg(inlineInnerBg)
                .rounded(innerRadius);
            if (tabStyle.shadow) layer.shadowSm();
            base.child(div()
                .absolute()
                .left0()
                .right0()
                .top0()
                .bottom0()
                .flex()
                .itemsCenter()
                .child(layer));
        }
        // Under `max_width` the label is the only part that gives way, so
        // hold the prefix and suffix (e.g. a close button) at their full size.
        if (prefixValue != null) {
            final wrapper = div();
            if (maxWidth != null) wrapper.flexShrink0();
            base.child(wrapper.child(prefixValue));
        }
        base.child(innerElement);
        if (suffixValue != null) {
            final wrapper = div();
            if (maxWidth != null) wrapper.flexShrink0();
            base.child(wrapper.child(suffixValue));
        }
        final onClick = onClickHandler;
        if (onClick != null) {
            base.onClick((event, window, cx) -> onClick(event, window, cx));
        }
        return base;
    }


    /**
     * The selected `TabVariant.Folder` tab: rounded on top and curving out at
     * the bottom into the content below, traced after Chrome's tab path.
     */
    static function folderTabShape(metrics:FolderTabMetrics, bg:IntoBackground):IntoElement {
        final curve:Float = metrics.radius;
        return canvas((_, _, _) -> null, (bounds, _, window, _) -> {
            final top = bounds.top();
            final bottom = bounds.bottom();
            final left = bounds.left();
            final right = bounds.right();
            final tabLeft = f32(left + curve);
            final tabRight = f32(right - curve);
            // Like Chrome, keep at least a third of the top flat on narrow tabs.
            final radius = Math.min(Math.max(f32(f32(bounds.size.width - f32(curve * 2.)) / 3.), 0.), curve);

            final path = PathBuilder.fill().withStyle(PathStyle.Fill(new FillOptions(0.02)));
            path.moveTo(point(left, bottom));
            quarterCircleTo(path, point(left, bottom), point(tabLeft, bottom), point(tabLeft, f32(bottom - curve)));
            path.lineTo(point(tabLeft, f32(top + radius)));
            quarterCircleTo(path, point(tabLeft, f32(top + radius)), point(tabLeft, top), point(f32(tabLeft + radius), top));
            path.lineTo(point(f32(tabRight - radius), top));
            quarterCircleTo(path, point(f32(tabRight - radius), top), point(tabRight, top), point(tabRight, f32(top + radius)));
            path.lineTo(point(tabRight, f32(bottom - curve)));
            quarterCircleTo(path, point(tabRight, f32(bottom - curve)), point(tabRight, bottom), point(right, bottom));
            path.close();
            final built = try path.build() catch (e:haxe.Exception) null;
            if (built != null) {
                window.paintPath(built, bg);
            }
        })
            .absolute()
            .top0()
            .bottom0()
            .left(glaze.Prelude.px(-curve))
            .right(glaze.Prelude.px(-curve));
    }

    /** Adds a quarter circle from `from` to `to`, whose tangents meet at `corner`. */
    static function quarterCircleTo(path:PathBuilder, from:Point, corner:Point, to:Point):Void {
        // Control point distance that makes a cubic Bezier a quarter circle.
        final k = f32(0.5522848);
        path.cubicBezierTo(
            to,
            point(f32(from.x + f32(f32(corner.x - from.x) * k)), f32(from.y + f32(f32(corner.y - from.y) * k))),
            point(f32(to.x + f32(f32(corner.x - to.x) * k)), f32(to.y + f32(f32(corner.y - to.y) * k)))
        );
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

}
